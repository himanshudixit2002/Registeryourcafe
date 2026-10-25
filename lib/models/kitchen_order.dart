import 'package:registeryourcafe/models/cafe_order.dart';

enum KitchenOrderStatus { pending, preparing, ready, completed, cancelled }

class KitchenOrder {
  final String id;
  final String orderNumber;
  final String? customerName;
  final String? tableName;
  final List<KitchenOrderItem> items;
  final KitchenOrderStatus status;
  final DateTime createdAt;
  final double total;
  final String paymentMethod;

  KitchenOrder({
    required this.id,
    required this.orderNumber,
    this.customerName,
    this.tableName,
    required this.items,
    required this.status,
    required this.createdAt,
    required this.total,
    required this.paymentMethod,
  });

  factory KitchenOrder.fromCafeOrder(CafeOrder order) {
    return KitchenOrder(
      id: order.id,
      orderNumber: order.id,
      customerName: order.customerName,
      tableName: order.tableName,
      items: order.items
          .map(
            (item) => KitchenOrderItem(
              name: item.name,
              quantity: item.quantity,
              imageUrl: item.imageUrl,
            ),
          )
          .toList(),
      status: _mapStatus(order.status),
      createdAt: order.createdAt,
      total: order.total,
      paymentMethod: order.paymentMethod?.toString().split('.').last ?? 'N/A',
    );
  }

  static KitchenOrderStatus _mapStatus(String status) {
    switch (status) {
      case 'pending':
        return KitchenOrderStatus.pending;
      case 'preparing':
        return KitchenOrderStatus.preparing;
      case 'ready':
        return KitchenOrderStatus.ready;
      case 'completed':
      case 'delivered':
        return KitchenOrderStatus.completed;
      case 'cancelled':
        return KitchenOrderStatus.cancelled;
      default:
        return KitchenOrderStatus.pending;
    }
  }
}

class KitchenOrderItem {
  final String name;
  final int quantity;
  final String? imageUrl;

  KitchenOrderItem({
    required this.name,
    required this.quantity,
    this.imageUrl,
  });
}
