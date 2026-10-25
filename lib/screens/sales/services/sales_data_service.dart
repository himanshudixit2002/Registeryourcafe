import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:registeryourcafe/constants/firestore_collections.dart';
import 'package:registeryourcafe/constants/refund_constants.dart';
import 'package:registeryourcafe/models/session.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../../../firestore/tenant_firestore.dart';
import '../../../models/cafe_order.dart';
import '../../../models/merchandise_order.dart';
import '../../../models/sales_transaction.dart';
import '../../../utils/app_logger.dart';
import '../../../utils/firestore_utils.dart';
import 'sales_refund_row_utils.dart';

class _Collection {
  static const String cafeOrders = 'cafe_orders';
  static const String merchandiseOrders = 'merchandise_orders';
  static const String sessions = 'sessions';
  static const String membershipPayments = 'membership_payments';
  static const String tournamentRegistrations = 'tournament_registrations';
}

class _Field {
  static const String status = 'status';
  static const String endTime = 'endTime';
  static const String createdAt = 'createdAt';
}

class SalesDataService {
  final TenantRef _tenant;

  SalesDataService(this._tenant);

  Stream<SalesDataSummary> getSalesData({
    required DateTimeRange dateRange,
    String revenueType = 'all',
    String paymentMethod = 'all',
  }) {
    final streams = <Stream<List<SalesTransaction>>>[];

    // Helper to create a transaction stream from a collection query
    Stream<List<SalesTransaction>> createTransactionStream(
      String collection, {
      String timeField = _Field.createdAt,
    }) {
      return _getQuery(collection, dateRange, timeField: timeField)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.expand((doc) => _processDocument(doc)).toList(),
          )
          .handleError((error) {
            // Return empty list on stream error to prevent breaking the combine
            return <SalesTransaction>[];
          });
    }

    // Determine which streams to listen to based on revenueType filter
    final bool listenToCafe = revenueType == 'all' || revenueType == 'cafe';
    final bool listenToMerch =
        revenueType == 'all' || revenueType == 'merchandise';
    final bool listenToSessions =
        revenueType == 'all' ||
        revenueType == 'table_charges' ||
        revenueType == 'cafe' ||
        revenueType == 'merchandise';
    final bool listenToCredit =
        revenueType == 'all' || revenueType == 'credit_topup';
    final bool listenToTournament =
        revenueType == 'all' || revenueType == 'tournament';

    if (listenToCafe) {
      streams.add(createTransactionStream(_Collection.cafeOrders));
    }
    if (listenToMerch) {
      streams.add(createTransactionStream(_Collection.merchandiseOrders));
    }
    if (listenToSessions) {
      streams.add(
        createTransactionStream(
          _Collection.sessions,
          timeField: _Field.endTime,
        ),
      );
    }
    if (listenToCredit) {
      streams.add(createTransactionStream(_Collection.membershipPayments));
    }
    if (listenToTournament) {
      streams.add(
        createTransactionStream(
          _Collection.tournamentRegistrations,
          timeField: 'approvedAt',
        ),
      );
    }

    if (streams.isEmpty) {
      return Stream.value(SalesDataSummary(isLoading: false));
    }

