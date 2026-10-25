import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/promotion.dart';
import '../services/promotion_service.dart';
import 'tenant_provider.dart';

final promotionServiceProvider = Provider<PromotionService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return PromotionService(tenant);
});

final promotionsProvider = StreamProvider<List<Promotion>>((ref) {
  final service = ref.watch(promotionServiceProvider);
  if (service == null) return Stream.value([]);
  return service.watchPromotions();
});

final activePromotionsProvider = StreamProvider<List<Promotion>>((ref) {
  final service = ref.watch(promotionServiceProvider);
  if (service == null) return Stream.value([]);
  return service.watchActivePromotions();
});
