import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

class StockItem {
  final String id;
  final String name;
  final String unit; // e.g., kg, liter, piece
  double quantity;
  final double lowStockThreshold; // Optional: for low stock alerts
  final Timestamp lastUpdated;

  // New fields for making stock items sellable on the menu
  final double? price; // Selling price, required if isSellable is true
  final bool isSellable; // Defaults to false, if true, item can appear on menu
  final String? description; // Optional: for menu display
  final String? imageUrl; // Optional: for menu display
  final String?
  category; // Optional: for menu display (e.g., "Drinks", "Snacks")
  final bool
  isMerchandise; // New field: distinguishes merchandise from cafe items
  /// Last purchase unit cost from vendor receipts (optional).
  final double? lastUnitCost;

  /// Other `stock_items` doc IDs that receive the same quantity when this item is on a vendor receipt (one hop).
  final List<String> linkedStockItemIds;

  StockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.lowStockThreshold,
    required this.lastUpdated,
    this.price, // Nullable, but logic will enforce if isSellable
    this.isSellable = false, // Default to false
    this.description,
    this.imageUrl,
    this.category,
    this.isMerchandise = false, // Default to not merchandise
    this.lastUnitCost,
    this.linkedStockItemIds = const [],
  });

  factory StockItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameRaw = data['name'];
    final unitRaw = data['unit'];
    final lastUpd = data['lastUpdated'];
    return StockItem(
      id: doc.id,
      name: nameRaw is String ? nameRaw : '${nameRaw ?? ''}',
      unit: unitRaw is String ? unitRaw : '${unitRaw ?? 'piece'}',
      quantity: parseFirestoreDouble(data['quantity']),
      lowStockThreshold: parseFirestoreDouble(data['lowStockThreshold']),
      lastUpdated: lastUpd is Timestamp ? lastUpd : Timestamp.now(),
      price: parseFirestoreDoubleOrNull(data['price']),
      isSellable: data['isSellable'] as bool? ?? false,
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      category: data['category'] as String?,
      isMerchandise: data['isMerchandise'] as bool? ?? false,
      lastUnitCost: parseFirestoreDoubleOrNull(data['lastUnitCost']),
      linkedStockItemIds: _parseIdList(data['linkedStockItemIds']),
    );
  }

  static List<String> _parseIdList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Reads [linkedStockItemIds] from raw Firestore field value.
  static List<String> parseLinkedStockItemIdsField(dynamic raw) =>
      _parseIdList(raw);

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'unit': unit,
      'quantity': quantity,
      'lowStockThreshold': lowStockThreshold,
      'lastUpdated': lastUpdated,
      'price': price,
      'isSellable': isSellable,
      'description': description,
      'imageUrl': imageUrl,
      'category': category,
      'isMerchandise': isMerchandise,
      'lastUnitCost': lastUnitCost,
      'linkedStockItemIds': linkedStockItemIds,
    }..removeWhere(
      (key, value) => value == null && key != 'price',
    ); // Keep price if null, but remove other optional nulls
  }

  StockItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    Timestamp? lastUpdated,
    double? lowStockThreshold,
    bool? isSellable,
    double? price,
    String? description,
    String? imageUrl,
    String? category,
    bool? isMerchandise,
    double? lastUnitCost,
    List<String>? linkedStockItemIds,
  }) {
    return StockItem(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      price: price ?? this.price,
      isSellable: isSellable ?? this.isSellable,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      isMerchandise: isMerchandise ?? this.isMerchandise,
      lastUnitCost: lastUnitCost ?? this.lastUnitCost,
      linkedStockItemIds: linkedStockItemIds ?? this.linkedStockItemIds,
    );
  }
}
