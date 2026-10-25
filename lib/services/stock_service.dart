import 'package:cloud_firestore/cloud_firestore.dart';
import '../firestore/tenant_firestore.dart';
import '../models/stock_item.dart';
import 'public_venue_sync_service.dart';
import '../utils/app_logger.dart';
import '../utils/business_validators.dart';
import '../utils/firestore_utils.dart';

/// Stock quantity updates with optional `stock_items/{id}/history` audit rows.
/// Vendor receiving uses [StockReceiptService.commitReceipt], which writes the same
/// history shape plus `receiptId`, `vendorId`, and `unitCost`.
class StockService {
  StockService._();

  static Future<void> _refreshPublicMenuMirror(
    TenantRef tenant,
    String itemId,
  ) async {
    try {
      final item = await getById(tenant, itemId);
      if (item == null) {
        await PublicVenueSyncService.removePublicMenuMirrorForStockId(
          tenant,
          itemId,
        );
      } else {
        await PublicVenueSyncService.syncPublicMenuFromStockItem(tenant, item);
      }
    } catch (e, st) {
      AppLogger.error(
        'Public menu mirror refresh failed (stock item $itemId)',
        tag: 'StockService',
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<StockItem?> getById(TenantRef tenant, String itemId) async {
    if (itemId.isEmpty) return null;
    final doc = await tenant.stockItems().doc(itemId).get();
    if (!doc.exists) return null;
    return StockItem.fromFirestore(doc);
  }

  static Stream<List<StockItem>> watchAll(TenantRef tenant) {
    return tenant
        .stockItems()
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => StockItem.fromFirestore(d)).toList(),
        );
  }

  static Future<List<StockItem>> getLowStockItems(
    TenantRef tenant, {
    double defaultThreshold = 10,
  }) async {
    final snapshot = await tenant.stockItems().get();
    return snapshot.docs.map((d) => StockItem.fromFirestore(d)).where((item) {
      final threshold = item.lowStockThreshold > 0
          ? item.lowStockThreshold
          : defaultThreshold;
      return item.quantity <= threshold;
    }).toList();
  }

  static Future<List<StockItem>> getOutOfStockItems(TenantRef tenant) async {
    final snapshot = await tenant
        .stockItems()
        .where('quantity', isLessThanOrEqualTo: 0)
        .get();
    return snapshot.docs.map((d) => StockItem.fromFirestore(d)).toList();
  }

  static Future<void> updateQuantity({
    required TenantRef tenant,
    required String itemId,
    required double adjustment,
    String? reason,
    String? updatedById,
    String? updatedByName,
  }) async {
    BusinessValidators.validateIdExists(itemId, 'Stock item');

    await tenant.db.runTransaction((transaction) async {
      final docRef = tenant.stockItems().doc(itemId);
      final doc = await transaction.get(docRef);

      if (!doc.exists) throw NotFoundException('Stock item not found');

      final currentQuantity = parseFirestoreDouble(doc.data()?['quantity']);
      final newQuantity = currentQuantity + adjustment;

      if (newQuantity < 0) {
        throw InvalidAmountException(
          'Cannot reduce stock below zero. Current: ${currentQuantity.toStringAsFixed(1)}, Adjustment: ${adjustment.toStringAsFixed(1)}',
        );
      }

      transaction.update(docRef, {
        'quantity': newQuantity,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedById': ?updatedById,
        'updatedByName': ?updatedByName,
      });

      if (adjustment.abs() > 0) {
        final historyRef = docRef.collection('history').doc();
        transaction.set(historyRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'previousQuantity': currentQuantity,
          'newQuantity': newQuantity,
          'adjustment': adjustment,
          'reason':
              reason ?? (adjustment > 0 ? 'Stock added' : 'Stock deducted'),
          'updatedById': ?updatedById,
          'updatedByName': ?updatedByName,
        });
      }
    });
    await _refreshPublicMenuMirror(tenant, itemId);
  }

  static Future<void> setQuantity({
    required TenantRef tenant,
    required String itemId,
    required double quantity,
    String? reason,
    String? updatedById,
    String? updatedByName,
  }) async {
    BusinessValidators.validateIdExists(itemId, 'Stock item');
    if (quantity < 0) {
      throw InvalidAmountException('Stock quantity cannot be negative');
    }

    await tenant.db.runTransaction((transaction) async {
      final docRef = tenant.stockItems().doc(itemId);
      final doc = await transaction.get(docRef);

      if (!doc.exists) throw NotFoundException('Stock item not found');

      final currentQuantity = parseFirestoreDouble(doc.data()?['quantity']);

      transaction.update(docRef, {
        'quantity': quantity,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedById': ?updatedById,
        'updatedByName': ?updatedByName,
      });

      final historyRef = docRef.collection('history').doc();
      transaction.set(historyRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'previousQuantity': currentQuantity,
        'newQuantity': quantity,
        'adjustment': quantity - currentQuantity,
        'reason': reason ?? 'Stock count adjusted',
        'updatedById': ?updatedById,
        'updatedByName': ?updatedByName,
      });
    });
    await _refreshPublicMenuMirror(tenant, itemId);
  }

  static void batchDeduct({
    required TenantRef tenant,
    required WriteBatch batch,
    required List<StockDeduction> deductions,
  }) {
    for (final deduction in deductions) {
      if (deduction.itemId.isEmpty) continue;
      final stockRef = tenant.stockItems().doc(deduction.itemId);
      batch.update(stockRef, {
        'quantity': FieldValue.increment(-deduction.quantity),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  static void batchRestore({
    required TenantRef tenant,
    required WriteBatch batch,
    required List<StockDeduction> restorations,
  }) {
    for (final restoration in restorations) {
      if (restoration.itemId.isEmpty) continue;
      final stockRef = tenant.stockItems().doc(restoration.itemId);
      batch.update(stockRef, {
        'quantity': FieldValue.increment(restoration.quantity),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> upsert(TenantRef tenant, StockItem item) async {
    await tenant
        .stockItems()
        .doc(item.id)
        .set(item.toFirestore(), SetOptions(merge: true));
    await PublicVenueSyncService.syncPublicMenuFromStockItem(tenant, item);
  }

  static Future<void> delete(TenantRef tenant, String itemId) async {
    BusinessValidators.validateIdExists(itemId, 'Stock item');

    final cafeOrders = await tenant
        .cafeOrders()
        .where('items', arrayContains: {'itemId': itemId})
        .limit(1)
        .get();
    if (cafeOrders.docs.isNotEmpty) {
      throw InvalidStateException(
        'Cannot delete item that has been used in orders',
      );
    }

    await tenant.stockItems().doc(itemId).delete();
    await PublicVenueSyncService.removePublicMenuMirrorForStockId(
      tenant,
      itemId,
    );
  }

  static Future<void> updateLowStockThreshold({
    required TenantRef tenant,
    required String itemId,
    required double threshold,
  }) async {
    BusinessValidators.validateIdExists(itemId, 'Stock item');
    if (threshold < 0) {
      throw InvalidAmountException('Threshold cannot be negative');
    }

    await tenant.stockItems().doc(itemId).update({
      'lowStockThreshold': threshold,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}

class StockDeduction {
  final String itemId;
  final int quantity;

  const StockDeduction({required this.itemId, required this.quantity});
}
