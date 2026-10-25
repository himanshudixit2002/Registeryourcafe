import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/promotion.dart';

class PromotionService {
  final TenantRef _tenant;

  PromotionService(this._tenant);

  CollectionReference<Map<String, dynamic>> _col() =>
      _tenant.companyDoc().collection('promotions');

  Stream<List<Promotion>> watchPromotions() {
    return _col()
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Promotion.fromFirestore).toList());
  }

  Stream<List<Promotion>> watchActivePromotions() {
    return _col()
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(Promotion.fromFirestore)
            .where((p) => p.isCurrentlyActive)
            .toList());
  }

  Future<void> createPromotion(Promotion promo) async {
    await _col().add(promo.toFirestore());
  }

  Future<void> toggleActive(String id, bool active) async {
    await _col().doc(id).update({'isActive': active});
  }

  Future<void> deletePromotion(String id) async {
    await _col().doc(id).delete();
  }

  Future<Promotion?> validateCoupon(String code) async {
    final snap = await _col()
        .where('couponCode', isEqualTo: code.toUpperCase())
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final promo = Promotion.fromFirestore(snap.docs.first);
    return promo.isCurrentlyActive ? promo : null;
  }
}
