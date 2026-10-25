import '../utils/firestore_utils.dart';
import 'company_role.dart';

enum UserRole { admin, staff }

class AppUser {
  final String uid;
  final String name;
  final String? phoneNumber;
  final String email;
  final UserRole role;

  /// Firestore company document id (`companies/{companyId}`). Null for legacy accounts.
  final String? companyId;

  /// `companies/{companyId}/permissionRoles/{roleId}`. Null for legacy profiles.
  final String? roleId;

  AppUser({
    required this.uid,
    required this.name,
    this.phoneNumber,
    required this.email,
    required this.role,
    this.companyId,
    this.roleId,
  });

  /// Prefer stored [roleId]; otherwise derive from legacy [role] for permissions.
  String get resolvedRoleId {
    if (roleId != null && roleId!.isNotEmpty) return roleId!;
    return role == UserRole.admin ? SystemRoleIds.owner : SystemRoleIds.staff;
  }

  factory AppUser.fromMap(Map<String, dynamic> data, String documentId) {
    final nameRaw = data['name'];
    final emailRaw = data['email'];
    return AppUser(
      uid: documentId,
      name: nameRaw is String && nameRaw.trim().isNotEmpty
          ? nameRaw.trim()
          : 'No Name',
      phoneNumber: data['phoneNumber'] as String?,
      email: emailRaw is String ? emailRaw : '',
      role: _parseRole(data['role']),
      companyId: parseFirestoreStringOrNull(data['companyId']),
      roleId: parseFirestoreStringOrNull(data['roleId']),
    );
  }

  static UserRole _parseRole(dynamic raw) {
    final key = raw?.toString().trim().toLowerCase() ?? '';
    if (key.isEmpty) return UserRole.staff;
    for (final e in UserRole.values) {
      if (e.toString().split('.').last.toLowerCase() == key) {
        return e;
      }
    }
    if (key.endsWith('admin')) return UserRole.admin;
    if (key.endsWith('staff')) return UserRole.staff;
    return UserRole.staff;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'role': role.toString().split('.').last,
      if (companyId != null) 'companyId': companyId,
      if (roleId != null && roleId!.isNotEmpty) 'roleId': roleId,
    };
  }
}
