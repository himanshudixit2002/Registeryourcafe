import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/guest_cafe_order.dart';
import '../services/guest_cafe_order_service.dart';
import 'tenant_provider.dart';

final guestCafeOrderServiceProvider = Provider<GuestCafeOrderService?>((ref) {
  final t = ref.watch(tenantRefProvider);
  if (t == null) return null;
  return GuestCafeOrderService(t);
});

final pendingGuestCafeOrdersProvider =
    StreamProvider.autoDispose<List<GuestCafeOrder>>((ref) {
  final svc = ref.watch(guestCafeOrderServiceProvider);
  if (svc == null) {
    return Stream.value(const <GuestCafeOrder>[]);
  }
  return svc.pendingOrdersStream();
});
