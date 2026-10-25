import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';
import '../utils/firestore_utils.dart';

class MerchandiseOrderItem {
  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String? notes;

  MerchandiseOrderItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      if (notes != null) 'notes': notes,
    };
  }

  factory MerchandiseOrderItem.fromFirestore(Map<String, dynamic> data) {
    return MerchandiseOrderItem(
      itemId: data['itemId'] as String,
      name: data['name'] as String,
      price: parseFirestoreDouble(data['price']),
      quantity: parseFirestoreInt(data['quantity'], fallback: 1),
      notes: data['notes'] as String?,
    );
  }
}

class MerchandiseOrder {
  final String id;
  final List<MerchandiseOrderItem> items;
  final String status;
  final DateTime createdAt;
  final double total;
  final PaymentMethod? paymentMethod;
  final double? creditsUsed;
  final Map<String, double>? paymentBreakdown;
  final Map<String, double>? refundPaymentBreakdown;
  final String? customerId;
  final String? customerName;
  final String? tableId;
  final String? tableName;
  final String? sessionId;
  final bool isBilled;
  final DateTime? billedAt;
  final String? performedById;
  final String? performedByName;
  final String? performedByRole;
  // Refund meta
  final bool isRefunded;
  final double? refundAmount;
  final DateTime? refundedAt;
  final String? refundedById;
  final String? refundedByName;
  final String? refundedByRole;
  final List<Map<String, dynamic>>? refundHistory;

  MerchandiseOrder({
    required this.id,
    required this.items,
    required this.status,
    required this.createdAt,
    required this.total,
    this.paymentMethod,
    this.creditsUsed,
    this.paymentBreakdown,
    this.customerId,
    this.customerName,
    this.tableId,
    this.tableName,
    this.sessionId,
    this.isBilled = false,
    this.billedAt,
    this.performedById,
    this.performedByName,
    this.performedByRole,
    this.isRefunded = false,
    this.refundAmount,
    this.refundedAt,
    this.refundedById,
    this.refundedByName,
    this.refundedByRole,
    this.refundHistory,
    this.refundPaymentBreakdown,
  });

  factory MerchandiseOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MerchandiseOrder(
      id: doc.id,
      items: (data['items'] as List<dynamic>? ?? [])
          .map(
            (item) => MerchandiseOrderItem.fromFirestore(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      total: parseFirestoreDouble(data['total']),
      paymentMethod: data['paymentMethod'] != null
          ? PaymentMethodExtension.fromStorageValue(
              data['paymentMethod'] as String?,
            )
          : null,
      creditsUsed: parseFirestoreDoubleOrNull(data['creditsUsed']),
      paymentBreakdown: (data['paymentBreakdown'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, parseFirestoreDouble(v))),
      refundPaymentBreakdown:
          (data['refundPaymentBreakdown'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, parseFirestoreDouble(v)),
          ),
      customerId: data['customerId'] as String?,
      customerName: data['customerName'] as String?,
      tableId: data['tableId'] as String?,
      tableName: data['tableName'] as String?,
      sessionId: data['sessionId'] as String?,
      isBilled: data['isBilled'] as bool? ?? false,
      billedAt: (data['billedAt'] as Timestamp?)?.toDate(),
      performedById: data['performedById'] as String?,
      performedByName: data['performedByName'] as String?,
      performedByRole: data['performedByRole'] as String?,
      isRefunded: data['isRefunded'] as bool? ?? false,
      refundAmount: parseFirestoreDoubleOrNull(data['refundAmount']),
      refundedAt: (data['refundedAt'] as Timestamp?)?.toDate(),
      refundedById: data['refundedById'] as String?,
      refundedByName: data['refundedByName'] as String?,
      refundedByRole: data['refundedByRole'] as String?,
      refundHistory: (data['refundHistory'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'items': items.map((item) => item.toFirestore()).toList(),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'total': total,
      if (paymentMethod != null)
        'paymentMethod': paymentMethod!.toString().split('.').last,
      if (creditsUsed != null) 'creditsUsed': creditsUsed,
      if (paymentBreakdown != null) 'paymentBreakdown': paymentBreakdown,
      if (refundPaymentBreakdown != null)
        'refundPaymentBreakdown': refundPaymentBreakdown,
      'customerId': customerId,
      'customerName': customerName,
      'tableId': tableId,
      'tableName': tableName,
      'sessionId': sessionId,
      'isBilled': isBilled,
      'billedAt': billedAt != null ? Timestamp.fromDate(billedAt!) : null,
      'performedById': performedById,
      'performedByName': performedByName,
      'performedByRole': performedByRole,
      'isRefunded': isRefunded,
      if (refundAmount != null) 'refundAmount': refundAmount,
      'refundedAt': refundedAt != null ? Timestamp.fromDate(refundedAt!) : null,
      'refundedById': refundedById,
      'refundedByName': refundedByName,
      'refundedByRole': refundedByRole,
      if (refundHistory != null && refundHistory!.isNotEmpty)
        'refundHistory': refundHistory,
    };
  }
}
