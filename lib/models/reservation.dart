import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

enum ReservationStatus {
  pending,
  confirmed,
  cancelled,
  completed;

  static ReservationStatus parse(String? value) {
    if (value == null) return ReservationStatus.pending;
    for (final s in ReservationStatus.values) {
      if (s.name == value) return s;
    }
    return ReservationStatus.pending;
  }
}

class Reservation {
  final String id;
  final String? tableId;
  final String? tableName;
  final String? customerId;
  final String guestName;
  final String guestPhone;
  final DateTime date;
  final String startTime;
  final String endTime;
  final ReservationStatus status;
  final String? notes;
  final int partySize;
  final DateTime createdAt;

  const Reservation({
    required this.id,
    this.tableId,
    this.tableName,
    this.customerId,
    required this.guestName,
    required this.guestPhone,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.status = ReservationStatus.pending,
    this.notes,
    this.partySize = 1,
    required this.createdAt,
  });

  factory Reservation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Reservation(
      id: doc.id,
      tableId: data['tableId'] as String?,
      tableName: data['tableName'] as String?,
      customerId: data['customerId'] as String?,
      guestName: data['guestName'] as String? ?? '',
      guestPhone: data['guestPhone'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      status: ReservationStatus.parse(data['status'] as String?),
      notes: data['notes'] as String?,
      partySize: parseFirestoreInt(data['partySize'], fallback: 1),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (tableId != null) 'tableId': tableId,
      if (tableName != null) 'tableName': tableName,
      if (customerId != null) 'customerId': customerId,
      'guestName': guestName,
      'guestPhone': guestPhone,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'status': status.name,
      if (notes != null) 'notes': notes,
      'partySize': partySize,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
