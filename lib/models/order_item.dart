abstract class OrderItemBase {
  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String? notes;

  const OrderItemBase({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.notes,
  });

  /// Total price for this item (price × quantity)
  double get total => price * quantity;

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      if (notes != null) 'notes': notes,
    };
  }

  /// Convert to print-friendly format
  Map<String, dynamic> toPrintFormat() {
    return {'name': name, 'price': price, 'quantity': quantity};
  }

  /// Convert to refund history format
  Map<String, dynamic> toRefundFormat() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}

extension OrderItemListExtension<T extends OrderItemBase> on List<T> {
  /// Calculate total for all items
  double get totalAmount => fold(0.0, (sum, item) => sum + item.total);

  /// Convert all items to Firestore format
  List<Map<String, dynamic>> toFirestoreList() =>
      map((e) => e.toFirestore()).toList();

  /// Convert all items to print format
  List<Map<String, dynamic>> toPrintFormatList() =>
      map((e) => e.toPrintFormat()).toList();

  /// Convert all items to refund format
  List<Map<String, dynamic>> toRefundFormatList() =>
      map((e) => e.toRefundFormat()).toList();

  /// Get total quantity of all items
  int get totalQuantity => fold(0, (sum, item) => sum + item.quantity);
}
