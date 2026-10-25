import 'package:cloud_firestore/cloud_firestore.dart';
import '../firestore/tenant_firestore.dart';
import '../models/cafe_order.dart';
import '../models/merchandise_order.dart';
import '../models/customer.dart';
import '../models/table.dart';
import '../models/session.dart';
import '../models/app_user.dart';
import '../utils/calculation_utils.dart';
import '../utils/business_validators.dart';
import 'credit_service.dart' hide InsufficientCreditsException;
import 'order_id_service.dart';
import '../utils/firestore_utils.dart';

class OrderService {
  OrderService._();

  static Future<Map<String, StockValidationResult>> validateStockAvailability(
    TenantRef tenant,
    List<OrderItemInput> items,
  ) async {
    final results = <String, StockValidationResult>{};

    for (final item in items) {
      if (item.itemId.isEmpty) continue;

      final stockDoc = await tenant.stockItems().doc(item.itemId).get();
      if (!stockDoc.exists) {
        results[item.itemId] = StockValidationResult(
          itemName: item.name,
          requested: item.quantity,
          available: 0,
          isValid: false,
          reason: 'Item not found in stock',
        );
        continue;
      }

      final stockData = stockDoc.data()!;
      final available = parseFirestoreDouble(stockData['quantity']);
      final trackStock = stockData['trackStock'] as bool? ?? true;

      if (trackStock && available < item.quantity) {
        results[item.itemId] = StockValidationResult(
          itemName: item.name,
          requested: item.quantity,
          available: available,
          isValid: false,
          reason: 'Insufficient stock',
        );
      }
    }

    return results;
  }

  static Future<void> ensureStockAvailable(
    TenantRef tenant,
    List<OrderItemInput> items,
  ) async {
    final validation = await validateStockAvailability(tenant, items);
    if (validation.isNotEmpty) {
      final insufficientItems = validation.entries
          .where((e) => !e.value.isValid)
          .map(
            (e) =>
                '${e.value.itemName}: available ${e.value.available.toStringAsFixed(0)}, requested ${e.value.requested}',
          )
          .join(', ');
      throw InsufficientStockException(
        'Insufficient stock for: $insufficientItems',
      );
    }
  }

  static Future<double> validateAndCalculateCredits({
    required TenantRef tenant,
    required String customerId,
    required double requestedCredits,
    required double orderAmount,
  }) async {
    if (requestedCredits <= 0 || customerId.isEmpty) return 0.0;

    final customerDoc = await tenant.customers().doc(customerId).get();
    if (!customerDoc.exists) return 0.0;

    final customerData = customerDoc.data()!;
    final availableCredits = parseFirestoreDouble(customerData['credits']);

    return CalculationUtils.calculateCreditsToUse(
      requestedCredits: requestedCredits,
      availableCredits: availableCredits,
      maxAmount: orderAmount,
    );
  }

