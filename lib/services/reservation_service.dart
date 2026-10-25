import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/reservation.dart';

class ReservationService {
  final TenantRef _tenant;

  ReservationService(this._tenant);

  CollectionReference<Map<String, dynamic>> _col() =>
      _tenant.companyDoc().collection('reservations');

  Stream<List<Reservation>> watchReservations({DateTime? fromDate}) {
    Query<Map<String, dynamic>> q = _col().orderBy('date', descending: false);
    if (fromDate != null) {
      q = q.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
    }
    return q.limit(200).snapshots().map(
          (snap) => snap.docs.map(Reservation.fromFirestore).toList(),
        );
  }

  Future<void> createReservation(Reservation reservation) async {
    await _col().add(reservation.toFirestore());
  }

  Future<void> updateStatus(String id, ReservationStatus status) async {
    await _col().doc(id).update({'status': status.name});
  }

  Future<void> deleteReservation(String id) async {
    await _col().doc(id).delete();
  }
}
