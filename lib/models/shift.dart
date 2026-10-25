import 'package:cloud_firestore/cloud_firestore.dart';

enum ShiftStatus {
  scheduled,
  clockedIn,
  clockedOut,
  absent;

  static ShiftStatus parse(String? value) {
    if (value == null) return ShiftStatus.scheduled;
    for (final s in ShiftStatus.values) {
      if (s.name == value) return s;
    }
    return ShiftStatus.scheduled;
  }
}

class Shift {
  final String id;
  final String staffUid;
  final String staffName;
  final DateTime date;
  final String scheduledStart;
  final String scheduledEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final ShiftStatus status;

  const Shift({
    required this.id,
    required this.staffUid,
    required this.staffName,
    required this.date,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    this.status = ShiftStatus.scheduled,
  });

  double get hoursWorked {
    if (actualStart == null || actualEnd == null) return 0;
    return actualEnd!.difference(actualStart!).inMinutes / 60;
  }

  factory Shift.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Shift(
      id: doc.id,
      staffUid: data['staffUid'] as String? ?? '',
      staffName: data['staffName'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledStart: data['scheduledStart'] as String? ?? '',
      scheduledEnd: data['scheduledEnd'] as String? ?? '',
      actualStart: (data['actualStart'] as Timestamp?)?.toDate(),
      actualEnd: (data['actualEnd'] as Timestamp?)?.toDate(),
      status: ShiftStatus.parse(data['status'] as String?),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffUid': staffUid,
      'staffName': staffName,
      'date': Timestamp.fromDate(date),
      'scheduledStart': scheduledStart,
      'scheduledEnd': scheduledEnd,
      if (actualStart != null) 'actualStart': Timestamp.fromDate(actualStart!),
      if (actualEnd != null) 'actualEnd': Timestamp.fromDate(actualEnd!),
      'status': status.name,
    };
  }
}
