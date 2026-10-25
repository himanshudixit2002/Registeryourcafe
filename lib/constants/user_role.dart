import '../models/app_user.dart';

export '../models/app_user.dart' show UserRole;

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Staff';
    }
  }

  String get storageValue => name.toLowerCase();

  static UserRole fromStorageValue(String? value) {
    if (value == null || value.isEmpty) return UserRole.staff;
    return UserRole.values.firstWhere(
      (e) => e.storageValue == value.toLowerCase(),
      orElse: () => UserRole.staff,
    );
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isStaffOnly => this == UserRole.staff;

  /// Prefer [effectivePermissionsProvider] / [PermissionIds] for UI gates.
  @Deprecated('Use EffectivePermissions.can(PermissionIds.opsRefund)')
  bool get canRefund => isAdmin;
  @Deprecated('Use EffectivePermissions and table permissions')
  bool get canManageTables => isAdmin;
  @Deprecated('Use EffectivePermissions and cafe/inventory permissions')
  bool get canManageStock => isAdmin;
  @Deprecated('Use EffectivePermissions.can(PermissionIds.navDashboard)')
  bool get canViewAnalytics => isAdmin;
}
