import 'permission_id.dart';

/// Resolved permission set for the signed-in user in the current company.
class EffectivePermissions {
  EffectivePermissions(Set<String> ids) : _ids = Set.unmodifiable(ids);

  /// Full access (company owner bypass or `owner` system role).
  EffectivePermissions.all() : _ids = Set.unmodifiable(PermissionIds.all);

  final Set<String> _ids;

  Set<String> get rawIds => _ids;

  bool can(String permissionId) => _ids.contains(permissionId);

  bool canAny(Iterable<String> permissionIds) =>
      permissionIds.any(_ids.contains);
}

/// Feature-level gates: “open” screens vs “mutate” configuration.
extension EffectivePermissionsFeatureAccess on EffectivePermissions {
  bool canOpenTableSettingsScreens() =>
      can(PermissionIds.navTables) || can(PermissionIds.opsTableConfigure);

  /// Table types settings (and hub link) — includes narrow configure permission.
  bool canOpenTableTypesSettings() =>
      can(PermissionIds.navTables) ||
      can(PermissionIds.opsTableConfigure) ||
      can(PermissionIds.opsTableTypesConfigure);

  bool canMutateTableConfiguration() => can(PermissionIds.opsTableConfigure);

  bool canMutateTableTypeDefinitions() =>
      can(PermissionIds.opsTableConfigure) ||
      can(PermissionIds.opsTableTypesConfigure);

  bool canOpenMembershipTypesSettings() =>
      can(PermissionIds.navCustomers) ||
      can(PermissionIds.opsCustomersAdmin) ||
      can(PermissionIds.opsMembershipTypesConfigure);

  bool canMutateMembershipTypeDefinitions() =>
      can(PermissionIds.opsCustomersAdmin) ||
      can(PermissionIds.opsMembershipTypesConfigure);

  bool canConfigureLoyaltySettings() =>
      can(PermissionIds.opsLoyaltyConfigure);

  /// Convert points → credits (settings editors may always convert).
  bool canConvertLoyaltyPoints() =>
      can(PermissionIds.opsLoyaltyConvert) ||
      can(PermissionIds.opsLoyaltyConfigure);

  bool canManageLeaderboardConfig() =>
      can(PermissionIds.opsLeaderboardManage);

  bool canManageTournamentConfig() =>
      can(PermissionIds.opsTournamentManage);

  /// Public discovery listing, public menu editor, module toggles.
  bool canConfigurePublicVenueModules() =>
      can(PermissionIds.settingsModules);
}
