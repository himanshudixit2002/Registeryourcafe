import 'package:cloud_firestore/cloud_firestore.dart';

enum TableCleaningStatus {
  clean,
  dirty,
  inProgress;

  static TableCleaningStatus parse(String? v) {
    if (v == 'dirty') return dirty;
    if (v == 'inProgress') return inProgress;
    return clean;
  }
}

class TableMaintenanceLog {
  final String id;
  final String tableId;
  final String tableName;
  final String issue;
  final String status;
  final String? resolvedBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const TableMaintenanceLog({
    required this.id,
    required this.tableId,
    required this.tableName,
    required this.issue,
    this.status = 'open',
    this.resolvedBy,
    required this.createdAt,
    this.resolvedAt,
  });

  factory TableMaintenanceLog.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return TableMaintenanceLog(
      id: doc.id,
      tableId: d['tableId'] as String? ?? '',
      tableName: d['tableName'] as String? ?? '',
      issue: d['issue'] as String? ?? '',
      status: d['status'] as String? ?? 'open',
      resolvedBy: d['resolvedBy'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'tableId': tableId,
    'tableName': tableName,
    'issue': issue,
    'status': status,
    if (resolvedBy != null) 'resolvedBy': resolvedBy,
    'createdAt': Timestamp.fromDate(createdAt),
    if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
  };
}

class WalkInQueueEntry {
  final String id;
  final String name;
  final int partySize;
  final int estimatedMinutes;
  final String status;
  final DateTime createdAt;

  const WalkInQueueEntry({
    required this.id,
    required this.name,
    required this.partySize,
    this.estimatedMinutes = 10,
    this.status = 'waiting',
    required this.createdAt,
  });

  factory WalkInQueueEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return WalkInQueueEntry(
      id: doc.id,
      name: d['name'] as String? ?? '',
      partySize: (d['partySize'] as num?)?.toInt() ?? 1,
      estimatedMinutes: (d['estimatedMinutes'] as num?)?.toInt() ?? 10,
      status: d['status'] as String? ?? 'waiting',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'partySize': partySize,
    'estimatedMinutes': estimatedMinutes,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
