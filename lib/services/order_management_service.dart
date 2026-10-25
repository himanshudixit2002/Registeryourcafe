import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/order_config.dart';

class OrderManagementService {
  final TenantRef _tenant;
  OrderManagementService(this._tenant);

  CollectionReference<Map<String, dynamic>> _preOrders() =>
      _tenant.companyDoc().collection('preOrders');
  CollectionReference<Map<String, dynamic>> _tips() =>
      _tenant.companyDoc().collection('tips');
  CollectionReference<Map<String, dynamic>> _orderModifications() =>
      _tenant.companyDoc().collection('orderModifications');

  Future<void> createPreOrder(PreOrder order) async =>
      await _preOrders().add(order.toFirestore());

  Stream<List<PreOrder>> watchPreOrders() => _preOrders()
      .orderBy('scheduledFor')
      .snapshots()
      .map((s) => s.docs.map(PreOrder.fromFirestore).toList());

  Future<void> updatePreOrderStatus(String id, String status) async =>
      await _preOrders().doc(id).update({'status': status});

  Future<void> addTip(TipRecord tip) async =>
      await _tips().add(tip.toFirestore());

  Stream<List<TipRecord>> watchTips({int limit = 50}) => _tips()
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(TipRecord.fromFirestore).toList());

  Future<void> logOrderModification({
    required String orderId,
    required String action,
    required String actorName,
    String? details,
  }) async {
    await _orderModifications().add({
      'orderId': orderId,
      'action': action,
      'actorName': actorName,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveSplitBill(
    String orderId,
    List<SplitBillEntry> entries,
  ) async {
    await _tenant.companyDoc().collection('splitBills').doc(orderId).set({
      'entries': entries.map((e) => e.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
