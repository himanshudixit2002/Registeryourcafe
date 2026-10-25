import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/inventory_advanced.dart';

class InventoryAdvancedService {
  final TenantRef _tenant;

  InventoryAdvancedService(this._tenant);

  CollectionReference<Map<String, dynamic>> _purchaseOrders() =>
      _tenant.companyDoc().collection('purchaseOrders');

  CollectionReference<Map<String, dynamic>> _expiryRecords() =>
      _tenant.companyDoc().collection('expiryRecords');

  CollectionReference<Map<String, dynamic>> _supplierScores() =>
      _tenant.companyDoc().collection('supplierScores');

  Future<void> createPurchaseOrder(PurchaseOrder po) async =>
      await _purchaseOrders().add(po.toFirestore());

  Stream<List<PurchaseOrder>> watchPurchaseOrders() => _purchaseOrders()
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(PurchaseOrder.fromFirestore).toList());

  Future<void> updatePOStatus(String id, String status) async =>
      await _purchaseOrders().doc(id).update({'status': status});

  Future<void> addExpiryRecord(ExpiryRecord record) async =>
      await _expiryRecords().add(record.toFirestore());

  Stream<List<ExpiryRecord>> watchExpiringItems({int daysAhead = 30}) {
    final cutoff = DateTime.now().add(Duration(days: daysAhead));
    return _expiryRecords()
        .where(
          'expiryDate',
          isLessThanOrEqualTo: Timestamp.fromDate(cutoff),
        )
        .orderBy('expiryDate')
        .snapshots()
        .map((s) => s.docs.map(ExpiryRecord.fromFirestore).toList());
  }

  Future<void> scoreSupplier(
    String vendorId,
    double score,
    String? note,
  ) async {
    await _supplierScores().doc(vendorId).set(
      {
        'score': score,
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setStockAlertThreshold(
    String itemId,
    double threshold,
  ) async =>
      await _tenant.stockItems().doc(itemId).update({
        'alertThreshold': threshold,
      });
}
