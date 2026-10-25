import 'package:cloud_firestore/cloud_firestore.dart';

class SplitBillEntry {
  final String guestName;
  final double amount;
  final String paymentMethod;

  const SplitBillEntry({
    required this.guestName,
    required this.amount,
    required this.paymentMethod,
  });

  Map<String, dynamic> toMap() => {
    'guestName': guestName,
    'amount': amount,
    'paymentMethod': paymentMethod,
  };

  factory SplitBillEntry.fromMap(Map<String, dynamic> m) => SplitBillEntry(
    guestName: m['guestName'] as String? ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    paymentMethod: m['paymentMethod'] as String? ?? 'cash',
  );
}

class OrderNote {
  final String itemId;
  final String note;

  const OrderNote({required this.itemId, required this.note});

  Map<String, dynamic> toMap() => {'itemId': itemId, 'note': note};

  factory OrderNote.fromMap(Map<String, dynamic> m) => OrderNote(
    itemId: m['itemId'] as String? ?? '',
    note: m['note'] as String? ?? '',
  );
}

class TipRecord {
  final String orderId;
  final double amount;
  final String? staffUid;
  final DateTime createdAt;

  const TipRecord({
    required this.orderId,
    required this.amount,
    this.staffUid,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() => {
    'orderId': orderId,
    'amount': amount,
    if (staffUid != null) 'staffUid': staffUid,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory TipRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return TipRecord(
      orderId: d['orderId'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      staffUid: d['staffUid'] as String?,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

enum OrderMode { dineIn, takeaway, delivery, preOrder }

class PreOrder {
  final String id;
  final String customerName;
  final String customerPhone;
  final DateTime scheduledFor;
  final List<Map<String, dynamic>> items;
  final String status;
  final DateTime createdAt;

  const PreOrder({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.scheduledFor,
    required this.items,
    this.status = 'pending',
    required this.createdAt,
  });

  factory PreOrder.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return PreOrder(
      id: doc.id,
      customerName: d['customerName'] as String? ?? '',
      customerPhone: d['customerPhone'] as String? ?? '',
      scheduledFor:
          (d['scheduledFor'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: (d['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [],
      status: d['status'] as String? ?? 'pending',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'customerName': customerName,
    'customerPhone': customerPhone,
    'scheduledFor': Timestamp.fromDate(scheduledFor),
    'items': items,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
