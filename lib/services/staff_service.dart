import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_collections.dart';
import '../models/staff_member.dart';

class StaffService {
  final FirebaseFirestore _db;
  final String _companyId;

  StaffService(this._db, this._companyId);

  Stream<List<StaffMember>> watchStaff() {
    return _db
        .collection(FirestoreCollections.users)
        .where('companyId', isEqualTo: _companyId)
        .snapshots()
        .map((snap) => snap.docs.map(StaffMember.fromFirestore).toList());
  }

  Future<void> updateStaffRole(String uid, String roleId) async {
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'roleId': roleId,
    });
  }

  Future<void> toggleStaffActive(String uid, bool active) async {
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'isActive': active,
    });
  }
}
