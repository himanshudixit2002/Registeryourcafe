import 'package:cloud_firestore/cloud_firestore.dart';
import '../firestore/tenant_firestore.dart';
import '../models/app_user.dart';
import '../utils/calculation_utils.dart';
import '../utils/app_logger.dart';
import '../utils/firestore_utils.dart';

class CreditService {
  CreditService._();

  /// Error message for insufficient credits
  static const String insufficientCreditsError = 'INSUFFICIENT_CREDITS';

  /// Transaction types for credit operations.
  static const String typeDebit = 'debit';
  static const String typeCredit = 'credit';
  static const String typeTopUp = 'manualTopUp';
  static const String typeMembership = 'membership';
  static const String typeInitialBalance = 'initialBalance';

  /// Reference types for tracking credit usage.
  static const String refCafeOrder = 'cafe_order';
  static const String refMerchandiseOrder = 'merchandise_order';
  static const String refSessionPayment = 'session_payment';
  static const String refRefund = 'refund';
  static const String refManualAdjustment = 'manual_adjustment';
  static const String refLoyaltyConversion = 'loyalty_conversion';

  /// Validates customer has sufficient credits for the requested amount.
  static Future<CreditValidationResult> validateCredits({
    required TenantRef tenant,
    required String customerId,
    required double requestedAmount,
    required double orderTotal,
  }) async {
    if (requestedAmount <= 0 || customerId.isEmpty) {
      return CreditValidationResult(
        isValid: true,
        availableCredits: 0,
        usableCredits: 0,
        reason: 'No credits requested',
      );
    }

    final customerDoc = await tenant.customers().doc(customerId).get();
    if (!customerDoc.exists) {
      return CreditValidationResult(
        isValid: false,
        availableCredits: 0,
        usableCredits: 0,
        reason: 'Customer not found',
      );
    }

    final customerData = customerDoc.data()!;
    final availableCredits = parseFirestoreDouble(customerData['credits']);
    final usableCredits = CalculationUtils.calculateCreditsToUse(
      requestedCredits: requestedAmount,
      availableCredits: availableCredits,
      maxAmount: orderTotal,
    );

    if (usableCredits < requestedAmount) {
      return CreditValidationResult(
        isValid: false,
        availableCredits: availableCredits,
        usableCredits: usableCredits,
        reason:
            'Insufficient credits. Available: ₹${availableCredits.toStringAsFixed(2)}',
      );
    }

    return CreditValidationResult(
      isValid: true,
      availableCredits: availableCredits,
      usableCredits: usableCredits,
    );
  }

