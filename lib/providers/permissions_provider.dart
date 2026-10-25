import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../auth/effective_permissions.dart';

import '../auth/effective_permissions.dart';
import '../auth/permission_id.dart';
import '../firestore/tenant_firestore.dart';
import '../models/app_user.dart';
import '../models/company_module_visibility.dart';
import '../models/company_profile.dart';
import '../models/company_role.dart';
import '../services/company_roles_service.dart';
import '../utils/app_logger.dart';
import '../utils/firestore_utils.dart';
import 'auth_provider.dart';

Set<String> _defaultPermissionSetForRoleId(String roleId) {
  switch (roleId) {
    case SystemRoleIds.owner:
      return DefaultRolePermissions.owner;
    case SystemRoleIds.manager:
      return DefaultRolePermissions.manager;
    case SystemRoleIds.cashier:
      return DefaultRolePermissions.cashier;
    case SystemRoleIds.staff:
      return DefaultRolePermissions.staff;
    default:
      return DefaultRolePermissions.staff;
  }
}

/// Firestore rules only grant access from stored `permissionIds`; they do not
/// infer defaults for custom role ids. Match that here so the UI does not show
/// actions that the server will deny.
bool _isBuiltInSystemRoleId(String roleId) {
  return roleId == SystemRoleIds.owner ||
      roleId == SystemRoleIds.manager ||
      roleId == SystemRoleIds.cashier ||
      roleId == SystemRoleIds.staff;
}

/// Resolves permission ids from Firestore; ensures roles that include
/// [PermissionIds.navTables] also get [PermissionIds.opsTableConfigure] and
/// [PermissionIds.opsTableTypesConfigure].
///
/// Firestore rules require matching `permissionIds` on
/// `companies/{cid}/permissionRoles/{roleId}` for writes to `table_type_definitions`
/// and `membership_type_definitions`. The client also pairs nav modules with
/// narrow ops here so UI matches rules; [CompanyRolesService.ensureNavPairedOpsInPermissionRoles]
/// backfills older role documents (owner-signed-in bootstrap).
Set<String> _effectivePermissionIdsForRole(CompanyRole role, String roleDocId) {
  late Set<String> ids;
  if (role.permissionIds.isNotEmpty) {
    ids = role.permissionIds.toSet();
  } else if (_isBuiltInSystemRoleId(roleDocId)) {
    ids = _defaultPermissionSetForRoleId(roleDocId).toSet();
  } else {
    ids = {};
  }
  if (ids.contains(PermissionIds.navTables)) {
    ids = {
      ...ids,
      PermissionIds.opsTableConfigure,
      PermissionIds.opsTableTypesConfigure,
    };
  } else if (ids.contains(PermissionIds.opsTableConfigure)) {
    ids = {...ids, PermissionIds.opsTableTypesConfigure};
  }
  if (ids.contains(PermissionIds.navCustomers)) {
    ids = {...ids, PermissionIds.opsMembershipTypesConfigure};
  }
  return ids;
}

EffectivePermissions _capPermissionsForModules(
  EffectivePermissions permissions,
  CompanyModuleVisibility modules,
) {
  return EffectivePermissions(
    CompanyModuleVisibility.filterPermissionIdsForModules(
      permissions.rawIds,
      modules,
    ),
  );
}

/// Hides nav/ops for disabled modules (see [CompanyModuleVisibility]).
///
/// **Owner** (via [isRegisteredCompanyOwner]) and **system owner/manager** roles
/// skip this cap: they are venue admins and must still reach Settings → table
/// types / membership plans to configure the workspace even when a module is
/// toggled off (shell tabs stay hidden via [EffectivePermissionsNav.canSeeShellRoute]).
/// Firestore rules continue to gate writes by [userHasPermission].
EffectivePermissions _capPermissionsForRoleAndModules(
  EffectivePermissions permissions,
  CompanyModuleVisibility modules,
  String roleDocId,
) {
  if (roleDocId == SystemRoleIds.owner || roleDocId == SystemRoleIds.manager) {
    return permissions;
  }
  return _capPermissionsForModules(permissions, modules);
}

/// While [effectivePermissionsProvider] is still loading, avoid treating the user
/// as permission-empty (which hid add/edit on Settings screens with no clear error).
/// Owners and managers get full access during loading to prevent the post-registration
/// permission-denied race where the permissionRoles doc hasn't been seeded yet.
EffectivePermissions _permissionsWhileTenantStreamLoading(AppUser user) {
  final rid = user.resolvedRoleId;
  if (rid == SystemRoleIds.owner || rid == SystemRoleIds.manager) {
    return EffectivePermissions.all();
  }
  return EffectivePermissions(
    _effectivePermissionIdsForRole(
      CompanyRole(
        id: rid,
        name: rid,
        permissionIds: const [],
      ),
      rid,
    ),
  );
}

final companyRolesServiceProvider = Provider<CompanyRolesService>((ref) {
  return CompanyRolesService(FirebaseFirestore.instance);
});

/// True when [ownerUidFromDoc] matches the signed-in user (trimmed).
bool isRegisteredCompanyOwner(String? ownerUidFromDoc, String userUid) {
  final o = ownerUidFromDoc?.trim();
  final u = userUid.trim();
  return o != null && o.isNotEmpty && o == u;
}

