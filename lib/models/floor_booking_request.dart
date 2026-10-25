import 'package:cloud_firestore/cloud_firestore.dart';

/// Guest-initiated live-floor booking; staff approve into [PublicBookingSlot].
///
/// Stored at `companies/{companyId}/floor_booking_requests/{id}`.
class FloorBookingRequest {
  final String id;
  final String tableId;
  final String tableName;
  final DateTime startAt;
  final DateTime endAt;
  final String guestName;
  final String guestPhone;
  final String? guestEmail;
  final String? note;
  final FloorBookingRequestStatus status;
  final String requesterUid;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? decidedByUid;
  final String? decisionNote;
  final String? publicSlotId;

  const FloorBookingRequest({
    required this.id,
    required this.tableId,
    required this.tableName,
    required this.startAt,
    required this.endAt,
    required this.guestName,
    required this.guestPhone,
    this.guestEmail,
    this.note,
    required this.status,
    required this.requesterUid,
    required this.createdAt,
    this.updatedAt,
    this.decidedByUid,
    this.decisionNote,
    this.publicSlotId,
  });

  factory FloorBookingRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return FloorBookingRequest(
      id: doc.id,
      tableId: data['tableId'] as String? ?? '',
      tableName: data['tableName'] as String? ?? '',
      startAt: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      endAt: (data['endAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      guestName: data['guestName'] as String? ?? '',
      guestPhone: data['guestPhone'] as String? ?? '',
      guestEmail: data['guestEmail'] as String?,
      note: data['note'] as String?,
      status: FloorBookingRequestStatus.parse(data['status']),
      requesterUid: data['requesterUid'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      decidedByUid: data['decidedByUid'] as String?,
      decisionNote: data['decisionNote'] as String?,
      publicSlotId: data['publicSlotId'] as String?,
    );
  }

  Map<String, dynamic> toFirestoreForCreate() {
    return {
      'tableId': tableId,
      'tableName': tableName,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'guestName': guestName.trim(),
      'guestPhone': guestPhone.trim(),
      'guestEmail': guestEmail?.trim() ?? '',
      'note': note?.trim() ?? '',
      'status': status.storageName,
      'requesterUid': requesterUid,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreStaffDecision({
    required FloorBookingRequestStatus newStatus,
    required String decidedByUid,
    String? decisionNote,
    String? publicSlotId,
  }) {
    return {
      'status': newStatus.storageName,
      'decidedByUid': decidedByUid,
      if (decisionNote != null && decisionNote.trim().isNotEmpty)
        'decisionNote': decisionNote.trim(),
      'publicSlotId': ?publicSlotId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

enum FloorBookingRequestStatus {
  pending,
  approved,
  declined,
  cancelled;

  String get storageName => name;

  static FloorBookingRequestStatus parse(Object? raw) {
    if (raw == null) return FloorBookingRequestStatus.pending;
    final s = raw.toString();
    final short = s.contains('.') ? s.split('.').last : s;
    return FloorBookingRequestStatus.values.firstWhere(
      (e) => e.name == short,
      orElse: () => FloorBookingRequestStatus.pending,
    );
  }
}
