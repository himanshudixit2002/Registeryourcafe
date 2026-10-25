import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/merchandise_order.dart';
import '../utils/batch_query_utils.dart';
import 'tenant_provider.dart';

final merchandiseOrdersProvider = FutureProvider.autoDispose
    .family<List<MerchandiseOrder>, List<String>>((ref, orderIds) async {
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return [];
      return BatchQueryUtils.fetchByIds<MerchandiseOrder>(
        collectionRef: tenant.merchandiseOrders(),
        ids: orderIds,
        fromFirestore: MerchandiseOrder.fromFirestore,
      );
    });

/// Session bill: merges orders from [orderIds] with `merchandise_orders` by `sessionId`.
final sessionBillMerchandiseOrdersProvider = FutureProvider.autoDispose
    .family<
      List<MerchandiseOrder>,
      ({String sessionId, List<String> orderIds})
    >((ref, key) async {
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return [];

      final byId = <String, MerchandiseOrder>{};

      if (key.orderIds.isNotEmpty) {
        final fromIds = await BatchQueryUtils.fetchByIds<MerchandiseOrder>(
          collectionRef: tenant.merchandiseOrders(),
          ids: key.orderIds,
          fromFirestore: MerchandiseOrder.fromFirestore,
        );
        for (final o in fromIds) {
          byId[o.id] = o;
        }
      }

      final snap = await tenant
          .merchandiseOrders()
          .where('sessionId', isEqualTo: key.sessionId)
          .get();

      for (final doc in snap.docs) {
        final o = MerchandiseOrder.fromFirestore(doc);
        if (o.status.toLowerCase() == 'cancelled') continue;
        byId.putIfAbsent(o.id, () => o);
      }

      final list = byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
