import '../models/app_user.dart';
import '../models/company_role.dart';

/// Maps fine-grained [roleId] to legacy coarse [UserRole] for Firestore `role` field.
UserRole coarseUserRoleForRoleId(String? roleId) {
  if (roleId == null || roleId.isEmpty) return UserRole.staff;
  if (roleId == SystemRoleIds.owner || roleId == SystemRoleIds.manager) {
    return UserRole.admin;
  }
  return UserRole.staff;
}
