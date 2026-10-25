import 'package:cloud_firestore/cloud_firestore.dart';

class Invoice {
  final String id;
  final int invoiceNumber;
  final String prefix;
  final double subtotal;
  final double taxAmount;
  final double taxRate;
  final String taxLabel;
  final double total;
  final String? customerName;
  final String? sessionId;
  final DateTime createdAt;
  final String createdBy;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.prefix,
    required this.subtotal,
    required this.taxAmount,
    required this.taxRate,
    required this.taxLabel,
    required this.total,
    this.customerName,
    this.sessionId,
    required this.createdAt,
    required this.createdBy,
  });

  String get formattedNumber =>
      '$prefix-${invoiceNumber.toString().padLeft(6, '0')}';

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Invoice(
      id: doc.id,
      invoiceNumber: (data['invoiceNumber'] as num?)?.toInt() ?? 0,
      prefix: data['prefix'] as String? ?? 'INV',
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0,
      taxRate: (data['taxRate'] as num?)?.toDouble() ?? 0,
      taxLabel: data['taxLabel'] as String? ?? 'GST',
      total: (data['total'] as num?)?.toDouble() ?? 0,
      customerName: data['customerName'] as String?,
      sessionId: data['sessionId'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'invoiceNumber': invoiceNumber,
      'prefix': prefix,
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'taxRate': taxRate,
      'taxLabel': taxLabel,
      'total': total,
      if (customerName != null) 'customerName': customerName,
      if (sessionId != null) 'sessionId': sessionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}
