import 'package:cloud_firestore/cloud_firestore.dart';

class Vendor {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final bool isActive;
  final Timestamp createdAt;

  Vendor({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  factory Vendor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Vendor(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      notes: data['notes'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
      'isActive': isActive,
      'createdAt': createdAt,
    }..removeWhere((k, v) => v == null);
  }
}