/// Idempotent role seed after sign-in (older tenants / failed registration batches).
///
/// **Only the registered company owner** may write `permissionRoles/*` (see
/// Firestore rules); non-owners skip this entirely to avoid permission-denied
/// noise. Staff/manager rely on the venue owner signing in at least once so
/// system role documents exist and stay in sync.
final companyRolesBootstrapProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(appUserProvider).valueOrNull;
  final cid = user?.companyId;
  if (cid == null || cid.isEmpty || user == null) return;
  final tenant = TenantRef(FirebaseFirestore.instance, cid);
  try {
    final companySnap = await tenant.companyDoc().get();
    final ownerUid = parseFirestoreStringOrNull(
      companySnap.data()?['ownerUid'],
    );
    if (!isRegisteredCompanyOwner(ownerUid, user.uid)) {
      return;
    }
    final svc = ref.read(companyRolesServiceProvider);
    await svc.ensureDefaultRoles(tenant);
    await svc.ensureMissingSystemRoleDocuments(tenant);
    await svc.syncSystemRolesWithModuleBaseline(tenant);
    await svc.repairEmptySystemRolePermissionIds(tenant);
    await svc.ensureLoyaltyConvertOnLegacySystemRoles(tenant);
    await svc.ensureNavPairedOpsInPermissionRoles(tenant);
  } catch (e, st) {
    AppLogger.logNonFatalProviderSideEffect(
      'companyRolesBootstrapProvider',
      e,
      st,
      tag: 'Permissions',
    );
  }
});

/// Resolved permissions for the signed-in user (owner bypass = full catalog).
final effectivePermissionsProvider = StreamProvider<EffectivePermissions?>((
  ref,
) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null || user.companyId == null || user.companyId!.isEmpty) {
    return Stream.value(null);
  }

  final tenant = TenantRef(FirebaseFirestore.instance, user.companyId!);
  final rid = user.resolvedRoleId;

  return tenant.companyDoc().snapshots().asyncExpand((companySnap) {
    final profile = CompanyProfile.fromFirestoreData(companySnap.data());
    final modules = profile.modules.forVenueKind(profile.venueKind);
    final ownerUid = parseFirestoreStringOrNull(
      companySnap.data()?['ownerUid'],
    );
    if (isRegisteredCompanyOwner(ownerUid, user.uid)) {
      // Owners keep the full catalog. Module toggles still hide shell tabs via
      // [isShellTitleVisible]; capping here blocked Settings → table types /
      // membership when Tables or Customers modules were off.
      return Stream.value(EffectivePermissions.all());
    }
    return tenant.permissionRoles().doc(rid).snapshots().map((roleSnap) {
      if (!roleSnap.exists) {
        AppLogger.warning(
          'permissionRoles/$rid does not exist for company ${user.companyId}. '
          'The venue owner must sign in to seed role documents. '
          'Using default permissions for built-in role "$rid".',
          tag: 'Permissions',
        );
        final fallbackRole = CompanyRole(
          id: rid,
          name: rid,
          permissionIds: const [],
        );
        return _capPermissionsForRoleAndModules(
          EffectivePermissions(
            _effectivePermissionIdsForRole(fallbackRole, rid),
          ),
          modules,
          rid,
        );
      }
      final role = CompanyRole.fromFirestore(roleSnap);
      return _capPermissionsForRoleAndModules(
        EffectivePermissions(_effectivePermissionIdsForRole(role, rid)),
        modules,
        rid,
      );
    });
  });
});

extension EffectivePermissionsNav on EffectivePermissions {
  /// Shell route visibility: company module flag plus nav permission (if any).
  bool canSeeShellRoute(CompanyModuleVisibility modules, String title) {
    if (!modules.isEnabledForNavTitle(title)) return false;
    final nav = PermissionIds.navPermissionForShellTitle(title);
    if (nav == null) return true;
    return can(nav);
  }
}

/// Resolves permissions for UI gating.
///
/// When the user belongs to a tenant ([AppUser.companyId] set), do **not** use
/// [_legacyEffectivePermissions] during load/error: that could show Table Types
/// and other screens while Firestore still denies reads (rules use `companyAccess` only, not role ids).
EffectivePermissions resolvedEffectivePermissions(
  AsyncValue<EffectivePermissions?> async,
  AppUser? user,
) {
  final hasTenant =
      user?.companyId != null && user!.companyId!.trim().isNotEmpty;

  if (hasTenant) {
    return async.maybeWhen(
      data: (p) => p ?? _permissionsWhileTenantStreamLoading(user),
      orElse: () => _permissionsWhileTenantStreamLoading(user),
    );
  }

  return async.maybeWhen(
    data: (p) => p ?? _legacyEffectivePermissions(user),
    orElse: () => _legacyEffectivePermissions(user),
  );
}

EffectivePermissions _legacyEffectivePermissions(AppUser? user) {
  if (user?.role == UserRole.admin) {
    return EffectivePermissions.all();
  }
  return EffectivePermissions(DefaultRolePermissions.staff.toSet());
}

extension RefResolvedPermissions on Ref {
  /// Combines [effectivePermissionsProvider] with legacy role fallback while loading.
  EffectivePermissions watchResolvedPermissions() {
    return resolvedEffectivePermissions(
      watch(effectivePermissionsProvider),
      watch(appUserProvider).valueOrNull,
    );
  }

  EffectivePermissions readResolvedPermissions() {
    return resolvedEffectivePermissions(
      read(effectivePermissionsProvider),
      read(appUserProvider).valueOrNull,
    );
  }
}

/// [WidgetRef] does not implement [Ref] in flutter_riverpod 2.x; mirror the helpers here.
extension WidgetRefResolvedPermissions on WidgetRef {
  EffectivePermissions watchResolvedPermissions() {
    return resolvedEffectivePermissions(
      watch(effectivePermissionsProvider),
      watch(appUserProvider).valueOrNull,
    );
  }

  EffectivePermissions readResolvedPermissions() {
    return resolvedEffectivePermissions(
      read(effectivePermissionsProvider),
      read(appUserProvider).valueOrNull,
    );
  }
}
