import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../utils/business_validators.dart';
import '../utils/firestore_utils.dart';

/// Append-only audit log under [stock_items]/{id}/[subcollection].
class StockCostService {
  StockCostService._();

  static const String subcollection = 'cost_history';

  static const String sourceVendorReceipt = 'vendor_receipt';
  static const String sourceManualEdit = 'manual_edit';

  static bool _sameCost(double? a, double? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a - b).abs() < 1e-9;
  }

  /// Log within an existing [Transaction] (e.g. vendor receipt).
  static void logCostChangeInTransaction(
    Transaction transaction, {
    required DocumentReference<Map<String, dynamic>> stockRef,
    required double? previousUnitCost,
    required double? newUnitCost,
    required String source,
    String? receiptId,
    String? vendorId,
    String? invoiceNumber,
    double? quantityReceived,
    String? note,
    String? updatedById,
    String? updatedByName,
    String? itemNameSnapshot,
  }) {
    final entryRef = stockRef.collection(subcollection).doc();
    transaction.set(entryRef, {
      'timestamp': FieldValue.serverTimestamp(),
      'previousUnitCost': previousUnitCost,
      'newUnitCost': newUnitCost,
      'source': source,
      'receiptId': ?receiptId,
      'vendorId': ?vendorId,
      if (invoiceNumber != null && invoiceNumber.isNotEmpty)
        'invoiceNumber': invoiceNumber,
      'quantityReceived': ?quantityReceived,
      if (note != null && note.isNotEmpty) 'note': note,
      'updatedById': ?updatedById,
      'updatedByName': ?updatedByName,
      if (itemNameSnapshot != null && itemNameSnapshot.isNotEmpty)
        'itemNameSnapshot': itemNameSnapshot,
    });
  }

  /// Sync [lastUnitCost] from staff input; writes [cost_history] only when value changes.
  static Future<void> syncManualUnitCost({
    required TenantRef tenant,
    required String itemId,
    required double? desiredUnitCost,
    String? note,
    String? updatedById,
    String? updatedByName,
  }) async {
    BusinessValidators.validateIdExists(itemId, 'Stock item');

    await tenant.db.runTransaction((transaction) async {
      final ref = tenant.stockItems().doc(itemId);
      final snap = await transaction.get(ref);
      if (!snap.exists) {
        throw NotFoundException('Stock item not found');
      }

      final data = snap.data()!;
      final current = parseFirestoreDoubleOrNull(data['lastUnitCost']);
      if (_sameCost(current, desiredUnitCost)) {
        return;
      }

      final name = data['name'] as String? ?? '';

      final update = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedById': ?updatedById,
        'updatedByName': ?updatedByName,
      };

      if (desiredUnitCost == null) {
        update['lastUnitCost'] = FieldValue.delete();
      } else {
        update['lastUnitCost'] = desiredUnitCost;
      }

      transaction.update(ref, update);

      logCostChangeInTransaction(
        transaction,
        stockRef: ref,
        previousUnitCost: current,
        newUnitCost: desiredUnitCost,
        source: sourceManualEdit,
        note: note,
        updatedById: updatedById,
        updatedByName: updatedByName,
        itemNameSnapshot: name,
      );
    });
  }
}
