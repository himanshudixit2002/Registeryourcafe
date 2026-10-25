import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/customer_engagement.dart';

class CustomerEngagementService {
  final TenantRef _tenant;
  CustomerEngagementService(this._tenant);

  CollectionReference<Map<String, dynamic>> _prefs() =>
      _tenant.companyDoc().collection('customerPreferences');
  CollectionReference<Map<String, dynamic>> _referrals() =>
      _tenant.companyDoc().collection('referrals');
  CollectionReference<Map<String, dynamic>> _waitlist() =>
      _tenant.companyDoc().collection('waitlist');
  CollectionReference<Map<String, dynamic>> _segments() =>
      _tenant.companyDoc().collection('customerSegments');
  CollectionReference<Map<String, dynamic>> _campaigns() =>
      _tenant.companyDoc().collection('campaigns');

  Future<void> savePreferences(
    String customerId,
    CustomerPreference pref,
  ) async =>
      await _prefs().doc(customerId).set(
        pref.toFirestore(),
        SetOptions(merge: true),
      );

  Future<CustomerPreference?> getPreferences(String customerId) async {
    final doc = await _prefs().doc(customerId).get();
    return doc.exists ? CustomerPreference.fromFirestore(doc) : null;
  }

  Future<void> createReferral(ReferralRecord referral) async =>
      await _referrals().add(referral.toFirestore());

  Stream<List<ReferralRecord>> watchReferrals() => _referrals()
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(ReferralRecord.fromFirestore).toList());

  Future<void> addToWaitlist(WaitlistEntry entry) async =>
      await _waitlist().add(entry.toFirestore());

  Stream<List<WaitlistEntry>> watchWaitlist() => _waitlist()
      .where('status', isEqualTo: 'waiting')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(WaitlistEntry.fromFirestore).toList());

  Future<void> updateWaitlistStatus(String id, String status) async =>
      await _waitlist().doc(id).update({'status': status});

  Future<void> createSegment({
    required String name,
    required Map<String, dynamic> criteria,
  }) async {
    await _segments().add({
      'name': name,
      'criteria': criteria,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      watchSegments() => _segments()
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs);

  Future<void> createCampaign({
    required String name,
    required String message,
    required String segmentId,
  }) async {
    await _campaigns().add({
      'name': name,
      'message': message,
      'segmentId': segmentId,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      watchCampaigns() => _campaigns()
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs);
}
