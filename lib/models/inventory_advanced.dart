import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrder {
  final String id;
  final String vendorId;
  final String vendorName;
  final List<PurchaseOrderItem> items;
  final String status;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime? expectedDelivery;

  const PurchaseOrder({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.items,
    this.status = 'draft',
    required this.totalAmount,
    required this.createdAt,
    this.expectedDelivery,
  });

  factory PurchaseOrder.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return PurchaseOrder(
      id: doc.id,
      vendorId: d['vendorId'] as String? ?? '',
      vendorName: d['vendorName'] as String? ?? '',
      items: (d['items'] as List?)
              ?.map(
                (e) => PurchaseOrderItem.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      status: d['status'] as String? ?? 'draft',
      totalAmount: (d['totalAmount'] as num?)?.toDouble() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expectedDelivery: (d['expectedDelivery'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'vendorId': vendorId,
    'vendorName': vendorName,
    'items': items.map((e) => e.toMap()).toList(),
    'status': status,
    'totalAmount': totalAmount,
    'createdAt': Timestamp.fromDate(createdAt),
    if (expectedDelivery != null)
      'expectedDelivery': Timestamp.fromDate(expectedDelivery!),
  };
}

class PurchaseOrderItem {
  final String itemId;
  final String itemName;
  final double quantity;
  final double unitPrice;

  const PurchaseOrderItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> m) =>
      PurchaseOrderItem(
        itemId: m['itemId'] as String? ?? '',
        itemName: m['itemName'] as String? ?? '',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
      );
}

class StockAlert {
  final String itemId;
  final String itemName;
  final double currentStock;
  final double threshold;

  const StockAlert({
    required this.itemId,
    required this.itemName,
    required this.currentStock,
    required this.threshold,
  });
}

class ExpiryRecord {
  final String id;
  final String itemId;
  final String itemName;
  final String batchId;
  final DateTime expiryDate;
  final double quantity;

  const ExpiryRecord({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.batchId,
    required this.expiryDate,
    required this.quantity,
  });

  factory ExpiryRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ExpiryRecord(
      id: doc.id,
      itemId: d['itemId'] as String? ?? '',
      itemName: d['itemName'] as String? ?? '',
      batchId: d['batchId'] as String? ?? '',
      expiryDate: (d['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      quantity: (d['quantity'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'itemId': itemId,
    'itemName': itemName,
    'batchId': batchId,
    'expiryDate': Timestamp.fromDate(expiryDate),
    'quantity': quantity,
  };
}
