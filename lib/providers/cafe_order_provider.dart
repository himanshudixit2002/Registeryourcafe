import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cafe_order.dart';
import '../utils/batch_query_utils.dart';
import 'tenant_provider.dart';

final cafeOrdersProvider = FutureProvider.autoDispose
    .family<List<CafeOrder>, List<String>>((ref, orderIds) async {
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return [];
      return BatchQueryUtils.fetchByIds<CafeOrder>(
        collectionRef: tenant.cafeOrders(),
        ids: orderIds,
        fromFirestore: CafeOrder.fromFirestore,
      );
    });

/// Session bill: merges orders from [orderIds] with any `cafe_orders` where
/// `sessionId` matches (fixes missing `cafeOrderIds` from legacy writes).
final sessionBillCafeOrdersProvider = FutureProvider.autoDispose
    .family<List<CafeOrder>, ({String sessionId, List<String> orderIds})>((
      ref,
      key,
    ) async {
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return [];

      final byId = <String, CafeOrder>{};

      if (key.orderIds.isNotEmpty) {
        final fromIds = await BatchQueryUtils.fetchByIds<CafeOrder>(
          collectionRef: tenant.cafeOrders(),
          ids: key.orderIds,
          fromFirestore: CafeOrder.fromFirestore,
        );
        for (final o in fromIds) {
          byId[o.id] = o;
        }
      }

      final snap = await tenant
          .cafeOrders()
          .where('sessionId', isEqualTo: key.sessionId)
          .get();

      for (final doc in snap.docs) {
        final o = CafeOrder.fromFirestore(doc);
        if (o.status.toLowerCase() == 'cancelled') continue;
        byId.putIfAbsent(o.id, () => o);
      }

      final list = byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