    return Rx.combineLatest(streams, (
      List<List<SalesTransaction>> listOfLists,
    ) {
      final allTransactions = listOfLists.expand((list) => list).toList();

      final filteredTransactions = allTransactions.where((t) {
        if (paymentMethod == 'all') return true;
        if (paymentMethod == 'credit') {
          // Include any transaction that involved credits (positive for charges, negative for refunds),
          // or where the primary method is explicitly credit.
          return t.paymentMethod == 'credit' || t.creditsUsed != 0;
        } else {
          // For other methods (cash, upi), include both positive (charges) and negative (refunds)
          // where that method was involved.
          return t.paymentMethod == paymentMethod && t.paidTotal != 0;
        }
      }).toList();

      double totalPaidRevenue = 0.0;
      final Map<String, double> valueOfGoodsByType = {};
      final Map<String, double> paymentMethodTotals = {};

      // Helper to determine what fraction of a transaction's monetary value
      // should be counted towards the currently selected revenue type.
      double ratioForTransaction(SalesTransaction t) {
        switch (revenueType) {
          case 'all':
            return 1.0;
          case 'table_charges':
            if (t.type == TransactionType.session && t.tableCharges > 0) {
              return t.total == 0 ? 0 : t.tableCharges / t.total;
            }
            return 0.0;
          case 'cafe':
            if (t.type == TransactionType.cafe) return 1.0;
            if (t.type == TransactionType.session && t.cafeCharges > 0) {
              return t.total == 0 ? 0 : t.cafeCharges / t.total;
            }
            return 0.0;
          case 'merchandise':
            if (t.type == TransactionType.merchandise) return 1.0;
            if (t.type == TransactionType.session && t.merchandiseCharges > 0) {
              return t.total == 0 ? 0 : t.merchandiseCharges / t.total;
            }
            return 0.0;
          case 'credit_topup':
            return t.type == TransactionType.credit ? 1.0 : 0.0;
          case 'tournament':
            return t.type == TransactionType.tournamentRegistration ? 1.0 : 0.0;
          default:
            return 1.0;
        }
      }

      for (final transaction in filteredTransactions) {
        final double ratio = ratioForTransaction(transaction);

        // Skip if this transaction isn't relevant for the selected revenue type.
        if (ratio == 0) {
          // Even though it's not contributing financially we still keep it in
          // the list so the user can see context in the transactions table.
          // (If later you wish to hide them completely you can filter the list
          // above instead.)
        }

        // Check if this is a RETAINED method line (alternative refund re-attribution)
        // These have total=0 but paidTotal>0 and should only update method totals, not revenue
        final bool isRetainedLine =
            transaction.total == 0 && transaction.paidTotal > 0;

        // Increment revenue totals proportionally (skip retained lines as they don't add revenue)
        if (!isRetainedLine) {
          final double paidComponent = transaction.paidTotal * ratio;
          final double creditComponent = transaction.creditsUsed * ratio;
          totalPaidRevenue += paidComponent + creditComponent;
        }

        // Populate payment method totals proportionally. We include all transactions
        // (including retained lines) so method breakdowns show actual money flow.
        final double paidComponent = transaction.paidTotal * ratio;
        final double creditComponent = transaction.creditsUsed * ratio;

        if (paidComponent != 0) {
          paymentMethodTotals.update(
            transaction.paymentMethod,
            (v) => v + paidComponent,
            ifAbsent: () => paidComponent,
          );
        }
        if (creditComponent != 0) {
          paymentMethodTotals.update(
            'credit',
            (v) => v + creditComponent,
            ifAbsent: () => creditComponent,
          );
        }

        // Aggregate value of goods by its fundamental type, respecting the filter
        switch (transaction.type) {
          case TransactionType.session:
            // Deconstruct session into its components
            if (revenueType == 'all' || revenueType == 'table_charges') {
              if (transaction.tableCharges != 0) {
                valueOfGoodsByType.update(
                  'Table Charges',
                  (v) => v + transaction.tableCharges,
                  ifAbsent: () => transaction.tableCharges,
                );
              }
            }
            if (revenueType == 'all' || revenueType == 'cafe') {
              if (transaction.cafeCharges != 0) {
                valueOfGoodsByType.update(
                  'Cafe',
                  (v) => v + transaction.cafeCharges,
                  ifAbsent: () => transaction.cafeCharges,
                );
              }
            }
            if (revenueType == 'all' || revenueType == 'merchandise') {
              if (transaction.merchandiseCharges != 0) {
                valueOfGoodsByType.update(
                  'Merchandise',
                  (v) => v + transaction.merchandiseCharges,
                  ifAbsent: () => transaction.merchandiseCharges,
                );
              }
            }
            break;
          case TransactionType.cafe:
            if (revenueType == 'all' || revenueType == 'cafe') {
              valueOfGoodsByType.update(
                'Cafe',
                (v) => v + transaction.total,
                ifAbsent: () => transaction.total,
              );
            }
            break;
          case TransactionType.merchandise:
            if (revenueType == 'all' || revenueType == 'merchandise') {
              valueOfGoodsByType.update(
                'Merchandise',
                (v) => v + transaction.total,
                ifAbsent: () => transaction.total,
              );
            }
            break;
          case TransactionType.credit:
            if (revenueType == 'all' || revenueType == 'credit_topup') {
              valueOfGoodsByType.update(
                'Credit Top-up',
                (v) => v + transaction.total,
                ifAbsent: () => transaction.total,
              );
            }
            break;
          case TransactionType.tournamentRegistration:
            if (revenueType == 'all' || revenueType == 'tournament') {
              valueOfGoodsByType.update(
                'Tournament',
                (v) => v + transaction.total,
                ifAbsent: () => transaction.total,
              );
            }
            break;
        }
      }

      filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

      return SalesDataSummary(
        totalRevenue: totalPaidRevenue,
        totalTransactions: filteredTransactions.length,
        revenueByType: valueOfGoodsByType,
        paymentMethodTotals: paymentMethodTotals,
        transactions: filteredTransactions,
        isLoading: false,
      );
    }).startWith(SalesDataSummary(isLoading: true)).handleError((
      Object error,
      StackTrace stackTrace,
    ) {
      AppLogger.error(
        'Stream error',
        error: error,
        stackTrace: stackTrace,
        tag: 'SalesDataService',
      );
      return SalesDataSummary(isLoading: false, error: error);
    });
  }

  CollectionReference<Map<String, dynamic>> _collectionRef(String collection) {
    switch (collection) {
      case _Collection.cafeOrders:
        return _tenant.cafeOrders();
      case _Collection.merchandiseOrders:
        return _tenant.merchandiseOrders();
      case _Collection.sessions:
        return _tenant.sessions();
      case _Collection.membershipPayments:
        return _tenant.membershipPayments();
      case _Collection.tournamentRegistrations:
        return _tenant.tournamentRegistrations();
      default:
        throw ArgumentError('Unknown collection $collection');
    }
  }

  Query _getQuery(
    String collection,
    DateTimeRange dateRange, {
    String timeField = _Field.createdAt,
  }) {
    Query query = _collectionRef(collection);

    if (collection == _Collection.cafeOrders) {
      query = query.where(
        _Field.status,
        whereIn: ['delivered', 'completed', 'refunded'],
      );
    } else if (collection == _Collection.merchandiseOrders) {
      query = query.where(
        _Field.status,
        whereIn: ['pending', 'delivered', 'completed', 'refunded'],
      );
    } else if (collection == _Collection.sessions) {
      // Include both completed and refunded sessions so that refunds appear
      // correctly in the sales summary by negating their totals.
      query = query.where(_Field.status, whereIn: ['completed', 'refunded']);
    } else if (collection == _Collection.tournamentRegistrations) {
      // Only approved or cancelled (refunded) registrations matter for sales view
      query = query.where('status', whereIn: ['approved', 'cancelled']);
    }

    // Always apply lower bound.
    query = query.where(timeField, isGreaterThanOrEqualTo: dateRange.start);

    // Apply upper bound only if the selected end date is in the past by more than 2 minutes.
    final bool endIsInPast = dateRange.end.isBefore(
      DateTime.now().subtract(const Duration(minutes: 2)),
    );
    if (endIsInPast) {
      query = query.where(timeField, isLessThanOrEqualTo: dateRange.end);
    }

    query = query.orderBy(timeField, descending: true);

    return query;
  }

  List<SalesTransaction> _processDocument(DocumentSnapshot doc) {
    try {
      switch (doc.reference.parent.id) {
        case _Collection.cafeOrders:
          {
            final cafeData = doc.data() as Map<String, dynamic>;
            final order = CafeOrder.fromFirestore(doc);

            // If this order is part of a session AND has no refund history,
            // it's fully represented in the session transaction - skip it.
            // BUT if it has refund history, we need to show those refund transactions separately.
            if (cafeData['sessionId'] != null &&
                (cafeData['sessionId'] as String).isNotEmpty &&
                order.refundHistory.isEmpty) {
              // This cafe order is already included in its parent session transaction.
              return [];
            }
            final List<SalesTransaction> transactions = [];

            // Check if this order is part of a session
            final bool isSessionLinked =
                cafeData['sessionId'] != null &&
                (cafeData['sessionId'] as String).isNotEmpty;

            // Main order transaction (current state after any refunds)
            // Skip if it's session-linked (already included in session row)
            if (!isSessionLinked) {
              final double creditsUsed = order.creditsUsed ?? 0.0;
              double paidPortion = order.total - creditsUsed;
              if (paidPortion < 0) paidPortion = 0;

              // Determine primary payment method
              String pm;
              if (creditsUsed.abs() >= order.total.abs() && order.total != 0) {
                pm = 'credit';
              } else {
                if (order.paymentBreakdown != null) {
                  final nonCreditKeys = order.paymentBreakdown!.keys
                      .where((k) => k.toLowerCase() != 'credits')
                      .toList();
                  pm = nonCreditKeys.isNotEmpty
                      ? nonCreditKeys.first.toLowerCase()
                      : (order.paymentMethod?.name ?? 'cash');
                } else {
                  pm = order.paymentMethod?.name ?? 'cash';
                }
                pm = pm == 'credits' ? 'credit' : pm;
              }

              // Add main order transaction (shows current state after refunds).
              // Skip showing a redundant zero-value row when the order is fully
              // refunded (items cleared and total == 0).
              final bool hasRefundsCafe = order.refundHistory.isNotEmpty;
              final bool showMainCafeRow =
                  order.items.isNotEmpty ||
                  (hasRefundsCafe && order.total != 0);
              if (showMainCafeRow) {
                transactions.add(
                  SalesTransaction(
                    id: order.id,
                    type: TransactionType.cafe,
                    date: order.createdAt,
                    total: order.total,
                    paidTotal: paidPortion,
                    paymentMethod: pm,
                    description: order.items.isNotEmpty
                        ? order.items
                              .map((e) => '${e.name} (x${e.quantity})')
                              .join(', ')
                        : 'Fully Refunded Order',
                    items: order.items
                        .map(
                          (e) => TransactionItem(
                            name: e.name,
                            quantity: e.quantity,
                            price: e.price,
                          ),
                        )
                        .toList(),
                    customerId: order.customerId,
                    customerName: order.customerName,
                    creditsUsed: creditsUsed,
                    cafeCharges: order.total,
                  ),
                );
              }
            }

            // Add refund transactions from refundHistory
            // For session-linked orders, also track these refunds to neutralize session breakdown
            for (int i = 0; i < order.refundHistory.length; i++) {
              final refund = order.refundHistory[i];
              final refundAmount =
                  parseFirestoreDoubleOrNull(refund['refundAmount']) ??
                  parseFirestoreDoubleOrNull(refund['amount']) ??
                  0.0;
              if (refundAmount <= 0) continue;

              // Skip refunds written when the parent session was refunded
              // (already accounted for in the session transaction).
              final refundNote = refund['note'] as String?;
              if (isSessionLinked &&
                  isRefundNoteFromSessionLevelRefund(refundNote)) {
                continue;
              }

              final refundedAt = refund['refundedAt'];
              DateTime refundDate = order.createdAt;
              if (refundedAt != null) {
                refundDate = (refundedAt is Timestamp)
                    ? refundedAt.toDate()
                    : order.createdAt;
              }

              final refundItems = refund['items'] as List<dynamic>? ?? [];

              // Extract refund destination info
              final creditsRefunded = parseFirestoreDouble(
                refund['creditsRefunded'],
              );
              final refundPaymentBreakdown =
                  refund['refundPaymentBreakdown'] as Map<String, dynamic>?;
              final originalPaymentBreakdown =
                  refund['originalPaymentBreakdown'] as Map<String, dynamic>?;
              final useAlternativeMethod =
                  refund['useAlternativeRefundMethod'] as bool? ?? false;

              // For session-linked orders, mark the transaction type appropriately
              final transType = isSessionLinked
                  ? TransactionType
                        .cafe // Still cafe, but will be tracked
                  : TransactionType.cafe;

              // Check if alternative refund method was used
              if (useAlternativeMethod &&
                  originalPaymentBreakdown != null &&
                  refundPaymentBreakdown != null) {
                // Create TWO transactions for alternative method refunds (re-attribution style):
                // 1) CASH payout (negative paidTotal) and goods neutralization (total negative)
                // 2) UPI retained (positive paidTotal), method-only (no goods value)
                final originalMethod = originalPaymentBreakdown.keys.first
                    .toLowerCase();
                final altMethod = refundPaymentBreakdown.keys.first
                    .toLowerCase();
                final nonCreditRefund = refundAmount - creditsRefunded;

                // Row A: Counter pays via alternative method (e.g., CASH) → negative cash
                transactions.add(
                  SalesTransaction(
                    id: '${order.id}_refund_counter_$i',
                    type: transType,
                    date: refundDate,
                    total: -refundAmount, // goods neutralization
                    paidTotal: -nonCreditRefund, // cash outflow by counter
                    paymentMethod: altMethod,
                    description:
                        '${isSessionLinked ? 'SESSION CAFE ' : ''}REFUND PAID (${altMethod.toUpperCase()}) · ${refundItems
                            .map(refundItemDescriptionPart)
                            .join(', ')}',
                    items: refundItems
                        .map(transactionItemFromRefundRow)
                        .toList(),
                    customerId: order.customerId,
                    customerName: order.customerName,
                    creditsUsed: 0,
                    cafeCharges: -refundAmount,
                  ),
                );

                // Row B: Original method retained (e.g., UPI in bank) → positive UPI method-only
                if (nonCreditRefund > 0) {
                  transactions.add(
                    SalesTransaction(
                      id: '${order.id}_refund_retained_$i',
                      type: transType,
                      date: refundDate,
                      total: 0, // no goods value impact
                      paidTotal: nonCreditRefund, // method attribution to UPI
                      paymentMethod: originalMethod,
                      description:
                          '${isSessionLinked ? 'SESSION CAFE ' : ''}RETAINED (${originalMethod.toUpperCase()}) · ${refundItems
                              .map(refundItemDescriptionPart)
                              .join(', ')}',
                      items: refundItems
                          .map(transactionItemFromRefundRow)
                          .toList(),
                      customerId: order.customerId,
                      customerName: order.customerName,
                      creditsUsed: 0,
                      cafeCharges: 0,
                    ),
                  );
                }
              } else {
                // Standard refund (same method or to credits)
                // Determine primary refund method and presentation in sales
                String refundMethod = 'refund';
                double effectivePaidTotal = -(refundAmount - creditsRefunded);

                if (creditsRefunded >= refundAmount) {
                  // Full refund to credits
                  refundMethod = 'credit';
                  effectivePaidTotal =
                      0; // No cash/UPI payout when refunded to credits
                } else if (refundPaymentBreakdown != null &&
                    refundPaymentBreakdown.isNotEmpty) {
                  refundMethod = refundPaymentBreakdown.keys.first
                      .toLowerCase();
                }

                // If refund is fully to credits (no cash/upi payout), neutralize sale
                // without adding negative credit usage in analytics.
                final bool isCreditOnlyRefund =
                    creditsRefunded >= refundAmount - 0.0001;
                final String effectiveMethod = isCreditOnlyRefund
                    ? 'credit'
                    : refundMethod;
                // Never show negative credits usage for refunds in analytics
                final double effectiveCreditsUsed = 0.0;

                transactions.add(
                  SalesTransaction(
                    id: '${order.id}_refund_$i',
                    type: transType,
                    date: refundDate,
                    total: -refundAmount,
                    paidTotal: effectivePaidTotal,
                    paymentMethod: effectiveMethod,
                    description:
                        '${isSessionLinked ? 'SESSION CAFE ' : ''}REFUND · ${refundItems
                            .map(refundItemDescriptionPart)
                            .join(', ')}',
                    items: refundItems
                        .map(transactionItemFromRefundRow)
                        .toList(),
                    customerId: order.customerId,
                    customerName: order.customerName,
                    creditsUsed: effectiveCreditsUsed,
                    cafeCharges: -refundAmount,
                  ),
                );
              }
            }

            return transactions;
          }
        case _Collection.merchandiseOrders:
          {
            final merchData = doc.data() as Map<String, dynamic>;
            final order = MerchandiseOrder.fromFirestore(doc);

            // If this order is part of a session AND has no refund history,
            // it's fully represented in the session transaction - skip it.
            // BUT if it has refund history, we need to show those refund transactions separately.
            if (merchData['sessionId'] != null &&
                (merchData['sessionId'] as String).isNotEmpty &&
                (order.refundHistory == null || order.refundHistory!.isEmpty)) {
              return []; // Already aggregated in session
            }
            final List<SalesTransaction> transactions = [];

            // Check if this order is part of a session
            final bool isSessionLinked =
                merchData['sessionId'] != null &&
                (merchData['sessionId'] as String).isNotEmpty;

            // Main order transaction (current state after any refunds)
            // Skip if it's session-linked (already included in session row)
            if (!isSessionLinked) {
              final double creditsUsedM = order.creditsUsed ?? 0.0;
              double paidPortionM = order.total - creditsUsedM;
              if (paidPortionM < 0) paidPortionM = 0;

              String pm;
              if (creditsUsedM.abs() >= order.total.abs() && order.total != 0) {
                pm = 'credit';
              } else {
                if (order.paymentBreakdown != null) {
                  final nonCreditKeys = order.paymentBreakdown!.keys
                      .where((k) => k.toLowerCase() != 'credits')
                      .toList();
                  pm = nonCreditKeys.isNotEmpty
                      ? nonCreditKeys.first.toLowerCase()
                      : (order.paymentMethod?.name ?? 'cash');
                } else {
                  pm = order.paymentMethod?.name ?? 'cash';
                }
                pm = pm == 'credits' ? 'credit' : pm;
              }

              // Add main order transaction (shows current state after refunds)
              // Always add this even if items list is empty (due to full refund)
              final bool hasRefunds =
                  order.refundHistory != null &&
                  order.refundHistory!.isNotEmpty;
              final bool showMainMerchRow =
                  order.items.isNotEmpty || (hasRefunds && order.total != 0);
              if (showMainMerchRow) {
                transactions.add(
                  SalesTransaction(
                    id: order.id,
                    type: TransactionType.merchandise,
                    date: order.createdAt,
                    total: order.total,
                    paidTotal: paidPortionM,
                    paymentMethod: pm,
                    description: order.items.isNotEmpty
                        ? order.items
                              .map((e) => '${e.name} (x${e.quantity})')
                              .join(', ')
                        : 'Fully Refunded Order',
                    items: order.items
                        .map(
                          (e) => TransactionItem(
                            name: e.name,
                            quantity: e.quantity,
                            price: e.price,
                          ),
                        )
                        .toList(),
                    customerId: order.customerId,
                    customerName: order.customerName,
                    creditsUsed: creditsUsedM,
                    merchandiseCharges: order.total,
                  ),
                );
              }
            }

            // Add refund transactions from refundHistory
            // For session-linked orders, also track these refunds to neutralize session breakdown
            if (order.refundHistory != null) {
              for (int i = 0; i < order.refundHistory!.length; i++) {
                final refund = order.refundHistory![i];
                final refundAmount =
                    parseFirestoreDoubleOrNull(refund['refundAmount']) ??
                    parseFirestoreDoubleOrNull(refund['amount']) ??
                    0.0;
                if (refundAmount <= 0) continue;

                // Skip refunds written when the parent session was refunded
                // (already accounted for in the session transaction).
                final refundNote = refund['note'] as String?;
                if (isSessionLinked &&
                    isRefundNoteFromSessionLevelRefund(refundNote)) {
                  continue;
                }

                final refundedAt = refund['refundedAt'];
                DateTime refundDate = order.createdAt;
                if (refundedAt != null) {
                  refundDate = (refundedAt is Timestamp)
                      ? refundedAt.toDate()
                      : order.createdAt;
                }

                final refundItems = refund['items'] as List<dynamic>? ?? [];

                // Extract refund destination info
                final creditsRefunded = parseFirestoreDouble(
                  refund['creditsRefunded'],
                );
                final refundPaymentBreakdown =
                    refund['refundPaymentBreakdown'] as Map<String, dynamic>?;
                final originalPaymentBreakdown =
                    refund['originalPaymentBreakdown'] as Map<String, dynamic>?;
                final useAlternativeMethod =
                    refund['useAlternativeRefundMethod'] as bool? ?? false;

                // For session-linked orders, mark the transaction type appropriately
                final transType = isSessionLinked
                    ? TransactionType
                          .merchandise // Still merchandise, but will be tracked
                    : TransactionType.merchandise;

                // Check if alternative refund method was used
                if (useAlternativeMethod &&
                    originalPaymentBreakdown != null &&
                    refundPaymentBreakdown != null) {
                  // Re-attribution style for merchandise
                  final originalMethod = originalPaymentBreakdown.keys.first
                      .toLowerCase();
                  final altMethod = refundPaymentBreakdown.keys.first
                      .toLowerCase();
                  final nonCreditRefund = refundAmount - creditsRefunded;

                  // Row A: Counter pays via alternative method (negative cash/upi) and goods neutralization
                  transactions.add(
                    SalesTransaction(
                      id: '${order.id}_refund_counter_$i',
                      type: transType,
                      date: refundDate,
                      total: -refundAmount,
                      paidTotal: -nonCreditRefund,
                      paymentMethod: altMethod,
                      description:
                          '${isSessionLinked ? 'SESSION MERCH ' : ''}REFUND PAID (${altMethod.toUpperCase()}) · ${refundItems
                              .map(refundItemDescriptionPart)
                              .join(', ')}',
                      items: refundItems
                          .map(transactionItemFromRefundRow)
                          .toList(),
                      customerId: order.customerId,
                      customerName: order.customerName,
                      creditsUsed: 0,
                      merchandiseCharges: -refundAmount,
                    ),
                  );

                  // Row B: Original method retained (positive method-only)
                  if (nonCreditRefund > 0) {
                    transactions.add(
                      SalesTransaction(
                        id: '${order.id}_refund_retained_$i',
                        type: transType,
                        date: refundDate,
                        total: 0,
                        paidTotal: nonCreditRefund,
                        paymentMethod: originalMethod,
                        description:
                            '${isSessionLinked ? 'SESSION MERCH ' : ''}RETAINED (${originalMethod.toUpperCase()}) · ${refundItems
                                .map(refundItemDescriptionPart)
                                .join(', ')}',
                        items: refundItems
                            .map(transactionItemFromRefundRow)
                            .toList(),
                        customerId: order.customerId,
                        customerName: order.customerName,
                        creditsUsed: 0,
                        merchandiseCharges: 0,
                      ),
                    );
                  }
                } else {
                  // Standard refund (same method or to credits)
                  // Determine primary refund method and presentation in sales
                  String refundMethod = 'refund';
                  double effectivePaidTotal = -(refundAmount - creditsRefunded);

                  if (creditsRefunded >= refundAmount) {
                    // Full refund to credits
                    refundMethod = 'credit';
                    effectivePaidTotal =
                        0; // No cash/UPI payout when refunded to credits
                  } else if (refundPaymentBreakdown != null &&
                      refundPaymentBreakdown.isNotEmpty) {
                    refundMethod = refundPaymentBreakdown.keys.first
                        .toLowerCase();
                  }

                  // If refund is fully to credits (no cash/upi payout), neutralize sale
                  // without adding negative credit usage in analytics.
                  final bool isCreditOnlyRefund =
                      creditsRefunded >= refundAmount - 0.0001;
                  final String effectiveMethod = isCreditOnlyRefund
                      ? 'credit'
                      : refundMethod;
                  // Never show negative credits usage for refunds in analytics
                  final double effectiveCreditsUsed = 0.0;

                  transactions.add(
                    SalesTransaction(
                      id: '${order.id}_refund_$i',
                      type: transType,
                      date: refundDate,
                      total: -refundAmount,
                      paidTotal: effectivePaidTotal,
                      paymentMethod: effectiveMethod,
                      description:
                          '${isSessionLinked ? 'SESSION MERCH ' : ''}REFUND · ${refundItems
                              .map(refundItemDescriptionPart)
                              .join(', ')}',
                      items: refundItems
                          .map(transactionItemFromRefundRow)
                          .toList(),
                      customerId: order.customerId,
                      customerName: order.customerName,
                      creditsUsed: effectiveCreditsUsed,
                      merchandiseCharges: -refundAmount,
                    ),
                  );
                }
              }
            }

            return transactions;
          }
        case _Collection.sessions:
          final session = TableSession.fromFirestore(doc);
          final data = doc.data() as Map<String, dynamic>;

          final bool isRefundedS = session.isRefunded;

          // Component totals from Firestore
          double grossAmount = parseFirestoreDouble(data['grossAmount']);
          final double cafeAmountRaw = parseFirestoreDouble(
            data['totalCafeAmount'],
          );
          final double merchAmountRaw = parseFirestoreDouble(
            data['totalMerchandiseAmount'],
          );

          // Repaired/or legacy sessions can have grossAmount/totalBill stuck at 0 while
          // components exist — derive from stored parts + table charges (no extra Firestore reads).
          if (grossAmount <= 0) {
            final computedGross = session.calculateTotalBillAmount();
            if (computedGross > 0) {
              grossAmount = computedGross;
            }
          }

          // Determine totalBill using available fields (now we have grossAmount).
          final double totalBill =
              session.totalBillAmount ??
              (grossAmount != 0.0
                  ? grossAmount
                  : ((session.totalAmount ?? 0.0) + session.tableCharges));
          final creditsUsed = parseFirestoreDouble(data['creditsUsed']);

          // Session-linked order refunds that are *not* from a full session refund
          // appear as separate SESSION CAFE / SESSION MERCH rows (see cafe/merch cases).

          // If refunded, reflect negative values using stored refundAmount
          final double sessionRefundAmount = parseFirestoreDouble(
            data['refundAmount'],
          );
          // For refunded sessions, neutralize goods proportionally and avoid negative credits usage
          final double effectiveTotalS = isRefundedS
              ? -sessionRefundAmount
              : totalBill;
          double effectiveCreditsUsedS = creditsUsed;
          if (isRefundedS) {
            // Do not report negative credits usage in analytics; credit return is handled in customer balance
            effectiveCreditsUsedS = 0.0;
          }

          String primaryPaymentMethod;
          if (effectiveCreditsUsedS.abs() >= effectiveTotalS.abs() &&
              effectiveTotalS != 0) {
            primaryPaymentMethod = 'credit';
          } else {
            primaryPaymentMethod = session.paymentMode.name.toLowerCase();
          }

          // Extract itemized list if available
          final List<TransactionItem> items = [];
          final rawItems =
              (doc.data() as Map<String, dynamic>)['orderItems'] as List?;
          if (rawItems != null) {
            for (final item in rawItems) {
              final data = Map<String, dynamic>.from(item as Map);
              items.add(
                TransactionItem(
                  name: data['name'] as String? ?? 'Item',
                  quantity: parseFirestoreInt(data['quantity'], fallback: 1),
                  price: parseFirestoreDouble(data['price']),
                ),
              );
            }
          }

          double cafeAmount = cafeAmountRaw;
          double merchAmount = merchAmountRaw;
          double tableAmount = grossAmount - cafeAmountRaw - merchAmountRaw;
          double netTotal = grossAmount;

          if (isRefundedS) {
            // Full session refund - proportionally reduce all components
            final double base = grossAmount <= 0 ? 1.0 : grossAmount;
            final double ratio = (sessionRefundAmount / base).clamp(0.0, 1.0);
            tableAmount = -tableAmount * ratio;
            cafeAmount = -cafeAmount * ratio;
            merchAmount = -merchAmount * ratio;
            netTotal = -(grossAmount * ratio);
          }

          return [
            SalesTransaction(
              id: session.id,
              type: TransactionType.session,
              date: session.endTime ?? session.startTime,
              total: netTotal,
              paidTotal: effectiveTotalS,
              paymentMethod: primaryPaymentMethod,
              description:
                  (isRefundedS ? 'REFUND · ' : '') +
                  (items.isNotEmpty
                      ? items
                            .map((e) => '${e.name} (x${e.quantity})')
                            .join(', ')
                      : 'Session for ${session.tableName}'),
              items: items,
              customerId: session.customerId,
              customerName: session.customerName,
              creditsUsed: effectiveCreditsUsedS,
              tableCharges: tableAmount,
              cafeCharges: cafeAmount,
              merchandiseCharges: merchAmount,
            ),
          ];
        case _Collection.tournamentRegistrations:
          {
            final data = doc.data() as Map<String, dynamic>;

            final status = (data['status'] as String?) ?? 'pending';
            // Use amountPaid as the actual amount - entryFee might not be stored
            final amountPaid = parseFirestoreDouble(data['amountPaid']);
            final entryFee =
                parseFirestoreDoubleOrNull(data['entryFee']) ?? amountPaid;
            final paymentMethod =
                (data['paymentMethod'] as String?)?.toLowerCase() ?? 'cash';
            final tournamentName = data['tournamentName'] as String? ?? '';
            final customerId = data['customerId'] as String? ?? '';
            final customerName = data['customerName'] as String? ?? '';
            final requestedAt =
                (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final approvedAt =
                (data['approvedAt'] as Timestamp?)?.toDate() ?? requestedAt;

            final List<SalesTransaction> transactions = [];

            // Only show approved registrations with actual payment
            if (status == 'approved' && amountPaid > 0) {
              // Use amountPaid as both total and paidTotal to avoid "retained" issue
              final actualAmount = amountPaid > 0 ? amountPaid : entryFee;
              transactions.add(
                SalesTransaction(
                  id: doc.id,
                  type: TransactionType.tournamentRegistration,
                  date: approvedAt,
                  total: actualAmount,
                  paidTotal: actualAmount,
                  paymentMethod: paymentMethod,
                  description: 'Tournament: $tournamentName',
                  items: [
                    TransactionItem(
                      name: 'Tournament Entry - $tournamentName',
                      quantity: 1,
                      price: actualAmount,
                    ),
                  ],
                  customerId: customerId.isEmpty ? null : customerId,
                  customerName: customerName.isEmpty ? null : customerName,
                  tournamentCharges: actualAmount,
                ),
              );
            }

            // Refund entry (negative)
            final bool isRefunded = data['isRefunded'] as bool? ?? false;
            final double refundAmount = parseFirestoreDouble(
              data['refundAmount'],
            );
            final double creditsRefunded = parseFirestoreDouble(
              data['creditsRefunded'],
            );
            if (isRefunded && refundAmount > 0) {
              final refundedAt =
                  (data['refundedAt'] as Timestamp?)?.toDate() ?? approvedAt;
              final refundMethod =
                  (data['refundPaymentMethod'] as String?)?.toLowerCase() ??
                  paymentMethod;
              final nonCreditRefund = refundAmount - creditsRefunded;

              transactions.add(
                SalesTransaction(
                  id: '${doc.id}_refund',
                  type: TransactionType.tournamentRegistration,
                  date: refundedAt,
                  total: -refundAmount,
                  paidTotal: -nonCreditRefund,
                  paymentMethod: refundMethod,
                  description: 'Tournament Refund: $tournamentName',
                  items: [
                    TransactionItem(
                      name: 'Tournament Refund - $tournamentName',
                      quantity: 1,
                      price: -refundAmount,
                    ),
                  ],
                  customerId: customerId.isEmpty ? null : customerId,
                  customerName: customerName.isEmpty ? null : customerName,
                  creditsUsed: -creditsRefunded,
                  tournamentCharges: -refundAmount,
                ),
              );
            }

            return transactions;
          }
        case _Collection.membershipPayments:
          final data = doc.data() as Map<String, dynamic>;
          final pm = (data['paymentMethod'] as String?) ?? 'cash';
          return [
            SalesTransaction(
              id: doc.id,
              type: TransactionType.credit,
              date: (data['createdAt'] as Timestamp).toDate(),
              total: parseFirestoreDouble(data['amount']),
              paymentMethod: pm,
              description: 'Membership/${data['type'] ?? ''}',
              customerId: null,
              customerName: null,
            ),
          ];
        default:
          return [];
      }
    } catch (e) {
      // Catch parsing errors and return empty list to prevent breaking the stream
      AppLogger.warning(
        'Failed to process document ${doc.id}: $e',
        tag: 'SalesDataService',
      );
      return [];
    }
  }

  /// Fetches credit summary data for the given date range.
  ///
  /// Returns a [CreditSummary] containing:
  /// - Total credits sold (manual top-ups paid via cash/upi)
  /// - Total credits allotted (from memberships)
  /// - Total credits spent by customers
  /// - Current total credit balance across all customers
  Future<CreditSummary> getCreditSummary({
    required DateTimeRange dateRange,
  }) async {
    try {
      double totalCreditsSold = 0.0;
      double totalCreditsAllotted = 0.0;
      double grossCreditsSpent = 0.0;
      double totalCreditsRefunded = 0.0;
      double totalCreditBalance = 0.0;
      int topUpCount = 0;
      int spendCount = 0;
      int refundCount = 0;

      final customersSnapshot = await _tenant.customers().get();
      final startTimestamp = Timestamp.fromDate(dateRange.start);
      final endTimestamp = Timestamp.fromDate(dateRange.end);

      void addCreditTxRow(Map<String, dynamic> data) {
        final amount = parseFirestoreDouble(data['amount']);
        final typeStr = (data['type'] as String?)?.toLowerCase() ?? '';
        final method = (data['method'] as String?)?.toLowerCase() ?? 'cash';

        switch (typeStr) {
          case 'manualtopup':
            if (method != 'credits') {
              totalCreditsSold += amount;
              topUpCount++;
            }
            break;
          case 'membership':
          case 'initialbalance':
            totalCreditsAllotted += amount;
            topUpCount++;
            break;
          case 'debit':
            grossCreditsSpent += amount.abs();
            spendCount++;
            break;
          case 'credit':
            totalCreditsRefunded += amount.abs();
            refundCount++;
            break;
        }
      }

      // Per-customer subcollection reads are tenant-scoped and satisfy security
      // rules; unscoped collectionGroup queries are rejected for this data model.
      final rows = await Future.wait(
        customersSnapshot.docs.map((doc) async {
          final data = doc.data();
          final bal = parseFirestoreDouble(data['credits']);
          final snap = await doc.reference
              .collection(FirestoreCollections.creditTransactions)
              .where('date', isGreaterThanOrEqualTo: startTimestamp)
              .where('date', isLessThanOrEqualTo: endTimestamp)
              .get();
          return (balance: bal, txDocs: snap.docs);
        }),
      );

      for (final row in rows) {
        totalCreditBalance += row.balance;
        for (final txDoc in row.txDocs) {
          addCreditTxRow(txDoc.data());
        }
      }

      return CreditSummary(
        totalCreditsSold: totalCreditsSold,
        totalCreditsAllotted: totalCreditsAllotted,
        grossCreditsSpent: grossCreditsSpent,
        totalCreditsRefunded: totalCreditsRefunded,
        totalCreditBalance: totalCreditBalance,
        topUpCount: topUpCount,
        spendCount: spendCount,
        refundCount: refundCount,
      );
    } catch (e) {
      AppLogger.error(
        'Error fetching credit summary',
        error: e,
        tag: 'SalesDataService',
      );
      return const CreditSummary();
    }
  }

  /// Enhanced version of getSalesData that includes credit summary.
  Stream<SalesDataSummary> getSalesDataWithCredits({
    required DateTimeRange dateRange,
    String revenueType = 'all',
    String paymentMethod = 'all',
  }) {
    // Combine the existing sales data stream with credit summary
    return getSalesData(
      dateRange: dateRange,
      revenueType: revenueType,
      paymentMethod: paymentMethod,
    ).asyncMap((summary) async {
      if (summary.isLoading) {
        return summary;
      }

      // Fetch credit summary
      final creditSummary = await getCreditSummary(dateRange: dateRange);

      return summary.copyWith(creditSummary: creditSummary);
    });
  }
}
