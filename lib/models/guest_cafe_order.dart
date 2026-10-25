import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';
import 'cafe_order.dart';

/// Public-landing guest menu order (pending until staff promotes to [CafeOrder]).
class GuestCafeOrderItem {
  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String? notes;
  final String? imageUrl;

  const GuestCafeOrderItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.notes,
    this.imageUrl,
  });

  Map<String, dynamic> toFirestoreMap() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'imageUrl': imageUrl,
    };
  }

  factory GuestCafeOrderItem.fromFirestoreMap(Map<String, dynamic> m) {
    return GuestCafeOrderItem(
      itemId: m['itemId'] as String? ?? '',
      name: m['name'] as String? ?? '',
      price: parseFirestoreDouble(m['price']),
      quantity: parseFirestoreInt(m['quantity'], fallback: 1),
      notes: m['notes'] as String?,
      imageUrl: m['imageUrl'] as String?,
    );
  }

  CafeOrderItem toCafeOrderItem() {
    return CafeOrderItem(
      itemId: itemId,
      name: name,
      price: price,
      quantity: quantity,
      notes: notes,
      imageUrl: imageUrl,
    );
  }
}

class GuestCafeOrder {
  final String id;
  final List<GuestCafeOrderItem> items;
  final double total;
  final String status;
  final String requesterUid;
  final DateTime createdAt;
  final String guestName;
  final String guestPhone;
  final String orderMode;
  final String tableId;
  final String tableName;
  final String guestNotes;
  final String? convertedCafeOrderId;
  final DateTime? updatedAt;

  const GuestCafeOrder({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.requesterUid,
    required this.createdAt,
    required this.guestName,
    required this.guestPhone,
    required this.orderMode,
    required this.tableId,
    required this.tableName,
    required this.guestNotes,
    this.convertedCafeOrderId,
    this.updatedAt,
  });

  factory GuestCafeOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawItems = data['items'] as List? ?? [];
    final items = rawItems
        .map(
          (e) => GuestCafeOrderItem.fromFirestoreMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    return GuestCafeOrder(
      id: doc.id,
      items: items,
      total: parseFirestoreDouble(data['total']),
      status: data['status'] as String? ?? 'pending',
      requesterUid: data['requesterUid'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      guestName: data['guestName'] as String? ?? '',
      guestPhone: data['guestPhone'] as String? ?? '',
      orderMode: data['orderMode'] as String? ?? 'counter',
      tableId: data['tableId'] as String? ?? '',
      tableName: data['tableName'] as String? ?? '',
      guestNotes: data['guestNotes'] as String? ?? '',
      convertedCafeOrderId: data['convertedCafeOrderId'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isPending => status == 'pending';
}
