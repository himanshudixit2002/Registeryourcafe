import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/customer_feedback.dart';

class FeedbackService {
  final TenantRef _tenant;

  FeedbackService(this._tenant);

  CollectionReference<Map<String, dynamic>> _col() =>
      _tenant.companyDoc().collection('feedback');

  Stream<List<CustomerFeedback>> watchFeedback({int limit = 100}) {
    return _col()
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(CustomerFeedback.fromFirestore).toList());
  }

  Future<void> submitFeedback(CustomerFeedback feedback) async {
    await _col().add(feedback.toFirestore());
  }

  Future<void> respondToFeedback(String id, String response) async {
    await _col().doc(id).update({'response': response});
  }

  Future<void> deleteFeedback(String id) async {
    await _col().doc(id).delete();
  }
}
