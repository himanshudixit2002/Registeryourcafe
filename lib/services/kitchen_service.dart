import '../firestore/tenant_firestore.dart';
import '../models/cafe_order.dart';
import '../models/kitchen_order.dart';

class KitchenService {
  final TenantRef _tenant;

  KitchenService(this._tenant);

  /// Returns a stream of orders filtered by the given statuses.
  Stream<List<KitchenOrder>> getOrdersStream(List<String> statuses) {
    return _tenant
        .cafeOrders()
        .where('status', whereIn: statuses)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    KitchenOrder.fromCafeOrder(CafeOrder.fromFirestore(doc)),
              )
              .toList(),
        );
  }

  Stream<List<KitchenOrder>> get pendingOrdersStream =>
      getOrdersStream(['pending']);

  Stream<List<KitchenOrder>> get preparingOrdersStream =>
      getOrdersStream(['preparing']);

  Stream<List<KitchenOrder>> get readyOrdersStream =>
      getOrdersStream(['ready']);

  Stream<List<KitchenOrder>> get activeOrdersStream =>
      getOrdersStream(['pending', 'preparing', 'ready']);

  Future<void> updateOrderStatus(String orderId, String newStatus) {
    return _tenant.cafeOrders().doc(orderId).update({'status': newStatus});
  }
}
