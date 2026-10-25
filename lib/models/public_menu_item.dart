import 'package:cloud_firestore/cloud_firestore.dart';

class PublicMenuItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? categoryLabel;
  final int sortOrder;
  final bool isAvailable;
  final DateTime? updatedAt;
  final String? imageUrl;

  /// When true, row is mirrored from [stock_items] with the same document id.
  final bool syncedFromStock;

  const PublicMenuItem({
    required this.id,
    required this.name,
    this.description,
    this.price = 0,
    this.categoryLabel,
    this.sortOrder = 0,
    this.isAvailable = true,
    this.updatedAt,
    this.imageUrl,
    this.syncedFromStock = false,
  });

  factory PublicMenuItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final priceRaw = data['price'];
    double price = 0;
    if (priceRaw is num) {
      price = priceRaw.toDouble();
    } else if (priceRaw != null) {
      price = double.tryParse(priceRaw.toString()) ?? 0;
    }
    return PublicMenuItem(
      id: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'Item',
      description: data['description'] as String?,
      price: price,
      categoryLabel: data['categoryLabel'] as String?,
      sortOrder: (data['sortOrder'] is int)
          ? data['sortOrder'] as int
          : int.tryParse('${data['sortOrder']}') ?? 0,
      isAvailable: data['isAvailable'] != false,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      imageUrl: data['imageUrl'] as String?,
      syncedFromStock: data['syncedFromStock'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null && description!.trim().isNotEmpty)
        'description': description,
      'price': price,
      if (categoryLabel != null && categoryLabel!.trim().isNotEmpty)
        'categoryLabel': categoryLabel,
      'sortOrder': sortOrder,
      'isAvailable': isAvailable,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) 'imageUrl': imageUrl,
      'syncedFromStock': syncedFromStock,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
