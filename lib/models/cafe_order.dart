import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/payment_mode.dart';
import '../utils/firestore_utils.dart';

class CafeOrderItem {
  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String? notes;
  /// Optional menu thumbnail (e.g. Firebase Storage URL from [StockItem.imageUrl]).
  final String? imageUrl;

  CafeOrderItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.notes,
    this.imageUrl,
  });

  double get total => price * quantity;

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'notes': notes,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'imageUrl': imageUrl,
    };
  }

  factory CafeOrderItem.fromFirestore(Map<String, dynamic> data) {
    final idRaw = data['itemId'] ?? data['menuItemId'] ?? '';
    final nameRaw = data['name'] ?? '';
    return CafeOrderItem(
      itemId: idRaw is String ? idRaw : idRaw.toString(),
      name: nameRaw is String ? nameRaw : nameRaw.toString(),
      price: parseFirestoreDouble(data['price']),
      quantity: parseFirestoreInt(data['quantity'], fallback: 1),
      notes: data['notes'] as String?,
      imageUrl: data['imageUrl'] as String?,
    );
  }

  CafeOrderItem copyWith({
    String? itemId,
    String? name,
    double? price,
    int? quantity,
    String? notes,
    String? imageUrl,
  }) {
    return CafeOrderItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class CafeOrder {
  final String id;
  final String? tableId;
  final String? tableName;
  final String? customerId;
  final String? customerName;
  final String? sessionId;
  final List<CafeOrderItem> items;
  final DateTime createdAt;
  final String
  status; // 'pending', 'preparing', 'ready', 'delivered', 'cancelled'
  final double total;
  final String? notes;
  final PaymentMethod? paymentMethod;
  final double? creditsUsed; // Credits deducted for this order (if any)
  final Map<String, double>?
  paymentBreakdown; // e.g. { 'Credits': 50, 'Cash': 30 }
  // For refunds: attribution of non-credit refund parts
  final Map<String, double>? refundPaymentBreakdown;
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
  // Refund history entries with snapshot of refunded items
  final List<Map<String, dynamic>> refundHistory;

  CafeOrder({
    required this.id,
    this.tableId,
    this.tableName,
    this.customerId,
    this.customerName,
    this.sessionId,
    required this.items,
    required this.createdAt,
    required this.status,
    required this.total,
    this.notes,
    this.paymentMethod,
    this.creditsUsed,
    this.paymentBreakdown,
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
    this.refundPaymentBreakdown,
    this.refundHistory = const [],
  });

  factory CafeOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsList = (data['items'] as List? ?? [])
        .map(
          (item) => CafeOrderItem.fromFirestore(item as Map<String, dynamic>),
        )
        .toList();

    return CafeOrder(
      id: doc.id,
      tableId: data['tableId'] as String?,
      tableName: data['tableName'] as String?,
      customerId: data['customerId'] as String?,
      customerName: data['customerName'] as String?,
      sessionId: data['sessionId'] as String?,
      items: itemsList,
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      status: data['status'] as String? ?? 'pending',
      total: parseFirestoreDouble(data['total']),
      notes: data['notes'] as String?,
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
      refundHistory:
          (data['refundHistory'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tableId': tableId,
      'tableName': tableName,
      'customerId': customerId,
      'customerName': customerName,
      'sessionId': sessionId,
      'items': items.map((item) => item.toFirestore()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'total': total,
      'notes': notes,
      'paymentMethod': paymentMethod?.toString().split('.').last.toLowerCase(),
      if (creditsUsed != null) 'creditsUsed': creditsUsed,
      if (paymentBreakdown != null) 'paymentBreakdown': paymentBreakdown,
      if (refundPaymentBreakdown != null)
        'refundPaymentBreakdown': refundPaymentBreakdown,
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
      if (refundHistory.isNotEmpty) 'refundHistory': refundHistory,
    };
  }

  CafeOrder copyWith({
    String? tableId,
    String? tableName,
    String? customerId,
    String? customerName,
    String? sessionId,
    List<CafeOrderItem>? items,
    DateTime? createdAt,
    String? status,
    double? total,
    String? notes,
    PaymentMethod? paymentMethod,
    bool? isBilled,
    DateTime? billedAt,
    String? performedById,
    String? performedByName,
    String? performedByRole,
    double? creditsUsed,
    Map<String, double>? paymentBreakdown,
    bool? isRefunded,
    double? refundAmount,
    DateTime? refundedAt,
    String? refundedById,
    String? refundedByName,
    String? refundedByRole,
  }) {
    return CafeOrder(
      id: id,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      sessionId: sessionId ?? this.sessionId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      creditsUsed: creditsUsed ?? this.creditsUsed,
      paymentBreakdown: paymentBreakdown ?? this.paymentBreakdown,
      isBilled: isBilled ?? this.isBilled,
      billedAt: billedAt ?? this.billedAt,
      performedById: performedById ?? this.performedById,
      performedByName: performedByName ?? this.performedByName,
      performedByRole: performedByRole ?? this.performedByRole,
      isRefunded: isRefunded ?? this.isRefunded,
      refundAmount: refundAmount ?? this.refundAmount,
      refundedAt: refundedAt ?? this.refundedAt,
      refundedById: refundedById ?? this.refundedById,
      refundedByName: refundedByName ?? this.refundedByName,
      refundedByRole: refundedByRole ?? this.refundedByRole,
    );
  }
}
