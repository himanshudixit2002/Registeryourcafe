import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/staff_advanced.dart';

class StaffAdvancedService {
  final TenantRef _tenant;
  StaffAdvancedService(this._tenant);

  CollectionReference<Map<String, dynamic>> _commissions() =>
      _tenant.companyDoc().collection('commissions');
  CollectionReference<Map<String, dynamic>> _training() =>
      _tenant.companyDoc().collection('trainingModules');
  CollectionReference<Map<String, dynamic>> _leaves() =>
      _tenant.companyDoc().collection('leaveRequests');
  CollectionReference<Map<String, dynamic>> _goals() =>
      _tenant.companyDoc().collection('staffGoals');
  CollectionReference<Map<String, dynamic>> _documents() =>
      _tenant.companyDoc().collection('staffDocuments');

  Future<void> addCommission(CommissionRecord rec) async =>
      await _commissions().add(rec.toFirestore());

  Stream<List<CommissionRecord>> watchCommissions({int limit = 100}) =>
      _commissions()
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(CommissionRecord.fromFirestore).toList());

  Future<void> createTrainingModule(TrainingModule mod) async =>
      await _training().add(mod.toFirestore());

  Stream<List<TrainingModule>> watchTraining() => _training()
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(TrainingModule.fromFirestore).toList());

  Future<void> submitLeaveRequest(LeaveRequest req) async =>
      await _leaves().add(req.toFirestore());

  Stream<List<LeaveRequest>> watchLeaveRequests() => _leaves()
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(LeaveRequest.fromFirestore).toList());

  Future<void> updateLeaveStatus(String id, String status) async =>
      await _leaves().doc(id).update({'status': status});

  Future<void> createGoal(StaffGoal goal) async =>
      await _goals().add(goal.toFirestore());

  Stream<List<StaffGoal>> watchGoals() => _goals()
      .orderBy('deadline')
      .snapshots()
      .map((s) => s.docs.map(StaffGoal.fromFirestore).toList());

  Future<void> updateGoalProgress(String id, double current) async =>
      await _goals().doc(id).update({'current': current});

  Future<void> uploadDocument(
    String staffUid,
    String docName,
    String url,
  ) async {
    await _documents().add({
      'staffUid': staffUid,
      'name': docName,
      'url': url,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  }
}
