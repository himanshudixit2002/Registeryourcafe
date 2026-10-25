import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/permission_id.dart';

/// Document: `companies/{companyId}/permissionRoles/{roleId}`
class CompanyRole {
  const CompanyRole({
    required this.id,
    required this.name,
    this.description,
    required this.permissionIds,
    this.isSystem = false,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final List<String> permissionIds;
  final bool isSystem;
  final DateTime? updatedAt;

  factory CompanyRole.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? {};
    final raw = data['permissionIds'];
    final ids = <String>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is String && e.isNotEmpty) ids.add(e);
      }
    }
    return CompanyRole(
      id: snap.id,
      name: data['name'] as String? ?? snap.id,
      description: data['description'] as String?,
      permissionIds: ids,
      isSystem: data['isSystem'] as bool? ?? false,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'permissionIds': permissionIds,
      'isSystem': isSystem,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Built-in role document ids (seeded per company).
abstract final class SystemRoleIds {
  static const owner = 'owner';
  static const manager = 'manager';
  static const staff = 'staff';
  static const cashier = 'cashier';
}

/// Default permission sets for seeded roles.
abstract final class DefaultRolePermissions {
  static Set<String> get owner => PermissionIds.all.toSet();

  /// Everything except editing role definitions (optional safety).
  static Set<String> get manager =>
      PermissionIds.all.where((p) => p != PermissionIds.settingsRoles).toSet();

  static Set<String> get staff => {
    PermissionIds.navDashboard,
    PermissionIds.navTables,
    PermissionIds.navCafe,
    PermissionIds.opsCafeAdmin,
    PermissionIds.navCustomers,
    PermissionIds.navMerchandise,
    PermissionIds.navLeaderboard,
    PermissionIds.navLoyalty,
    PermissionIds.opsLoyaltyConvert,
    PermissionIds.navTournaments,
    PermissionIds.opsTableConfigure,
    PermissionIds.opsTableTypesConfigure,
    PermissionIds.opsMembershipTypesConfigure,
    PermissionIds.opsSessionsHistory,
  };

  static Set<String> get cashier => {
    ...staff,
    PermissionIds.navSales,
    PermissionIds.opsRefund,
  };
}
