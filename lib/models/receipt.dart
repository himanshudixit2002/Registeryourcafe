import 'package:cloud_firestore/cloud_firestore.dart';

class Receipt {
  final String id;
  final int receiptNumber;
  final String companyName;
  final String? companyAddress;
  final String? companyPhone;
  final String? customerName;
  final String? customerPhone;
  final List<ReceiptItem> items;
  final double subtotal;
  final double taxAmount;
  final String taxLabel;
  final double total;
  final String paymentMethod;
  final DateTime createdAt;
  final String createdBy;

  const Receipt({
    required this.id,
    required this.receiptNumber,
    required this.companyName,
    this.companyAddress,
    this.companyPhone,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.taxLabel,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    required this.createdBy,
  });

  String get formattedNumber =>
      'RCP-${receiptNumber.toString().padLeft(6, '0')}';

  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final itemsList = (data['items'] as List<dynamic>? ?? [])
        .map((e) => ReceiptItem.fromMap(e as Map<String, dynamic>))
        .toList();
    return Receipt(
      id: doc.id,
      receiptNumber: (data['receiptNumber'] as num?)?.toInt() ?? 0,
      companyName: data['companyName'] as String? ?? '',
      companyAddress: data['companyAddress'] as String?,
      companyPhone: data['companyPhone'] as String?,
      customerName: data['customerName'] as String?,
      customerPhone: data['customerPhone'] as String?,
      items: itemsList,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0,
      taxLabel: data['taxLabel'] as String? ?? 'Tax',
      total: (data['total'] as num?)?.toDouble() ?? 0,
      paymentMethod: data['paymentMethod'] as String? ?? 'cash',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'receiptNumber': receiptNumber,
      'companyName': companyName,
      if (companyAddress != null) 'companyAddress': companyAddress,
      if (companyPhone != null) 'companyPhone': companyPhone,
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'taxLabel': taxLabel,
      'total': total,
      'paymentMethod': paymentMethod,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}

class ReceiptItem {
  final String name;
  final int quantity;
  final double price;
  final double total;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory ReceiptItem.fromMap(Map<String, dynamic> data) {
    return ReceiptItem(
      name: data['name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }
}
