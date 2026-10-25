import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;

  /// If true, this category is meant for merchandise items, otherwise for cafe items.
  final bool isMerchandise;

  Category({required this.id, required this.name, required this.isMerchandise});

  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      isMerchandise: (data['isMerchandise'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name, 'isMerchandise': isMerchandise};
  }
}
