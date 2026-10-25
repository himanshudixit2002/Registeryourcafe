import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/table_advanced.dart';

class TableAdvancedService {
  final TenantRef _tenant;

  TableAdvancedService(this._tenant);

  CollectionReference<Map<String, dynamic>> _maintenance() =>
      _tenant.companyDoc().collection('tableMaintenance');

  CollectionReference<Map<String, dynamic>> _walkInQueue() =>
      _tenant.companyDoc().collection('walkInQueue');

  Future<void> updateCleaningStatus(String tableId, String status) async =>
      await _tenant.tables().doc(tableId).update({'cleaningStatus': status});

  Future<void> setVipTable(String tableId, bool isVip) async =>
      await _tenant.tables().doc(tableId).update({'isVip': isVip});

  Future<void> logMaintenance(TableMaintenanceLog log) async =>
      await _maintenance().add(log.toFirestore());

  Stream<List<TableMaintenanceLog>> watchMaintenance() => _maintenance()
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(TableMaintenanceLog.fromFirestore).toList());

  Future<void> resolveMaintenance(String id, String resolvedBy) async =>
      await _maintenance().doc(id).update({
        'status': 'resolved',
        'resolvedBy': resolvedBy,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

  Future<void> addToWalkInQueue(WalkInQueueEntry entry) async =>
      await _walkInQueue().add(entry.toFirestore());

  Stream<List<WalkInQueueEntry>> watchWalkInQueue() => _walkInQueue()
      .where('status', isEqualTo: 'waiting')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(WalkInQueueEntry.fromFirestore).toList());

  Future<void> updateWalkInStatus(String id, String status) async =>
      await _walkInQueue().doc(id).update({'status': status});

  Future<void> mergeTableSessions(
    String fromTableId,
    String toTableId,
  ) async {
    await _tenant.companyDoc().collection('tableMerges').add({
      'fromTableId': fromTableId,
      'toTableId': toTableId,
      'mergedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> transferTable(String tableId, String newSection) async {
    await _tenant.tables().doc(tableId).update({'section': newSection});
  }
}
