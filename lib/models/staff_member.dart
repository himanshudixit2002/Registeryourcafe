import 'package:cloud_firestore/cloud_firestore.dart';

class StaffMember {
  final String uid;
  final String name;
  final String email;
  final String? phoneNumber;
  final String role;
  final String? roleId;
  final String? companyId;
  final bool isActive;

  const StaffMember({
    required this.uid,
    required this.name,
    required this.email,
    this.phoneNumber,
    required this.role,
    this.roleId,
    this.companyId,
    this.isActive = true,
  });

  factory StaffMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StaffMember(
      uid: doc.id,
      name: data['name'] as String? ?? 'No Name',
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      role: data['role'] as String? ?? 'staff',
      roleId: data['roleId'] as String?,
      companyId: data['companyId'] as String?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}
