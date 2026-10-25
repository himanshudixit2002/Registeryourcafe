import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/marketing.dart';

class MarketingService {
  final TenantRef _tenant;
  MarketingService(this._tenant);

  CollectionReference<Map<String, dynamic>> _giftCards() =>
      _tenant.companyDoc().collection('giftCards');
  CollectionReference<Map<String, dynamic>> _campaigns() =>
      _tenant.companyDoc().collection('marketingCampaigns');
  CollectionReference<Map<String, dynamic>> _budgets() =>
      _tenant.companyDoc().collection('marketingBudgets');

  Future<void> createGiftCard(GiftCard card) async =>
      await _giftCards().add(card.toFirestore());

  Stream<List<GiftCard>> watchGiftCards() => _giftCards()
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(GiftCard.fromFirestore).toList());

  Future<void> redeemGiftCard(String id, double amount) async {
    final doc = await _giftCards().doc(id).get();
    final current =
        (doc.data()?['currentBalance'] as num?)?.toDouble() ?? 0;
    await _giftCards().doc(id).update({'currentBalance': current - amount});
  }

  Future<void> createCampaign(MarketingCampaign campaign) async =>
      await _campaigns().add(campaign.toFirestore());

  Stream<List<MarketingCampaign>> watchCampaigns() => _campaigns()
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MarketingCampaign.fromFirestore).toList());

  Future<void> updateCampaignStatus(String id, String status) async =>
      await _campaigns().doc(id).update({'status': status});

  Future<void> saveBudget(MarketingBudget budget) async =>
      await _budgets().add(budget.toFirestore());

  Stream<List<MarketingBudget>> watchBudgets() => _budgets()
      .snapshots()
      .map((s) => s.docs.map(MarketingBudget.fromFirestore).toList());
}