  static Future<CafeOrder> createCafeOrder({
    required TenantRef tenant,
    required List<CafeOrderItem> items,
    required double total,
    Customer? customer,
    SnookerTable? table,
    TableSession? session,
    String? paymentMethod,
    Map<String, double>? paymentBreakdown,
    double creditsUsed = 0.0,
    AppUser? createdBy,
    /// When true (and [session] is null): order stays `pending` / unbilled for kitchen
    /// (e.g. promoted public guest order, pay at venue later).
    bool unbilledKitchenQueue = false,
    String? sourceGuestCafeOrderId,
    String? orderNotes,
  }) async {
    if (items.isEmpty) {
      throw InvalidInputException('Order must have at least one item');
    }

    final itemInputs = items
        .map(
          (i) => OrderItemInput(
            itemId: i.itemId,
            name: i.name,
            quantity: i.quantity,
          ),
        )
        .toList();
    await ensureStockAvailable(tenant, itemInputs);

    double actualCreditsUsed = 0.0;
    if (creditsUsed > 0 && customer != null) {
      actualCreditsUsed = await validateAndCalculateCredits(
        tenant: tenant,
        customerId: customer.id,
        requestedCredits: creditsUsed,
        orderAmount: total,
      );
    }

    final attachSession = session != null;
    final immediateWalkInBilled =
        !attachSession && !unbilledKitchenQueue;
    final pendingKitchen = unbilledKitchenQueue && !attachSession;
    final orderStatus = attachSession || pendingKitchen ? 'pending' : 'delivered';
    final billed = immediateWalkInBilled;

    final orderId = await OrderIdService.generate(tenant, OrderCategory.cafe);
    final batch = tenant.db.batch();

    final orderRef = tenant.cafeOrders().doc(orderId);
    final orderData = {
      'items': items.map((i) => i.toFirestore()).toList(),
      'total': total,
      'status': orderStatus,
      'createdAt': FieldValue.serverTimestamp(),
      'customerId': customer?.id,
      'customerName': customer?.name,
      'tableId': table?.id ?? session?.tableId,
      'tableName': table?.name ?? session?.tableName,
      'sessionId': session?.id,
      'isBilled': billed,
      'billedAt': billed ? FieldValue.serverTimestamp() : null,
      'paymentMethod': ?paymentMethod,
      if (paymentBreakdown != null && paymentBreakdown.isNotEmpty)
        'paymentBreakdown': paymentBreakdown,
      if (actualCreditsUsed > 0) 'creditsUsed': actualCreditsUsed,
      if (createdBy != null) ...{
        'createdById': createdBy.uid,
        'createdByName': createdBy.name,
      },
      if (sourceGuestCafeOrderId != null &&
          sourceGuestCafeOrderId.trim().isNotEmpty)
        'sourceGuestCafeOrderId': sourceGuestCafeOrderId.trim(),
      if (orderNotes != null && orderNotes.trim().isNotEmpty)
        'notes': orderNotes.trim(),
      'isRefunded': false,
    };
    batch.set(orderRef, orderData);

    for (final item in items) {
      if (item.itemId.isEmpty) continue;
      final stockRef = tenant.stockItems().doc(item.itemId);
      batch.update(stockRef, {
        'quantity': FieldValue.increment(-item.quantity),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    if (session != null) {
      final sessionRef = tenant.sessions().doc(session.id);
      batch.update(sessionRef, {
        'cafeOrderIds': FieldValue.arrayUnion([orderId]),
        'totalCafeAmount': FieldValue.increment(total),
        'totalBillAmount': FieldValue.increment(total),
        'hasUnbilledOrders': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // Process credits payment atomically AFTER batch commit to prevent negative balances
    double finalCreditsUsed = 0.0;
    if (actualCreditsUsed > 0 && customer != null && immediateWalkInBilled) {
      // Only debit credits for immediate billed orders (not session-attached or kitchen queue)
      final debitResult = await CreditService.safeDebitCredits(
        tenant: tenant,
        customerId: customer.id,
        amount: actualCreditsUsed,
        reference: CreditReference.cafeOrder(orderId),
        performedBy: createdBy,
      );

      if (!debitResult.success) {
        // Credit debit failed - update order to reflect this
        await tenant.cafeOrders().doc(orderId).update({
          'creditDebitFailed': true,
          'creditDebitError': debitResult.error,
          'creditsUsed': 0,
        });
        throw InsufficientCreditsException(
          debitResult.error ?? 'Credit debit failed',
        );
      }
      finalCreditsUsed = debitResult.actualDebited;
    }

    return CafeOrder(
      id: orderId,
      items: items,
      total: total,
      status: orderStatus,
      createdAt: DateTime.now(),
      customerId: customer?.id,
      customerName: customer?.name,
      tableId: table?.id ?? session?.tableId,
      tableName: table?.name ?? session?.tableName,
      sessionId: session?.id,
      isBilled: billed,
      billedAt: billed ? DateTime.now() : null,
      paymentMethod: paymentMethod != null
          ? PaymentMethod.values.firstWhere(
              (m) => m.name == paymentMethod,
              orElse: () => PaymentMethod.cash,
            )
          : null,
      paymentBreakdown: paymentBreakdown,
      creditsUsed: finalCreditsUsed > 0 ? finalCreditsUsed : null,
      isRefunded: false,
      notes: orderNotes != null && orderNotes.trim().isNotEmpty
          ? orderNotes.trim()
          : null,
    );
  }

  static Future<MerchandiseOrder> createMerchandiseOrder({
    required TenantRef tenant,
    required List<MerchandiseOrderItem> items,
    required double total,
    Customer? customer,
    SnookerTable? table,
    TableSession? session,
    String? paymentMethod,
    Map<String, double>? paymentBreakdown,
    double creditsUsed = 0.0,
    AppUser? createdBy,
  }) async {
    if (items.isEmpty) {
      throw InvalidInputException('Order must have at least one item');
    }

    final itemInputs = items
        .map(
          (i) => OrderItemInput(
            itemId: i.itemId,
            name: i.name,
            quantity: i.quantity,
          ),
        )
        .toList();
    await ensureStockAvailable(tenant, itemInputs);

    double actualCreditsUsed = 0.0;
    if (creditsUsed > 0 && customer != null) {
      actualCreditsUsed = await validateAndCalculateCredits(
        tenant: tenant,
        customerId: customer.id,
        requestedCredits: creditsUsed,
        orderAmount: total,
      );
    }

    final orderId = await OrderIdService.generate(
      tenant,
      OrderCategory.merchandise,
    );
    final batch = tenant.db.batch();

    final orderRef = tenant.merchandiseOrders().doc(orderId);
    final orderData = {
      'items': items.map((i) => i.toFirestore()).toList(),
      'total': total,
      'status': session != null ? 'pending' : 'delivered',
      'createdAt': FieldValue.serverTimestamp(),
      'customerId': customer?.id,
      'customerName': customer?.name,
      'tableId': table?.id ?? session?.tableId,
      'tableName': table?.name ?? session?.tableName,
      'sessionId': session?.id,
      'isBilled': session == null,
      'billedAt': session == null ? FieldValue.serverTimestamp() : null,
      'paymentMethod': ?paymentMethod,
      if (paymentBreakdown != null && paymentBreakdown.isNotEmpty)
        'paymentBreakdown': paymentBreakdown,
      if (actualCreditsUsed > 0) 'creditsUsed': actualCreditsUsed,
      if (createdBy != null) ...{
        'createdById': createdBy.uid,
        'createdByName': createdBy.name,
      },
      'isRefunded': false,
    };
    batch.set(orderRef, orderData);

    for (final item in items) {
      if (item.itemId.isEmpty) continue;
      final stockRef = tenant.stockItems().doc(item.itemId);
      batch.update(stockRef, {
        'quantity': FieldValue.increment(-item.quantity),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    if (session != null) {
      final sessionRef = tenant.sessions().doc(session.id);
      batch.update(sessionRef, {
        'merchandiseOrderIds': FieldValue.arrayUnion([orderId]),
        'totalMerchandiseAmount': FieldValue.increment(total),
        'totalBillAmount': FieldValue.increment(total),
        'hasUnbilledOrders': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // Process credits payment atomically AFTER batch commit to prevent negative balances
    double finalCreditsUsed = 0.0;
    if (actualCreditsUsed > 0 && customer != null && session == null) {
      // Only debit credits for immediate orders (not session-attached)
      final debitResult = await CreditService.safeDebitCredits(
        tenant: tenant,
        customerId: customer.id,
        amount: actualCreditsUsed,
        reference: CreditReference.merchandiseOrder(orderId),
        performedBy: createdBy,
      );

      if (!debitResult.success) {
        // Credit debit failed - update order to reflect this
        await tenant.merchandiseOrders().doc(orderId).update({
          'creditDebitFailed': true,
          'creditDebitError': debitResult.error,
          'creditsUsed': 0,
        });
        throw InsufficientCreditsException(
          debitResult.error ?? 'Credit debit failed',
        );
      }
      finalCreditsUsed = debitResult.actualDebited;
    }

    return MerchandiseOrder(
      id: orderId,
      items: items,
      total: total,
      status: session != null ? 'pending' : 'delivered',
      createdAt: DateTime.now(),
      customerId: customer?.id,
      customerName: customer?.name,
      tableId: table?.id ?? session?.tableId,
      tableName: table?.name ?? session?.tableName,
      sessionId: session?.id,
      isBilled: session == null,
      billedAt: session == null ? DateTime.now() : null,
      paymentMethod: paymentMethod != null
          ? PaymentMethod.values.firstWhere(
              (m) => m.name == paymentMethod,
              orElse: () => PaymentMethod.cash,
            )
          : null,
      paymentBreakdown: paymentBreakdown,
      creditsUsed: finalCreditsUsed > 0 ? finalCreditsUsed : null,
      isRefunded: false,
    );
  }
}

class OrderItemInput {
  final String itemId;
  final String name;
  final int quantity;

  const OrderItemInput({
    required this.itemId,
    required this.name,
    required this.quantity,
  });
}

class StockValidationResult {
  final String itemName;
  final int requested;
  final double available;
  final bool isValid;
  final String? reason;

  const StockValidationResult({
    required this.itemName,
    required this.requested,
    required this.available,
    required this.isValid,
    this.reason,
  });
}
