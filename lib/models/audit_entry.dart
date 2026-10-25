import 'package:cloud_firestore/cloud_firestore.dart';

class AuditEntry {
  final String id;
  final String action;
  final String actorUid;
  final String actorName;
  final DateTime timestamp;
  final String? details;
  final String? entityType;
  final String? entityId;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.actorUid,
    required this.actorName,
    required this.timestamp,
    this.details,
    this.entityType,
    this.entityId,
  });

  factory AuditEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AuditEntry(
      id: doc.id,
      action: data['action'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'Unknown',
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      details: data['details'] as String?,
      entityType: data['entityType'] as String?,
      entityId: data['entityId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'action': action,
      'actorUid': actorUid,
      'actorName': actorName,
      'timestamp': Timestamp.fromDate(timestamp),
      if (details != null) 'details': details,
      if (entityType != null) 'entityType': entityType,
      if (entityId != null) 'entityId': entityId,
    };
  }
}
