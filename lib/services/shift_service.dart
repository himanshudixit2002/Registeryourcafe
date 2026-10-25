import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/shift.dart';

class ShiftService {
  final TenantRef _tenant;

  ShiftService(this._tenant);

  CollectionReference<Map<String, dynamic>> _col() =>
      _tenant.companyDoc().collection('shifts');

  Stream<List<Shift>> watchShifts({DateTime? fromDate}) {
    Query<Map<String, dynamic>> q = _col().orderBy('date', descending: false);
    if (fromDate != null) {
      q = q.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
    }
    return q.limit(200).snapshots().map(
          (snap) => snap.docs.map(Shift.fromFirestore).toList(),
        );
  }

  Future<void> createShift(Shift shift) async {
    await _col().add(shift.toFirestore());
  }

  Future<void> clockIn(String shiftId) async {
    await _col().doc(shiftId).update({
      'status': ShiftStatus.clockedIn.name,
      'actualStart': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> clockOut(String shiftId) async {
    await _col().doc(shiftId).update({
      'status': ShiftStatus.clockedOut.name,
      'actualEnd': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> markAbsent(String shiftId) async {
    await _col().doc(shiftId).update({
      'status': ShiftStatus.absent.name,
    });
  }

  Future<void> deleteShift(String shiftId) async {
    await _col().doc(shiftId).delete();
  }
}
