import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/audit_entry.dart';

class AuditService {
  final TenantRef _tenant;

  AuditService(this._tenant);

  CollectionReference<Map<String, dynamic>> _col() =>
      _tenant.companyDoc().collection('auditLog');

  Future<void> log({
    required String action,
    required String actorUid,
    required String actorName,
    String? details,
    String? entityType,
    String? entityId,
  }) async {
    final entry = AuditEntry(
      id: '',
      action: action,
      actorUid: actorUid,
      actorName: actorName,
      timestamp: DateTime.now(),
      details: details,
      entityType: entityType,
      entityId: entityId,
    );
    await _col().add(entry.toFirestore());
  }

  Stream<List<AuditEntry>> watchRecent({int limit = 200}) {
    return _col()
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AuditEntry.fromFirestore).toList());
  }

  Future<List<AuditEntry>> queryByEntity(
    String entityType,
    String entityId,
  ) async {
    final snap = await _col()
        .where('entityType', isEqualTo: entityType)
        .where('entityId', isEqualTo: entityId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();
    return snap.docs.map(AuditEntry.fromFirestore).toList();
  }
}
