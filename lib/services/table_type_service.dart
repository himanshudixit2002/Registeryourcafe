import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/table.dart' show parseTableTypeId;
import '../models/table_type_definition.dart';
import '../models/venue_kind.dart';
import '../utils/app_logger.dart';

class TableTypeService {
  final TenantRef _tenant;

  TableTypeService(this._tenant);

  CollectionReference<Map<String, dynamic>> get _col =>
      _tenant.tableTypeDefinitions();

  /// Seeds default table labels when the collection has no documents.
  Future<void> ensureDefaultSeedIfEmpty({required VenueKind venueKind}) async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _tenant.db.batch();
    for (final def in TableTypeDefinition.defaultSeedForVenueKind(venueKind)) {
      batch.set(_col.doc(def.id), def.toFirestoreForCreate());
    }
    await batch.commit();
  }

  /// One-time migration when [VenueKind] is dining/restaurant but definitions
  /// still look gaming-first.
  ///
  /// - **Pure gaming seed:** archives all current rows, writes target seeds,
  ///   remaps `tables.type` from gaming ids to the first target id.
  /// - **Mixed (gaming seeds + custom ids):** writes any missing target seed
  ///   docs, archives only rows whose id is in the gaming seed set, remaps
  ///   tables that still use gaming ids. Custom type definitions are kept.
  ///
  /// Idempotent: skips once at least one target-venue seed id exists in the
  /// collection.
  Future<void> migrateGamingSeedTableTypesIfNeeded({
    required VenueKind venueKind,
  }) async {
    if (venueKind == VenueKind.gamingCafe) return;

    final gamingIds = TableTypeDefinition.gamingTableTypeSeedIdSet;
    final snapshot = await _col.get();
    if (snapshot.docs.isEmpty) {
      await ensureDefaultSeedIfEmpty(venueKind: venueKind);
      return;
    }

    final docIds = snapshot.docs.map((d) => d.id).toSet();
    final targetDefs = TableTypeDefinition.defaultSeedForVenueKind(venueKind);
    final targetIds = targetDefs.map((d) => d.id).toSet();
    if (docIds.intersection(targetIds).isNotEmpty) return;

    final replacementId = targetDefs.first.id;
    final allGamingSeedsOnly =
        docIds.isNotEmpty && docIds.every(gamingIds.contains);

    AppLogger.info(
      'Migrating table types toward ${venueKind.name} '
      '(mode: ${allGamingSeedsOnly ? 'pure_gaming_seed' : 'mixed'}; '
      'replacement table type: $replacementId)',
      tag: 'TableTypeMigration',
    );

    var batch = _tenant.db.batch();
    var opCount = 0;

    Future<void> commitIfFull() async {
      if (opCount >= 400) {
        await batch.commit();
        batch = _tenant.db.batch();
        opCount = 0;
      }
    }

    if (allGamingSeedsOnly) {
      for (final id in docIds) {
        batch.update(_col.doc(id), {
          'isArchived': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        opCount++;
        await commitIfFull();
      }
    } else {
      for (final id in docIds) {
        if (!gamingIds.contains(id)) continue;
        batch.update(_col.doc(id), {
          'isArchived': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        opCount++;
        await commitIfFull();
      }
    }

    for (final def in targetDefs) {
      batch.set(_col.doc(def.id), def.toFirestoreForCreate());
      opCount++;
      await commitIfFull();
    }

    if (opCount > 0) {
      await batch.commit();
      batch = _tenant.db.batch();
      opCount = 0;
    }

    final tablesSnap = await _tenant.tables().get();
    for (final doc in tablesSnap.docs) {
      final data = doc.data();
      final tid = parseTableTypeId(data);
      if (!gamingIds.contains(tid)) continue;
      batch.update(doc.reference, {
        'type': replacementId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _tenant.db.batch();
        opCount = 0;
      }
    }
    if (opCount > 0) {
      await batch.commit();
    }

    await _tenant.companyDoc().set(
      {
        'tableTypesVenueMigrationAt': FieldValue.serverTimestamp(),
        'tableTypesVenueMigrationKind': venueKind.name,
        'tableTypesMixedMigration': !allGamingSeedsOnly,
      },
      SetOptions(merge: true),
    );

    AppLogger.info('Table type migration finished.', tag: 'TableTypeMigration');
  }

  Future<void> createWithId(String id, TableTypeDefinition def) async {
    await _col.doc(id).set(def.copyWith(id: id).toFirestoreForCreate());
  }

  Future<void> update(TableTypeDefinition def) async {
    await _col.doc(def.id).set(def.toFirestore(), SetOptions(merge: true));
  }

  Future<void> setArchived(String id, bool archived) async {
    await _col.doc(id).update({
      'isArchived': archived,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
