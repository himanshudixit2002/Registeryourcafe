import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/membership_type_definition.dart';
import '../models/venue_kind.dart';

class MembershipTypeService {
  final TenantRef _tenant;

  MembershipTypeService(this._tenant);

  CollectionReference<Map<String, dynamic>> get _col =>
      _tenant.membershipTypeDefinitions();

  Future<void> ensureDefaultSeedIfEmpty({required VenueKind venueKind}) async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _tenant.db.batch();
    for (final def
        in MembershipTypeDefinition.defaultSeedForVenueKind(venueKind)) {
      batch.set(_col.doc(def.id), def.toFirestoreForCreate());
    }
    await batch.commit();
  }

  Future<void> createWithId(String id, MembershipTypeDefinition def) async {
    await _col.doc(id).set(def.copyWith(id: id).toFirestoreForCreate());
  }

  Future<void> update(MembershipTypeDefinition def) async {
    await _col.doc(def.id).set(def.toFirestore(), SetOptions(merge: true));
  }

  Future<void> setArchived(String id, bool archived) async {
    await _col.doc(id).update({
      'isArchived': archived,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
