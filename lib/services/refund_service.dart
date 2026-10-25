import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/effective_permissions.dart';
import '../auth/permission_id.dart';
import '../constants/refund_constants.dart';
import '../firestore/tenant_firestore.dart';
import '../models/app_user.dart';
import '../models/cafe_order.dart';
import '../models/merchandise_order.dart';
import '../models/session.dart';
import '../utils/app_logger.dart';
import '../utils/firestore_utils.dart';
import 'credit_service.dart';
import 'refund_calculation_helper.dart';

class RefundService {
  final TenantRef _tenant;

  RefundService(this._tenant);

  void _assertRefundAllowed(EffectivePermissions permissions) {
    if (!permissions.can(PermissionIds.opsRefund)) {
      throw Exception('You do not have permission to process refunds.');
    }
  }

  Future<_SessionContext> _getSessionContext(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) {
      return _SessionContext.empty();
    }

    final snap = await _tenant.sessions().doc(sessionId).get();
    if (!snap.exists) {
      return _SessionContext.empty();
    }

    final data = snap.data() as Map<String, dynamic>;
    return _SessionContext(
      sessionId: sessionId,
      isActive: data['status'] == 'active',
      isCompleted: data['status'] == 'completed',
      isRefunded: data['isRefunded'] as bool? ?? false,
      paymentMode: (data['paymentMode'] as String?)?.toLowerCase(),
      creditsUsed: parseFirestoreDouble(data['creditsUsed']),
      creditsAlreadyRefunded: parseFirestoreDouble(data['creditsRefunded']),
      totalBillAmount: parseFirestoreDouble(data['totalBillAmount']),
    );
  }

  void _restoreStock(WriteBatch batch, List<_RefundItem> items) {
    for (final item in items) {
      if (item.itemId.isEmpty) continue;
      batch.update(_tenant.stockItems().doc(item.itemId), {
        'quantity': FieldValue.increment(item.quantity.toDouble()),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  void _refundCustomerCredits(
    WriteBatch batch,
    String? customerId,
    double amount,
    String orderId,
    AppUser admin,
    String note,
  ) {
    if (amount <= 0 || customerId == null || customerId.isEmpty) return;

    CreditService.creditCredits(
      tenant: _tenant,
      batch: batch,
      customerId: customerId,
      amount: amount,
      reference: CreditReference.refund(orderId),
      performedBy: admin,
      note: note,
    );
  }

  void _updateSessionCreditsRefunded(
    WriteBatch batch,
    String sessionId,
    double creditsRefunded,
  ) {
    if (sessionId.isEmpty || creditsRefunded <= 0) return;

    batch.update(_tenant.sessions().doc(sessionId), {
      'creditsRefunded': FieldValue.increment(creditsRefunded),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _buildRefundEntry(
    AppUser admin,
    double amount,
    double creditsRefunded,
    List<_RefundItem> items,
    Map<String, double>? breakdown,
    Map<String, dynamic>? originalBreakdown,
    bool useAlt, {
    String? note,
  }) {
    return {
      'refundedAt': Timestamp.now(),
      'refundedById': admin.uid,
      'refundedByName': admin.name,
      'refundedByRole': admin.role.name,
      'items': items
          .map(
            (it) => {
              'itemId': it.itemId,
              'name': it.name,
              'price': it.price,
              'quantity': it.quantity,
            },
          )
          .toList(),
      'amount': amount,
      'creditsRefunded': creditsRefunded,
      'refundPaymentBreakdown': ?breakdown,
      'originalPaymentBreakdown': ?originalBreakdown,
      if (useAlt) 'useAlternativeRefundMethod': useAlt,
      'note': ?note,
    };
  }

  Future<void> refundCafeOrder({
    required EffectivePermissions permissions,
    required String orderId,
    required AppUser admin,
    double? amount,
    bool refundRemainderToCredits = false,
    bool useAlternativeMethod = false,
    String? alternativeMethod,
  }) async {
    _assertRefundAllowed(permissions);
    final docRef = _tenant.cafeOrders().doc(orderId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Cafe order not found');

    final order = CafeOrder.fromFirestore(doc);
    if (order.isRefunded) throw Exception('Order has already been refunded');

    final ctx = await _getSessionContext(order.sessionId);
    if (ctx.isActive) {
      throw Exception(
        'Cannot refund order from active session. End the session first.',
      );
    }

    final refundAmount = amount ?? order.total;
    if (refundAmount <= 0 || refundAmount > order.total) {
      throw Exception('Invalid refund amount');
    }

    final orderCreditsUsed = order.creditsUsed ?? 0;
    final allocation = RefundCalculationHelper.calculateRefundAllocation(
      refundAmount: refundAmount,
      creditsUsed: orderCreditsUsed,
      originalTotal: order.total,
      refundRemainderToCredits: refundRemainderToCredits,
    );

    if (ctx.hasSession && allocation.creditsRefundedFinal > 0) {
      final remainingSessionCredits =
          ctx.creditsUsed - ctx.creditsAlreadyRefunded;
      if (allocation.creditsRefundedFinal >
          remainingSessionCredits + orderCreditsUsed) {
        AppLogger.warning(
          'Credit refund (${allocation.creditsRefundedFinal}) exceeds remaining ($remainingSessionCredits)',
          tag: 'RefundService',
        );
      }
    }

    final fallback = RefundCalculationHelper.determineFallbackPaymentMethod(
      orderPaymentMethod: order.paymentMethod?.name,
      sessionPaymentMode: ctx.paymentMode,
    );

    final paymentResult = RefundCalculationHelper.buildRefundPaymentBreakdown(
      nonCreditToRefund: allocation.nonCreditToRefund,
      originalPaymentBreakdown:
          order.paymentBreakdown?.map((k, v) => MapEntry(k, v.toDouble())) ??
          {},
      fallbackPaymentMethod: fallback,
      useAlternativeMethod: useAlternativeMethod,
      alternativeMethod: alternativeMethod,
    );

    final batch = _tenant.db.batch();
    final items = order.items
        .map((it) => _RefundItem(it.itemId, it.name, it.price, it.quantity))
        .toList();

    final entry = _buildRefundEntry(
      admin,
      refundAmount,
      allocation.creditsRefundedFinal,
      items,
      paymentResult.refundPaymentBreakdown,
      paymentResult.originalPaymentBreakdown,
      useAlternativeMethod,
    );

    batch.update(docRef, {
      'isRefunded': true,
      'refundAmount': refundAmount,
      'status': 'refunded',
      'refundedAt': FieldValue.serverTimestamp(),
      'refundedById': admin.uid,
      'refundedByName': admin.name,
      'refundedByRole': admin.role.name,
      if (paymentResult.refundPaymentBreakdown != null)
        'refundPaymentBreakdown': paymentResult.refundPaymentBreakdown,
      'refundHistory': FieldValue.arrayUnion([entry]),
      'items': <Map<String, dynamic>>[],
      'total': 0.0,
      'creditsUsed': 0.0,
    });

    _refundCustomerCredits(
      batch,
      order.customerId,
      allocation.creditsRefundedFinal,
      order.id,
      admin,
      'Refund cafe order ${order.id}',
    );

    if (ctx.hasSession && allocation.creditsRefundedFinal > 0) {
      _updateSessionCreditsRefunded(
        batch,
        ctx.sessionId!,
        allocation.creditsRefundedFinal,
      );
    }

    _restoreStock(batch, items);
    await batch.commit();

    AppLogger.info(
      'Refunded cafe order $orderId: ₹$refundAmount, credits ₹${allocation.creditsRefundedFinal}',
      tag: 'RefundService',
    );
  }

  Future<void> refundCafeOrderItemsWithQuantities({
    required EffectivePermissions permissions,
    required String orderId,
    required List<Map<String, dynamic>> items,
    required AppUser admin,
    bool refundRemainderToCredits = false,
    bool useAlternativeMethod = false,
    String? alternativeMethod,
  }) async {
    _assertRefundAllowed(permissions);
    final docRef = _tenant.cafeOrders().doc(orderId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Cafe order not found');

    final order = CafeOrder.fromFirestore(snap);
    if (order.isRefunded) throw Exception('Order already refunded');
    if (items.isEmpty) return;

    final ctx = await _getSessionContext(order.sessionId);

    double refundAmount = 0.0;
    final List<CafeOrderItem> updatedItems = [];
    final List<_RefundItem> refundedItems = [];

    for (final orderItem in order.items) {
      final refundItem = items.firstWhere(
        (item) => item['itemId'] == orderItem.itemId,
        orElse: () => <String, dynamic>{},
      );
      if (refundItem.isNotEmpty) {
        final int refundQty = refundItem['quantity'] as int;
        if (refundQty > 0 && refundQty <= orderItem.quantity) {
          refundAmount += orderItem.price * refundQty;
          refundedItems.add(
            _RefundItem(
              orderItem.itemId,
              orderItem.name,
              orderItem.price,
              refundQty,
            ),
          );
          if (refundQty < orderItem.quantity) {
            updatedItems.add(
              CafeOrderItem(
                itemId: orderItem.itemId,
                name: orderItem.name,
                price: orderItem.price,
                quantity: orderItem.quantity - refundQty,
                notes: orderItem.notes,
                imageUrl: orderItem.imageUrl,
              ),
            );
          }
        }
      } else {
        updatedItems.add(orderItem);
      }
    }

    if (refundAmount <= 0) return;

    final allocation = RefundCalculationHelper.calculateRefundAllocation(
      refundAmount: refundAmount,
      creditsUsed: order.creditsUsed ?? 0,
      originalTotal: order.total,
      refundRemainderToCredits: refundRemainderToCredits,
      isActiveSession: ctx.isActive,
    );

    final fallback = RefundCalculationHelper.determineFallbackPaymentMethod(
      orderPaymentMethod: order.paymentMethod?.name,
      sessionPaymentMode: ctx.paymentMode,
    );

    final paymentResult = ctx.isActive
        ? const RefundPaymentResult()
        : RefundCalculationHelper.buildRefundPaymentBreakdown(
            nonCreditToRefund: allocation.nonCreditToRefund,
            originalPaymentBreakdown:
                order.paymentBreakdown?.map(
                  (k, v) => MapEntry(k, v.toDouble()),
                ) ??
                {},
            fallbackPaymentMethod: fallback,
            useAlternativeMethod: useAlternativeMethod,
            alternativeMethod: alternativeMethod,
          );

    final batch = _tenant.db.batch();
    _restoreStock(batch, refundedItems);

    if (!ctx.isActive && allocation.creditsRefundedFinal > 0) {
      _refundCustomerCredits(
        batch,
        order.customerId,
        allocation.creditsRefundedFinal,
        order.id,
        admin,
        'Partial refund cafe order ${order.id}',
      );

      if (ctx.hasSession) {
        _updateSessionCreditsRefunded(
          batch,
          ctx.sessionId!,
          allocation.creditsRefundedFinal,
        );
      }
    }

    final newTotals = RefundCalculationHelper.calculateNewOrderTotals(
      originalTotal: order.total,
      originalCreditsUsed: order.creditsUsed ?? 0,
      refundAmount: refundAmount,
      creditsToRefund: allocation.creditsToRefund,
    );

    final entry = {
      'refundedAt': Timestamp.now(),
      'refundedById': admin.uid,
      'refundedByName': admin.name,
      'refundedByRole': admin.role.name,
      'refundAmount': refundAmount,
      'creditsRefunded': allocation.creditsRefundedFinal,
      'items': refundedItems
          .map(
            (it) => {
              'itemId': it.itemId,
              'name': it.name,
              'price': it.price,
              'quantity': it.quantity,
            },
          )
          .toList(),
      if (paymentResult.originalPaymentBreakdown != null)
        'originalPaymentBreakdown': paymentResult.originalPaymentBreakdown,
      if (paymentResult.refundPaymentBreakdown != null)
        'refundPaymentBreakdown': paymentResult.refundPaymentBreakdown,
    };

    final orderUpdate = <String, dynamic>{
      'items': updatedItems.map((it) => it.toFirestore()).toList(),
      'total': newTotals.newTotal,
      'creditsUsed': newTotals.newCreditsUsed,
      'refundHistory': FieldValue.arrayUnion([entry]),
    };

    if (updatedItems.isEmpty) {
      orderUpdate['isRefunded'] = true;
      orderUpdate['refundAmount'] = (order.refundAmount ?? 0.0) + refundAmount;
      orderUpdate['status'] = 'refunded';
    }

    batch.update(docRef, orderUpdate);
    await batch.commit();

    AppLogger.info(
      'Partial refund cafe $orderId: ₹$refundAmount, credits ₹${allocation.creditsRefundedFinal}',
      tag: 'RefundService',
    );
  }

  Future<void> refundCafeOrderItems({
    required EffectivePermissions permissions,
    required String orderId,
    required List<int> itemIndexesToRefund,
    required AppUser admin,
    bool refundRemainderToCredits = false,
    bool useAlternativeMethod = false,
    String? alternativeMethod,
  }) async {
    _assertRefundAllowed(permissions);
    final docRef = _tenant.cafeOrders().doc(orderId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Cafe order not found');

    final order = CafeOrder.fromFirestore(snap);
    if (order.isRefunded) throw Exception('Order already refunded');
    if (itemIndexesToRefund.isEmpty) return;

    final itemsToRefund = <Map<String, dynamic>>[];
    for (int i = 0; i < order.items.length; i++) {
      if (itemIndexesToRefund.contains(i)) {
        final it = order.items[i];
        itemsToRefund.add({
          'itemId': it.itemId,
          'name': it.name,
          'price': it.price,
          'quantity': it.quantity,
        });
      }
    }

    await refundCafeOrderItemsWithQuantities(
      permissions: permissions,
      orderId: orderId,
      items: itemsToRefund,
      admin: admin,
      refundRemainderToCredits: refundRemainderToCredits,
      useAlternativeMethod: useAlternativeMethod,
      alternativeMethod: alternativeMethod,
    );
  }

  Future<void> refundMerchandiseOrder({
    required EffectivePermissions permissions,
    required String orderId,
    required AppUser admin,
    double? amount,
    bool refundRemainderToCredits = false,
    bool useAlternativeMethod = false,
    String? alternativeMethod,
  }) async {
    _assertRefundAllowed(permissions);
    final docRef = _tenant.merchandiseOrders().doc(orderId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Merchandise order not found');

    final order = MerchandiseOrder.fromFirestore(doc);
    if (order.isRefunded) throw Exception('Order has already been refunded');

    final ctx = await _getSessionContext(order.sessionId);
    if (ctx.isActive) {
      throw Exception(
        'Cannot refund order from active session. End the session first.',
      );
    }

    final refundAmount = amount ?? order.total;
    if (refundAmount <= 0 || refundAmount > order.total) {
      throw Exception('Invalid refund amount');
    }

    final allocation = RefundCalculationHelper.calculateRefundAllocation(
      refundAmount: refundAmount,
      creditsUsed: order.creditsUsed ?? 0,
      originalTotal: order.total,
      refundRemainderToCredits: refundRemainderToCredits,
    );

    final fallback = RefundCalculationHelper.determineFallbackPaymentMethod(
      orderPaymentMethod: order.paymentMethod?.name,
      sessionPaymentMode: ctx.paymentMode,
    );

    final paymentResult = RefundCalculationHelper.buildRefundPaymentBreakdown(
      nonCreditToRefund: allocation.nonCreditToRefund,
      originalPaymentBreakdown:
          order.paymentBreakdown?.map((k, v) => MapEntry(k, v.toDouble())) ??
          {},
      fallbackPaymentMethod: fallback,
      useAlternativeMethod: useAlternativeMethod,
      alternativeMethod: alternativeMethod,
    );

    final batch = _tenant.db.batch();
    final items = order.items
        .map((it) => _RefundItem(it.itemId, it.name, it.price, it.quantity))
        .toList();

    final entry = _buildRefundEntry(
      admin,
      refundAmount,
      allocation.creditsRefundedFinal,
      items,
      paymentResult.refundPaymentBreakdown,
      paymentResult.originalPaymentBreakdown,
      useAlternativeMethod,
    );

    batch.update(docRef, {
      'isRefunded': true,
      'refundAmount': refundAmount,
      'status': 'refunded',
      'refundedAt': FieldValue.serverTimestamp(),
      'refundedById': admin.uid,
      'refundedByName': admin.name,
      'refundedByRole': admin.role.name,
      if (paymentResult.refundPaymentBreakdown != null)
        'refundPaymentBreakdown': paymentResult.refundPaymentBreakdown,
      'refundHistory': FieldValue.arrayUnion([entry]),
      'items': <Map<String, dynamic>>[],
      'total': 0.0,
      'creditsUsed': 0.0,
    });

    _refundCustomerCredits(
      batch,
      order.customerId,
      allocation.creditsRefundedFinal,
      order.id,
      admin,
      'Refund merchandise order ${order.id}',
    );

    if (ctx.hasSession && allocation.creditsRefundedFinal > 0) {
      _updateSessionCreditsRefunded(
        batch,
        ctx.sessionId!,
        allocation.creditsRefundedFinal,
      );
    }

    _restoreStock(batch, items);
    await batch.commit();

    AppLogger.info(
      'Refunded merchandise $orderId: ₹$refundAmount, credits ₹${allocation.creditsRefundedFinal}',
      tag: 'RefundService',
    );
  }

  Future<void> refundMerchandiseOrderItemsWithQuantities({
    required EffectivePermissions permissions,
    required String orderId,
    required List<Map<String, dynamic>> items,
    required AppUser admin,
    bool refundRemainderToCredits = false,
    bool useAlternativeMethod = false,
    String? alternativeMethod,
  }) async {
    _assertRefundAllowed(permissions);
    final docRef = _tenant.merchandiseOrders().doc(orderId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Merchandise order not found');

    final order = MerchandiseOrder.fromFirestore(snap);
    if (order.isRefunded) throw Exception('Order already refunded');
    if (items.isEmpty) return;

    final ctx = await _getSessionContext(order.sessionId);

    double refundAmount = 0.0;
    final List<MerchandiseOrderItem> updatedItems = [];
    final List<_RefundItem> refundedItems = [];

    for (final orderItem in order.items) {
      final refundItem = items.firstWhere(
        (item) => item['itemId'] == orderItem.itemId,
        orElse: () => <String, dynamic>{},
      );
      if (refundItem.isNotEmpty) {
        final int refundQty = refundItem['quantity'] as int;
        if (refundQty > 0 && refundQty <= orderItem.quantity) {
          refundAmount += orderItem.price * refundQty;
          refundedItems.add(
            _RefundItem(
              orderItem.itemId,
              orderItem.name,
              orderItem.price,
              refundQty,
            ),
          );
          if (refundQty < orderItem.quantity) {
            updatedItems.add(
              MerchandiseOrderItem(
                itemId: orderItem.itemId,
                name: orderItem.name,
                price: orderItem.price,
                quantity: orderItem.quantity - refundQty,
                notes: orderItem.notes,
              ),
            );
          }
        }
      } else {
        updatedItems.add(orderItem);
      }
    }

    if (refundAmount <= 0) return;

    final allocation = RefundCalculationHelper.calculateRefundAllocation(
      refundAmount: refundAmount,
      creditsUsed: order.creditsUsed ?? 0,
      originalTotal: order.total,
      refundRemainderToCredits: refundRemainderToCredits,
      isActiveSession: ctx.isActive,
    );

    final fallback = RefundCalculationHelper.determineFallbackPaymentMethod(
      orderPaymentMethod: order.paymentMethod?.name,
      sessionPaymentMode: ctx.paymentMode,
    );

    final paymentResult = ctx.isActive
        ? const RefundPaymentResult()
        : RefundCalculationHelper.buildRefundPaymentBreakdown(
            nonCreditToRefund: allocation.nonCreditToRefund,
            originalPaymentBreakdown:
                order.paymentBreakdown?.map(
                  (k, v) => MapEntry(k, v.toDouble()),
                ) ??
                {},
            fallbackPaymentMethod: fallback,
            useAlternativeMethod: useAlternativeMethod,
            alternativeMethod: alternativeMethod,
          );

    final batch = _tenant.db.batch();
    _restoreStock(batch, refundedItems);

    if (!ctx.isActive && allocation.creditsRefundedFinal > 0) {
      _refundCustomerCredits(
        batch,
        order.customerId,
        allocation.creditsRefundedFinal,
        order.id,
        admin,
        'Partial refund merchandise ${order.id}',
      );

      if (ctx.hasSession) {
        _updateSessionCreditsRefunded(
          batch,
          ctx.sessionId!,
          allocation.creditsRefundedFinal,
        );
      }
    }

    final newTotals = RefundCalculationHelper.calculateNewOrderTotals(
      originalTotal: order.total,
      originalCreditsUsed: order.creditsUsed ?? 0,
      refundAmount: refundAmount,
      creditsToRefund: allocation.creditsToRefund,
    );

    final entry = {
      'refundedAt': Timestamp.now(),
      'refundedById': admin.uid,
      'refundedByName': admin.name,
      'refundedByRole': admin.role.name,
      'refundAmount': refundAmount,
      'creditsRefunded': allocation.creditsRefundedFinal,
      'items': refundedItems
          .map(
            (it) => {
              'itemId': it.itemId,
              'name': it.name,
              'price': it.price,
              'quantity': it.quantity,
            },
          )
          .toList(),
      if (paymentResult.originalPaymentBreakdown != null)
        'originalPaymentBreakdown': paymentResult.originalPaymentBreakdown,
      if (paymentResult.refundPaymentBreakdown != null)
        'refundPaymentBreakdown': paymentResult.refundPaymentBreakdown,
    };

    final orderUpdate = <String, dynamic>{
      'items': updatedItems.map((it) => it.toFirestore()).toList(),
      'total': newTotals.newTotal,
      'creditsUsed': newTotals.newCreditsUsed,
      'refundHistory': FieldValue.arrayUnion([entry]),
    };

    if (updatedItems.isEmpty) {
      orderUpdate['isRefunded'] = true;
      orderUpdate['refundAmount'] = (order.refundAmount ?? 0.0) + refundAmount;
      orderUpdate['status'] = 'refunded';
    }

    batch.update(docRef, orderUpdate);
    await batch.commit();

    AppLogger.info(
      'Partial refund merchandise $orderId: ₹$refundAmount, credits ₹${allocation.creditsRefundedFinal}',
      tag: 'RefundService',
    );
  }

  Future<void> refundMerchandiseOrderItems({
    required EffectivePermissions permissions,
    required String orderId,
    required List<int> itemIndexesToRefund,
    required AppUser admin,
    bool refundRemainderToCredits = false,
    bool useAlternativeMethod = false,
    String? alternativeMethod,
  }) async {
    _assertRefundAllowed(permissions);
    final docRef = _tenant.merchandiseOrders().doc(orderId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Merchandise order not found');

    final order = MerchandiseOrder.fromFirestore(snap);
    if (order.isRefunded) throw Exception('Order already refunded');
    if (itemIndexesToRefund.isEmpty) return;

    final itemsToRefund = <Map<String, dynamic>>[];
    for (int i = 0; i < order.items.length; i++) {
      if (itemIndexesToRefund.contains(i)) {
        final it = order.items[i];
        itemsToRefund.add({
          'itemId': it.itemId,
          'name': it.name,
          'price': it.price,
          'quantity': it.quantity,
        });
      }
    }

    await refundMerchandiseOrderItemsWithQuantities(
      permissions: permissions,
      orderId: orderId,
      items: itemsToRefund,
      admin: admin,
      refundRemainderToCredits: refundRemainderToCredits,
      useAlternativeMethod: useAlternativeMethod,
      alternativeMethod: alternativeMethod,
    );
  }

  Future<void> refundSession({
    required EffectivePermissions permissions,
    required String sessionId,
    required AppUser admin,
    double? amount,
  }) async {
    _assertRefundAllowed(permissions);

    final docRef = _tenant.sessions().doc(sessionId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Session not found');

    final session = TableSession.fromFirestore(doc);
    if (session.isRefunded) {
      throw Exception('Session has already been fully refunded');
    }
    if (session.status == SessionStatus.active) {
      throw Exception(
        'Cannot refund an active session. End the session first.',
      );
    }

    final sessionCreditsUsed = session.creditsUsed ?? 0;
    final creditsAlreadyRefunded = session.creditsRefunded ?? 0.0;
    final creditsToRefund = (sessionCreditsUsed - creditsAlreadyRefunded).clamp(
      0.0,
      double.infinity,
    );

    final sessionTotal = session.effectiveSessionRefundCap;
    final refundAmount = amount ?? sessionTotal;

    if (refundAmount < 0) {
      throw Exception('Invalid refund amount');
    }
    if (sessionTotal > 0 && refundAmount > sessionTotal) {
      throw Exception('Invalid refund amount');
    }
    // No reliable cash cap (e.g. legacy/orphan data) — block non-zero cash refund.
    if (refundAmount > 0 && sessionTotal <= 0) {
      throw Exception('Invalid refund amount');
    }
    if (refundAmount <= 0 && creditsToRefund <= 0) {
      throw Exception('Invalid refund amount');
    }

    final cafeOrders = await _tenant
        .cafeOrders()
        .where('sessionId', isEqualTo: session.id)
        .get();
    final merchOrders = await _tenant
        .merchandiseOrders()
        .where('sessionId', isEqualTo: session.id)
        .get();

    final batch = _tenant.db.batch();

    batch.update(docRef, {
      'isRefunded': true,
      'refundAmount': refundAmount,
      'status': 'refunded',
      'creditsRefunded': sessionCreditsUsed,
      'refundedAt': FieldValue.serverTimestamp(),
      'refundedById': admin.uid,
      'refundedByName': admin.name,
      'refundedByRole': admin.role.name,
    });

    if (creditsToRefund > 0 && session.customerId.isNotEmpty) {
      _refundCustomerCredits(
        batch,
        session.customerId,
        creditsToRefund,
        session.id,
        admin,
        'Refund session ${session.id}',
      );
    }

    for (final o in cafeOrders.docs) {
      final order = CafeOrder.fromFirestore(o);
      if (order.status.toLowerCase() == 'cancelled') continue;
      if (!order.isRefunded) {
        _refundLinkedOrder(
          batch,
          'cafe_orders',
          order.id,
          order.items
              .map(
                (it) => _RefundItem(it.itemId, it.name, it.price, it.quantity),
              )
              .toList(),
          order.total,
          order.creditsUsed ?? 0,
          session.paymentMode.name.toLowerCase(),
          admin,
        );
      }
    }

    for (final o in merchOrders.docs) {
      final order = MerchandiseOrder.fromFirestore(o);
      if (order.status.toLowerCase() == 'cancelled') continue;
      if (!order.isRefunded) {
        _refundLinkedOrder(
          batch,
          'merchandise_orders',
          order.id,
          order.items
              .map(
                (it) => _RefundItem(it.itemId, it.name, it.price, it.quantity),
              )
              .toList(),
          order.total,
          order.creditsUsed ?? 0,
          session.paymentMode.name.toLowerCase(),
          admin,
        );
      }
    }

    await batch.commit();

    AppLogger.info(
      'Refunded session $sessionId: ₹$refundAmount, credits ₹$creditsToRefund',
      tag: 'RefundService',
    );
  }

  void _refundLinkedOrder(
    WriteBatch batch,
    String collection,
    String orderId,
    List<_RefundItem> items,
    double total,
    double creditsUsed,
    String paymentMode,
    AppUser admin,
  ) {
    final DocumentReference<Map<String, dynamic>> orderRef =
        collection == 'cafe_orders'
        ? _tenant.cafeOrders().doc(orderId)
        : _tenant.merchandiseOrders().doc(orderId);
    final nonCreditPortion = (total - creditsUsed).clamp(0.0, total);

    final breakdown = <String, double>{};
    if (creditsUsed > 0) {
      breakdown['credits'] = creditsUsed;
    }
    if (nonCreditPortion > 0) {
      breakdown[paymentMode] = nonCreditPortion;
    }

    final now = Timestamp.now();
    final entry = {
      'refundedAt': now,
      'refundedById': admin.uid,
      'refundedByName': admin.name,
      'refundedByRole': admin.role.name,
      'refundAmount': total,
      'creditsRefunded': creditsUsed,
      if (breakdown.isNotEmpty) 'refundPaymentBreakdown': breakdown,
      'items': items
          .map(
            (it) => {
              'itemId': it.itemId,
              'name': it.name,
              'price': it.price,
              'quantity': it.quantity,
            },
          )
          .toList(),
      'note': kRefundHistoryNoteFullSessionRefund,
    };

    batch.update(orderRef, {
      'isRefunded': true,
      'refundAmount': total,
      'status': 'refunded',
      'refundedAt': now,
      'refundedById': admin.uid,
      'refundedByName': admin.name,
      'refundedByRole': admin.role.name,
      'items': <Map<String, dynamic>>[],
      'total': 0.0,
      'creditsUsed': 0.0,
      'refundHistory': FieldValue.arrayUnion([entry]),
    });

    _restoreStock(batch, items);
  }
}

class _SessionContext {
  final String? sessionId;
  final bool isActive;
  final bool isCompleted;
  final bool isRefunded;
  final String? paymentMode;
  final double creditsUsed;
  final double creditsAlreadyRefunded;
  final double totalBillAmount;

  _SessionContext({
    this.sessionId,
    required this.isActive,
    this.isCompleted = false,
    this.isRefunded = false,
    this.paymentMode,
    this.creditsUsed = 0,
    this.creditsAlreadyRefunded = 0,
    this.totalBillAmount = 0,
  });

  factory _SessionContext.empty() =>
      _SessionContext(isActive: false, isCompleted: false, isRefunded: false);

  bool get hasSession => sessionId != null && sessionId!.isNotEmpty;
}

class _RefundItem {
  final String itemId;
  final String name;
  final double price;
  final int quantity;

  _RefundItem(this.itemId, this.name, this.price, this.quantity);
}
