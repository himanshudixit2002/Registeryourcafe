import 'package:cloud_firestore/cloud_firestore.dart';

class GuestBookingRecord {
  final String id;
  final String companyId;
  final String venueName;
  final String guestUid;
  final String guestName;
  final String guestPhone;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int partySize;
  final String? occasion;
  final String? preferences;
  final String status;
  final bool isRecurring;
  final String? recurringDay;
  final DateTime createdAt;

  const GuestBookingRecord({
    required this.id,
    required this.companyId,
    required this.venueName,
    required this.guestUid,
    required this.guestName,
    required this.guestPhone,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.partySize = 2,
    this.occasion,
    this.preferences,
    this.status = 'pending',
    this.isRecurring = false,
    this.recurringDay,
    required this.createdAt,
  });

  factory GuestBookingRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GuestBookingRecord(
      id: doc.id,
      companyId: d['companyId'] as String? ?? '',
      venueName: d['venueName'] as String? ?? '',
      guestUid: d['guestUid'] as String? ?? '',
      guestName: d['guestName'] as String? ?? '',
      guestPhone: d['guestPhone'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: d['startTime'] as String? ?? '',
      endTime: d['endTime'] as String? ?? '',
      partySize: (d['partySize'] as num?)?.toInt() ?? 2,
      occasion: d['occasion'] as String?,
      preferences: d['preferences'] as String?,
      status: d['status'] as String? ?? 'pending',
      isRecurring: d['isRecurring'] as bool? ?? false,
      recurringDay: d['recurringDay'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'companyId': companyId,
    'venueName': venueName,
    'guestUid': guestUid,
    'guestName': guestName,
    'guestPhone': guestPhone,
    'date': Timestamp.fromDate(date),
    'startTime': startTime,
    'endTime': endTime,
    'partySize': partySize,
    if (occasion != null) 'occasion': occasion,
    if (preferences != null) 'preferences': preferences,
    'status': status,
    'isRecurring': isRecurring,
    if (recurringDay != null) 'recurringDay': recurringDay,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
