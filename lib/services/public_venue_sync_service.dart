import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_collections.dart';
import '../firestore/tenant_firestore.dart';
import '../models/public_menu_item.dart';
import '../models/stock_item.dart';
import '../models/table.dart';
import '../utils/app_logger.dart';

/// Keeps [TenantRef.publicFloor] in sync with private tables when discovery is on.
class PublicVenueSyncService {
  PublicVenueSyncService._();

  static Future<bool> isDiscoveryEnabled(
    FirebaseFirestore db,
    String companyId,
  ) async {
    final doc = await db
        .collection(FirestoreCollections.publicVenues)
        .doc(companyId)
        .get();
    return doc.data()?['showOnDiscovery'] == true;
  }

  static Map<String, dynamic> _publicPayload(SnookerTable table) {
    return {
      'name': table.name,
      'tablePurpose': table.tablePurpose.name,
      'status': table.status.name,
      'capacity': table.capacity,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Writes or updates the public mirror for [table] when discovery is enabled.
  static Future<void> syncTable(TenantRef tenant, SnookerTable table) async {
    if (!await isDiscoveryEnabled(tenant.db, tenant.companyId)) return;
    await tenant.publicFloor().doc(table.id).set(_publicPayload(table));
  }

  /// Re-reads [tableId] from private tables and syncs (after partial updates).
  static Future<void> syncTableById(TenantRef tenant, String tableId) async {
    if (!await isDiscoveryEnabled(tenant.db, tenant.companyId)) return;
    final doc = await tenant.tables().doc(tableId).get();
    if (!doc.exists || doc.data() == null) {
      await tenant.publicFloor().doc(tableId).delete();
      return;
    }
    final table = SnookerTable.fromJson({...doc.data()!, 'id': doc.id});
    await tenant.publicFloor().doc(tableId).set(_publicPayload(table));
  }

  /// Removes mirror row (call when table deleted, regardless of discovery).
  static Future<void> deletePublicFloorTable(
    TenantRef tenant,
    String tableId,
  ) async {
    try {
      await tenant.publicFloor().doc(tableId).delete();
    } catch (e, st) {
      AppLogger.debug(
        'deletePublicFloorTable($tableId): $e\n$st',
        tag: 'PublicVenueSync',
      );
    }
  }

  /// Deletes all public_floor docs for tenant (e.g. discovery turned off).
  static Future<void> clearPublicFloor(TenantRef tenant) async {
    final snap = await tenant.publicFloor().get();
    if (snap.docs.isEmpty) return;
    WriteBatch batch = tenant.db.batch();
    var count = 0;
    for (final d in snap.docs) {
      batch.delete(d.reference);
      count++;
      if (count >= 450) {
        await batch.commit();
        batch = tenant.db.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
    }
  }

  /// Upserts mirrors for every private table (when enabling discovery).
  static Future<void> backfillAllTables(TenantRef tenant) async {
    if (!await isDiscoveryEnabled(tenant.db, tenant.companyId)) return;
    final snap = await tenant.tables().get();
    WriteBatch batch = tenant.db.batch();
    var count = 0;
    for (final doc in snap.docs) {
      final table = SnookerTable.fromJson({...doc.data(), 'id': doc.id});
      batch.set(tenant.publicFloor().doc(doc.id), _publicPayload(table));
      count++;
      if (count >= 450) {
        await batch.commit();
        batch = tenant.db.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
    }
  }

  // --- Public menu mirrors (café stock_items → public_menu_items) ---

  static bool stockItemEligibleForPublicMenu(StockItem item) {
    return item.isSellable &&
        !item.isMerchandise &&
        item.price != null &&
        item.price! > 0;
  }

  /// Upserts or deletes `public_menu_items/{stockItem.id}` from sellable café stock.
  static Future<void> syncPublicMenuFromStockItem(
    TenantRef tenant,
    StockItem item,
  ) async {
    try {
      if (!stockItemEligibleForPublicMenu(item)) {
        await removePublicMenuMirrorForStockId(tenant, item.id);
        return;
      }
      final name = item.name.trim();
      final pub = PublicMenuItem(
        id: item.id,
        name: name.isEmpty ? 'Item' : name,
        description: item.description,
        price: item.price!,
        categoryLabel: item.category?.trim().isEmpty == true
            ? null
            : item.category?.trim(),
        sortOrder: 0,
        // Public menu is a price list for guests — never mirror stock quantity.
        isAvailable: true,
        imageUrl: item.imageUrl?.trim().isEmpty == true
            ? null
            : item.imageUrl?.trim(),
        syncedFromStock: true,
      );
      await tenant
          .publicMenuItems()
          .doc(item.id)
          .set(pub.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      // Do not fail inventory UX if public mirror fails.
      AppLogger.warning(
        'syncPublicMenuFromStockItem failed for ${item.id}: $e\n$st',
        tag: 'PublicVenueSync',
      );
    }
  }

  static Future<void> removePublicMenuMirrorForStockId(
    TenantRef tenant,
    String stockItemId,
  ) async {
    if (stockItemId.isEmpty) return;
    try {
      await tenant.publicMenuItems().doc(stockItemId).delete();
    } catch (e, st) {
      AppLogger.debug(
        'removePublicMenuMirrorForStockId($stockItemId): $e\n$st',
        tag: 'PublicVenueSync',
      );
    }
  }

  /// When enabling discovery: mirror all eligible stock rows to the public menu.
  static Future<void> backfillPublicMenuFromStock(TenantRef tenant) async {
    try {
      final snap = await tenant.stockItems().get();
      for (final doc in snap.docs) {
        final item = StockItem.fromFirestore(doc);
        await syncPublicMenuFromStockItem(tenant, item);
      }
    } catch (e, st) {
      AppLogger.error(
        'backfillPublicMenuFromStock failed',
        tag: 'PublicVenueSync',
        error: e,
        stackTrace: st,
      );
    }
  }
}
