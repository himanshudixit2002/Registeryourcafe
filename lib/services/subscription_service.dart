import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/subscription_plan.dart';

class SubscriptionService {
  final TenantRef _tenant;

  SubscriptionService(this._tenant);

  Future<String> getCurrentPlanId() async {
    final doc = await _tenant.companyDoc().get();
    final data = doc.data();
    return data?['subscriptionPlanId'] as String? ?? 'free';
  }

  Future<DateTime?> getExpirationDate() async {
    final doc = await _tenant.companyDoc().get();
    final data = doc.data();
    final ts = data?['subscriptionExpiresAt'] as Timestamp?;
    return ts?.toDate();
  }

  Future<void> upgradePlan(String planId) async {
    await _tenant.companyDoc().set({
      'subscriptionPlanId': planId,
      'subscriptionExpiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> canAddStaff() async {
    final planId = await getCurrentPlanId();
    final plan = SubscriptionPlan.findById(planId);
    final usersSnap = await _tenant.db
        .collection('users')
        .where('companyId', isEqualTo: _tenant.companyId)
        .get();
    return usersSnap.size < plan.maxStaff;
  }

  Future<bool> canAddTable() async {
    final planId = await getCurrentPlanId();
    final plan = SubscriptionPlan.findById(planId);
    final tablesSnap = await _tenant.tables().get();
    return tablesSnap.size < plan.maxTables;
  }
}