  /// Atomically validates and debits credits using a Firestore transaction.
  ///
  /// This is the RECOMMENDED method for credit debits as it prevents negative
  /// balances by validating credits at debit time within a transaction.
  ///
  /// Returns [SafeDebitResult] with:
  /// - [success]: true if debit was successful
  /// - [actualDebited]: the amount actually debited (may be less if capped)
  /// - [newBalance]: the customer's new credit balance
  /// - [error]: error message if failed
  ///
  /// If [allowPartial] is true and customer has fewer credits than requested,
  /// it will debit whatever is available. Otherwise, it will fail.
  static Future<SafeDebitResult> safeDebitCredits({
    required TenantRef tenant,
    required String customerId,
    required double amount,
    required CreditReference reference,
    AppUser? performedBy,
    String? note,
    bool allowPartial = false,
  }) async {
    if (amount <= 0) {
      return const SafeDebitResult(
        success: true,
        actualDebited: 0,
        newBalance: 0,
      );
    }

    if (customerId.isEmpty) {
      return const SafeDebitResult(
        success: false,
        actualDebited: 0,
        newBalance: 0,
        error: 'Customer ID is required',
      );
    }

    try {
      final result = await tenant.db.runTransaction<SafeDebitResult>((
        transaction,
      ) async {
        final customerRef = tenant.customers().doc(customerId);
        final customerSnap = await transaction.get(customerRef);

        if (!customerSnap.exists) {
          throw Exception('Customer not found');
        }

        final currentCredits = parseFirestoreDouble(
          customerSnap.data()?['credits'],
        );

        // Determine how much we can actually debit
        double actualDebit = amount;
        if (currentCredits < amount) {
          if (allowPartial) {
            actualDebit = currentCredits > 0 ? currentCredits : 0;
          } else {
            throw InsufficientCreditsException(
              'Insufficient credits. Available: ₹${currentCredits.toStringAsFixed(2)}, Requested: ₹${amount.toStringAsFixed(2)}',
              availableCredits: currentCredits,
              requestedCredits: amount,
            );
          }
        }

        if (actualDebit <= 0) {
          return SafeDebitResult(
            success: true,
            actualDebited: 0,
            newBalance: currentCredits,
          );
        }

        final newBalance = CalculationUtils.roundCurrency(
          currentCredits - actualDebit,
        );

        // Perform the debit
        transaction.update(customerRef, {
          'credits': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create transaction record
        final txRef = customerRef.collection('credit_transactions').doc();
        transaction.set(
          txRef,
          _buildTransactionData(
            amount: -actualDebit,
            type: typeDebit,
            reference: reference,
            performedBy: performedBy,
            note: note ?? _generateDebitNote(reference),
          ),
        );

        return SafeDebitResult(
          success: true,
          actualDebited: actualDebit,
          newBalance: newBalance,
        );
      }, maxAttempts: 3);

      return result;
    } on InsufficientCreditsException catch (e) {
      return SafeDebitResult(
        success: false,
        actualDebited: 0,
        newBalance: e.availableCredits,
        error: e.message,
      );
    } catch (e) {
      AppLogger.error(
        'Failed to debit credits for customer $customerId',
        error: e,
        tag: 'CreditService',
      );
      return SafeDebitResult(
        success: false,
        actualDebited: 0,
        newBalance: 0,
        error: 'Failed to process credit payment: $e',
      );
    }
  }

  /// Validates and prepares credit debit within an existing Firestore transaction.
  ///
  /// Use this when you need to include credit operations in a larger transaction
  /// (e.g., order creation with stock updates).
  ///
  /// Returns [TransactionDebitResult] containing:
  /// - [canDebit]: whether the debit can proceed
  /// - [actualAmount]: the amount that will be debited
  /// - [currentBalance]: current credit balance
  /// - [operations]: a function to call to apply the debit operations to the transaction
  ///
  /// Example usage:
  /// ```dart
  /// await _firestore.runTransaction((transaction) async {
  ///   final debitResult = await CreditService.prepareDebitInTransaction(
  ///     transaction: transaction,
  ///     customerId: customerId,
  ///     amount: 100,
  ///     reference: CreditReference.cafeOrder(orderId),
  ///   );
  ///
  ///   if (!debitResult.canDebit) {
  ///     throw Exception(debitResult.error);
  ///   }
  ///
  ///   // ... other transaction operations ...
  ///
  ///   debitResult.applyOperations(transaction);
  /// });
  /// ```
  static Future<TransactionDebitResult> prepareDebitInTransaction({
    required TenantRef tenant,
    required Transaction transaction,
    required String customerId,
    required double amount,
    required CreditReference reference,
    AppUser? performedBy,
    String? note,
    bool allowPartial = false,
  }) async {
    if (amount <= 0 || customerId.isEmpty) {
      return TransactionDebitResult.success(
        actualAmount: 0,
        currentBalance: 0,
        operations: (_) {},
      );
    }

    final customerRef = tenant.customers().doc(customerId);
    final customerSnap = await transaction.get(customerRef);

    if (!customerSnap.exists) {
      return TransactionDebitResult.failure(
        error: 'Customer not found',
        currentBalance: 0,
      );
    }

    final currentCredits = parseFirestoreDouble(
      customerSnap.data()?['credits'],
    );

    // Determine how much we can actually debit
    double actualDebit = amount;
    if (currentCredits < amount) {
      if (allowPartial) {
        actualDebit = currentCredits > 0 ? currentCredits : 0;
      } else {
        return TransactionDebitResult.failure(
          error:
              'Insufficient credits. Available: ₹${currentCredits.toStringAsFixed(2)}, Requested: ₹${amount.toStringAsFixed(2)}',
          currentBalance: currentCredits,
        );
      }
    }

    if (actualDebit <= 0) {
      return TransactionDebitResult.success(
        actualAmount: 0,
        currentBalance: currentCredits,
        operations: (_) {},
      );
    }

    final newBalance = CalculationUtils.roundCurrency(
      currentCredits - actualDebit,
    );
    final txRef = customerRef.collection('credit_transactions').doc();
    final txData = _buildTransactionData(
      amount: -actualDebit,
      type: typeDebit,
      reference: reference,
      performedBy: performedBy,
      note: note ?? _generateDebitNote(reference),
    );

    return TransactionDebitResult.success(
      actualAmount: actualDebit,
      currentBalance: currentCredits,
      newBalance: newBalance,
      operations: (tx) {
        tx.update(customerRef, {
          'credits': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(txRef, txData);
      },
    );
  }

  /// Batch debit without balance validation. Prefer [safeDebitCredits] or
  /// [prepareDebitInTransaction] for UI-driven debits.
  static void _applyDebitCreditsToBatch({
    required TenantRef tenant,
    required WriteBatch batch,
    required String customerId,
    required double amount,
    required CreditReference reference,
    AppUser? performedBy,
    String? note,
  }) {
    if (amount <= 0 || customerId.isEmpty) return;

    final customerRef = tenant.customers().doc(customerId);

    // Update customer balance
    batch.update(customerRef, {
      'credits': FieldValue.increment(-amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create transaction record
    final txRef = customerRef.collection('credit_transactions').doc();
    batch.set(
      txRef,
      _buildTransactionData(
        amount: -amount,
        type: typeDebit,
        reference: reference,
        performedBy: performedBy,
        note: note ?? _generateDebitNote(reference),
      ),
    );
  }

  /// Credits (adds) credits to a customer account within a batch operation.
  ///
  /// Use this for:
  /// - Refunds
  /// - Manual top-ups
  /// - Membership credits
  static void creditCredits({
    required TenantRef tenant,
    required WriteBatch batch,
    required String customerId,
    required double amount,
    required CreditReference reference,
    AppUser? performedBy,
    String? note,
    String transactionType = typeCredit,
  }) {
    if (amount <= 0 || customerId.isEmpty) return;

    final customerRef = tenant.customers().doc(customerId);

    // Update customer balance
    batch.update(customerRef, {
      'credits': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create transaction record
    final txRef = customerRef.collection('credit_transactions').doc();
    batch.set(
      txRef,
      _buildTransactionData(
        amount: amount,
        type: transactionType,
        reference: reference,
        performedBy: performedBy,
        note: note ?? _generateCreditNote(reference),
      ),
    );
  }

  /// Standalone debit operation (not in a batch).
  /// Use sparingly - prefer batch operations for atomic transactions.
  static Future<void> debitCreditsStandalone({
    required TenantRef tenant,
    required String customerId,
    required double amount,
    required CreditReference reference,
    AppUser? performedBy,
    String? note,
  }) async {
    final batch = tenant.db.batch();
    _applyDebitCreditsToBatch(
      tenant: tenant,
      batch: batch,
      customerId: customerId,
      amount: amount,
      reference: reference,
      performedBy: performedBy,
      note: note,
    );
    await batch.commit();
  }

  /// Standalone credit operation (not in a batch).
  /// Use sparingly - prefer batch operations for atomic transactions.
  static Future<void> creditCreditsStandalone({
    required TenantRef tenant,
    required String customerId,
    required double amount,
    required CreditReference reference,
    AppUser? performedBy,
    String? note,
    String transactionType = typeCredit,
  }) async {
    final batch = tenant.db.batch();
    creditCredits(
      tenant: tenant,
      batch: batch,
      customerId: customerId,
      amount: amount,
      reference: reference,
      performedBy: performedBy,
      note: note,
      transactionType: transactionType,
    );
    await batch.commit();
  }

  /// Transfers credits between customers (e.g., PTL loser-pays scenarios).
  static void transferCredits({
    required TenantRef tenant,
    required WriteBatch batch,
    required String fromCustomerId,
    required String toCustomerId,
    required double amount,
    required CreditReference reference,
    AppUser? performedBy,
    String? note,
  }) {
    if (amount <= 0 || fromCustomerId.isEmpty || toCustomerId.isEmpty) return;

    // Debit from source
    _applyDebitCreditsToBatch(
      tenant: tenant,
      batch: batch,
      customerId: fromCustomerId,
      amount: amount,
      reference: reference.copyWith(
        additionalInfo: {'transferTo': toCustomerId},
      ),
      performedBy: performedBy,
      note: note ?? 'Transfer to customer',
    );

    // Credit to destination
    creditCredits(
      tenant: tenant,
      batch: batch,
      customerId: toCustomerId,
      amount: amount,
      reference: reference.copyWith(
        additionalInfo: {'transferFrom': fromCustomerId},
      ),
      performedBy: performedBy,
      note: note ?? 'Transfer from customer',
    );
  }

  /// Gets the current credit balance for a customer.
  static Future<double> getBalance(TenantRef tenant, String customerId) async {
    if (customerId.isEmpty) return 0.0;

    final doc = await tenant.customers().doc(customerId).get();
    if (!doc.exists) return 0.0;

    return parseFirestoreDouble(doc.data()?['credits']);
  }

  /// Calculates how credits should be distributed across multiple orders
  /// in a session based on their proportional amounts.
  static Map<String, double> distributeCreditsProportionally({
    required double totalCredits,
    required Map<String, double> orderTotals,
  }) {
    final grandTotal =
        orderTotals.values.fold(0.0, (running, v) => running + v);
    if (grandTotal <= 0) return {};

    return CalculationUtils.distributeProportionally(
      amountToDistribute: totalCredits,
      itemValues: orderTotals,
    );
  }

  static Map<String, dynamic> _buildTransactionData({
    required double amount,
    required String type,
    required CreditReference reference,
    AppUser? performedBy,
    String? note,
  }) {
    return {
      'date': FieldValue.serverTimestamp(),
      'amount': amount,
      'type': type,
      'method': 'credits',
      'note': ?note,
      if (performedBy != null) ...{
        'performedById': performedBy.uid,
        'performedByName': performedBy.name,
        'performedByRole': performedBy.role.name,
      },
      'reference': reference.toMap(),
    };
  }

  static String _generateDebitNote(CreditReference reference) {
    switch (reference.type) {
      case refCafeOrder:
        return 'Cafe order ${reference.id}';
      case refMerchandiseOrder:
        return 'Merchandise order ${reference.id}';
      case refSessionPayment:
        final tableNameRaw = reference.additionalInfo?['tableName'];
        final tableName = tableNameRaw is String
            ? tableNameRaw
            : (tableNameRaw?.toString() ?? '');
        return 'Session payment${tableName.isNotEmpty ? ' at $tableName' : ''}';
      default:
        return 'Credit debit';
    }
  }

  static String _generateCreditNote(CreditReference reference) {
    switch (reference.type) {
      case refRefund:
        return 'Refund for ${reference.id}';
      case refManualAdjustment:
        return 'Manual adjustment';
      case refLoyaltyConversion:
        return 'Loyalty points conversion';
      default:
        return 'Credit added';
    }
  }
}

class CreditValidationResult {
  final bool isValid;
  final double availableCredits;
  final double usableCredits;
  final String? reason;

  const CreditValidationResult({
    required this.isValid,
    required this.availableCredits,
    required this.usableCredits,
    this.reason,
  });
}

class CreditReference {
  final String type;
  final String id;
  final Map<String, dynamic>? additionalInfo;

  const CreditReference({
    required this.type,
    required this.id,
    this.additionalInfo,
  });

  /// Creates a reference for cafe orders.
  factory CreditReference.cafeOrder(String orderId) {
    return CreditReference(type: CreditService.refCafeOrder, id: orderId);
  }

  /// Creates a reference for merchandise orders.
  factory CreditReference.merchandiseOrder(String orderId) {
    return CreditReference(
      type: CreditService.refMerchandiseOrder,
      id: orderId,
    );
  }

  /// Creates a reference for session payments.
  factory CreditReference.sessionPayment(
    String sessionId, {
    String? tableName,
  }) {
    return CreditReference(
      type: CreditService.refSessionPayment,
      id: sessionId,
      additionalInfo: tableName != null ? {'tableName': tableName} : null,
    );
  }

  /// Creates a reference for refunds.
  factory CreditReference.refund(String orderId, {String? orderType}) {
    return CreditReference(
      type: CreditService.refRefund,
      id: orderId,
      additionalInfo: orderType != null ? {'orderType': orderType} : null,
    );
  }

  /// Creates a reference for loyalty point conversions.
  factory CreditReference.loyaltyConversion(String conversionId) {
    return CreditReference(
      type: CreditService.refLoyaltyConversion,
      id: conversionId,
    );
  }

  /// Creates a reference for manual adjustments.
  factory CreditReference.manualAdjustment({String? reason}) {
    return CreditReference(
      type: CreditService.refManualAdjustment,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      additionalInfo: reason != null ? {'reason': reason} : null,
    );
  }

  CreditReference copyWith({Map<String, dynamic>? additionalInfo}) {
    final merged = {...?this.additionalInfo, ...?additionalInfo};
    return CreditReference(
      type: type,
      id: id,
      additionalInfo: merged.isEmpty ? null : merged,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'id': id,
      if (additionalInfo != null) ...additionalInfo!,
    };
  }
}

class SafeDebitResult {
  final bool success;
  final double actualDebited;
  final double newBalance;
  final String? error;

  const SafeDebitResult({
    required this.success,
    required this.actualDebited,
    required this.newBalance,
    this.error,
  });

  @override
  String toString() =>
      'SafeDebitResult(success: $success, actualDebited: $actualDebited, newBalance: $newBalance, error: $error)';
}

class TransactionDebitResult {
  final bool canDebit;
  final double actualAmount;
  final double currentBalance;
  final double? newBalance;
  final String? error;
  final void Function(Transaction transaction)? _operations;

  const TransactionDebitResult._({
    required this.canDebit,
    required this.actualAmount,
    required this.currentBalance,
    this.newBalance,
    this.error,
    void Function(Transaction transaction)? operations,
  }) : _operations = operations;

  factory TransactionDebitResult.success({
    required double actualAmount,
    required double currentBalance,
    double? newBalance,
    required void Function(Transaction transaction) operations,
  }) {
    return TransactionDebitResult._(
      canDebit: true,
      actualAmount: actualAmount,
      currentBalance: currentBalance,
      newBalance: newBalance,
      operations: operations,
    );
  }

  factory TransactionDebitResult.failure({
    required String error,
    required double currentBalance,
  }) {
    return TransactionDebitResult._(
      canDebit: false,
      actualAmount: 0,
      currentBalance: currentBalance,
      error: error,
    );
  }

  /// Applies the debit operations to the transaction.
  /// Only call this if [canDebit] is true.
  void applyOperations(Transaction transaction) {
    final ops = _operations;
    if (ops != null) {
      ops(transaction);
    }
  }
}

class InsufficientCreditsException implements Exception {
  final String message;
  final double availableCredits;
  final double requestedCredits;

  const InsufficientCreditsException(
    this.message, {
    required this.availableCredits,
    required this.requestedCredits,
  });

  @override
  String toString() => 'InsufficientCreditsException: $message';
}
