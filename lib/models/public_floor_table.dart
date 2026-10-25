import 'package:cloud_firestore/cloud_firestore.dart';

import 'table.dart';

/// Public mirror of table state (no rates or session ids).
class PublicFloorTable {
  final String id;
  final String name;
  final TablePurpose tablePurpose;
  final TableStatus status;
  final int capacity;
  final DateTime? updatedAt;

  const PublicFloorTable({
    required this.id,
    required this.name,
    required this.tablePurpose,
    required this.status,
    this.capacity = 2,
    this.updatedAt,
  });

  factory PublicFloorTable.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PublicFloorTable(
      id: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : doc.id,
      tablePurpose: parseTablePurpose(data['tablePurpose']),
      status: _parseStatus(data['status']),
      capacity: (data['capacity'] is int)
          ? data['capacity'] as int
          : int.tryParse('${data['capacity']}') ?? 2,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

TableStatus _parseStatus(Object? raw) {
  if (raw == null) return TableStatus.available;
  final s = raw.toString().toLowerCase();
  final short = s.contains('.') ? s.split('.').last : s;
  return TableStatus.values.firstWhere(
    (e) => e.name == short,
    orElse: () => TableStatus.maintenance,
  );
}
