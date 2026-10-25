import 'package:cloud_firestore/cloud_firestore.dart';

/// Public-safe approved hold for live floor (no guest PII).
///
/// `companies/{companyId}/public_booking_slots/{id}`.
class PublicBookingSlot {
  final String id;
  final String tableId;
  final DateTime startAt;
  final DateTime endAt;
  final String requestId;
  final DateTime? updatedAt;

  const PublicBookingSlot({
    required this.id,
    required this.tableId,
    required this.startAt,
    required this.endAt,
    required this.requestId,
    this.updatedAt,
  });

  factory PublicBookingSlot.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PublicBookingSlot(
      id: doc.id,
      tableId: data['tableId'] as String? ?? '',
      startAt: (data['startAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endAt: (data['endAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      requestId: data['requestId'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tableId': tableId,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'requestId': requestId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Inclusive-exclusive window [startAt, endAt) style overlap check.
  bool containsInstant(DateTime t) =>
      !t.isBefore(startAt) && t.isBefore(endAt);
}

/// True iff [aStart,aEnd) overlaps [bStart,bEnd) (standard interval overlap).
bool bookingIntervalsOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) {
  if (!aEnd.isAfter(aStart) || !bEnd.isAfter(bStart)) return false;
  return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}
