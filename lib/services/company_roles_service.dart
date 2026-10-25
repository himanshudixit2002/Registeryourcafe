import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_collections.dart';
import '../firestore/tenant_firestore.dart';
import '../auth/permission_id.dart';
import '../models/company_profile.dart';
import '../models/company_module_visibility.dart';
import '../models/company_role.dart';
import '../utils/app_logger.dart';

/// Seeds and streams company role documents.
class CompanyRolesService {
  CompanyRolesService(this._db);

  final FirebaseFirestore _db;

  /// Writes default system roles into [batch] for a new company.
  ///
  /// [modulesForSeed] caps manager/staff/cashier templates to match venue modules
  /// (see [CompanyModuleVisibility.presetFor]); owner always gets the full catalog.
  static void seedDefaultRolesForBatch(
    WriteBatch batch,
    String companyId,
    FirebaseFirestore db, {
    CompanyModuleVisibility? modulesForSeed,
  }) {
    final modules = modulesForSeed ?? CompanyModuleVisibility.defaults;
    final base = db.collection(FirestoreCollections.companies).doc(companyId);
    void setRole(
      String id,
      String name,
      String description,
      Set<String> perms,
    ) {
      batch.set(base.collection(FirestoreCollections.permissionRoles).doc(id), {
        'name': name,
        'description': description,
        'permissionIds': perms.toList()..sort(),
        'isSystem': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    setRole(
      SystemRoleIds.owner,
      'Owner',
      'Full access to all modules and settings.',
      DefaultRolePermissions.owner,
    );
    setRole(
      SystemRoleIds.manager,
      'Manager',
      'Broad access; cannot edit role definitions.',
      CompanyModuleVisibility.filterPermissionIdsForModules(
        DefaultRolePermissions.manager.toSet(),
        modules,
      ),
    );
    setRole(
      SystemRoleIds.staff,
      'Staff',
      'Day-to-day floor and service; no analytics or refunds by default.',
      CompanyModuleVisibility.filterPermissionIdsForModules(
        DefaultRolePermissions.staff,
        modules,
      ),
    );
    setRole(
      SystemRoleIds.cashier,
      'Cashier',
      'Staff plus sales and refunds.',
      CompanyModuleVisibility.filterPermissionIdsForModules(
        DefaultRolePermissions.cashier,
        modules,
      ),
    );
  }

  /// Idempotent: creates default roles only if the owner role doc is missing.
  Future<void> ensureDefaultRoles(TenantRef tenant) async {
    final ownerRef = tenant.permissionRoles().doc(SystemRoleIds.owner);
    final snap = await ownerRef.get();
    if (snap.exists) return;

    final companySnap = await tenant.companyDoc().get();
    final modules =
        CompanyProfile.fromFirestoreData(companySnap.data()).modules;

    final batch = _db.batch();
    seedDefaultRolesForBatch(
      batch,
      tenant.companyId,
      _db,
      modulesForSeed: modules,
    );
    await batch.commit();
  }

  /// Creates any missing built-in role documents (`owner`, `manager`, `staff`,
  /// `cashier`). [ensureDefaultRoles] only runs when the **owner** doc is absent;
  /// this repairs tenants where the owner doc exists but other system roles were
  /// never written or were deleted.
  ///
  /// Callers must only invoke this when Firestore rules allow `permissionRoles`
  /// writes (registered company owner).
  Future<void> ensureMissingSystemRoleDocuments(TenantRef tenant) async {
    final companySnap = await tenant.companyDoc().get();
    if (!companySnap.exists) return;
    final profile = CompanyProfile.fromFirestoreData(companySnap.data());
    final modules = profile.modules.forVenueKind(profile.venueKind);

    Future<void> createIfMissing(
      String roleId,
      String name,
      String description,
      Set<String> fullTemplate, {
      required bool filterByModules,
    }) async {
      final ref = tenant.permissionRoles().doc(roleId);
      final snap = await ref.get();
      if (snap.exists) return;
      final Set<String> perms = !filterByModules
          ? fullTemplate
          : CompanyModuleVisibility.filterPermissionIdsForModules(
              fullTemplate,
              modules,
            );
      await ref.set({
        'name': name,
        'description': description,
        'permissionIds': perms.toList()..sort(),
        'isSystem': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await createIfMissing(
      SystemRoleIds.owner,
      'Owner',
      'Full access to all modules and settings.',
      DefaultRolePermissions.owner,
      filterByModules: false,
    );
    await createIfMissing(
      SystemRoleIds.manager,
      'Manager',
      'Broad access; cannot edit role definitions.',
      DefaultRolePermissions.manager,
      filterByModules: true,
    );
    await createIfMissing(
      SystemRoleIds.staff,
      'Staff',
      'Day-to-day floor and service; no analytics or refunds by default.',
      DefaultRolePermissions.staff,
      filterByModules: true,
    );
    await createIfMissing(
      SystemRoleIds.cashier,
      'Cashier',
      'Staff plus sales and refunds.',
      DefaultRolePermissions.cashier,
      filterByModules: true,
    );
  }

  /// Merges module-aware baselines into manager/staff/cashier so enabling
  /// workspace modules later does not leave stale [permissionIds] from
  /// initial registration.
  ///
  /// Only updates existing docs with [CompanyRole.isSystem] true. Owner is
  /// not modified.
  Future<void> syncSystemRolesWithModuleBaseline(TenantRef tenant) async {
    final companySnap = await tenant.companyDoc().get();
    if (!companySnap.exists) return;
    final profile = CompanyProfile.fromFirestoreData(companySnap.data());
    final modules = profile.modules.forVenueKind(profile.venueKind);

    Future<void> syncOne(String roleId, Set<String> templateFullSet) async {
      final docRef = tenant.permissionRoles().doc(roleId);
      final snap = await docRef.get();
      if (!snap.exists) return;
      final role = CompanyRole.fromFirestore(snap);
      if (!role.isSystem) return;
      final baseline =
          CompanyModuleVisibility.filterPermissionIdsForModules(
        templateFullSet,
        modules,
      );
      final current = role.permissionIds.toSet();
      if (baseline.every(current.contains)) return;
      final merged = {...current, ...baseline};
      await docRef.update({
        'permissionIds': merged.toList()..sort(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await syncOne(SystemRoleIds.manager, DefaultRolePermissions.manager);
    await syncOne(SystemRoleIds.staff, DefaultRolePermissions.staff);
    await syncOne(SystemRoleIds.cashier, DefaultRolePermissions.cashier);
  }

  /// Fills `permissionIds` when a system role doc exists but lists none.
  ///
  /// Matches seeded templates (module-filtered for manager/staff/cashier; full
  /// catalog for owner). Without this, Firestore rules deny guarded writes while
  /// the client used to infer defaults only in memory.
  Future<void> repairEmptySystemRolePermissionIds(TenantRef tenant) async {
    final companySnap = await tenant.companyDoc().get();
    if (!companySnap.exists) return;
    final profile = CompanyProfile.fromFirestoreData(companySnap.data());
    final modules = profile.modules.forVenueKind(profile.venueKind);

    Future<void> repairOne(String roleId, Set<String> fullTemplate) async {
      final ref = tenant.permissionRoles().doc(roleId);
      final snap = await ref.get();
      if (!snap.exists) return;
      final role = CompanyRole.fromFirestore(snap);
      if (!role.isSystem) return;
      if (role.permissionIds.isNotEmpty) return;

      final Set<String> replacement;
      if (roleId == SystemRoleIds.owner) {
        replacement = fullTemplate;
      } else {
        replacement = CompanyModuleVisibility.filterPermissionIdsForModules(
          fullTemplate,
          modules,
        );
      }
      await ref.update({
        'permissionIds': replacement.toList()..sort(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await repairOne(SystemRoleIds.owner, DefaultRolePermissions.owner);
    await repairOne(SystemRoleIds.manager, DefaultRolePermissions.manager);
    await repairOne(SystemRoleIds.staff, DefaultRolePermissions.staff);
    await repairOne(SystemRoleIds.cashier, DefaultRolePermissions.cashier);
  }

  /// Adds [PermissionIds.opsLoyaltyConvert] to seeded system roles that already
  /// have loyalty navigation so existing tenants keep convert after the
  /// permission split (custom roles unchanged).
  /// Adds Firestore permission ids that the client already synthesizes via
  /// [_effectivePermissionIdsForRole] so rules checks match saved role docs.
  ///
  /// Only updates documents that are missing the paired ops (idempotent).
  Future<void> ensureNavPairedOpsInPermissionRoles(TenantRef tenant) async {
    final snap = await tenant.permissionRoles().get();
    for (final doc in snap.docs) {
      final role = CompanyRole.fromFirestore(doc);
      final ids = role.permissionIds.toSet();
      var changed = false;
      if (ids.contains(PermissionIds.navTables)) {
        if (ids.add(PermissionIds.opsTableConfigure)) changed = true;
        if (ids.add(PermissionIds.opsTableTypesConfigure)) changed = true;
      } else if (ids.contains(PermissionIds.opsTableConfigure)) {
        if (ids.add(PermissionIds.opsTableTypesConfigure)) changed = true;
      }
      if (ids.contains(PermissionIds.navCustomers)) {
        if (ids.add(PermissionIds.opsMembershipTypesConfigure)) changed = true;
      }
      if (!changed) continue;
      try {
        await doc.reference.update({
          'permissionIds': ids.toList()..sort(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e, st) {
        AppLogger.logNonFatalProviderSideEffect(
          'ensureNavPairedOpsInPermissionRoles ${doc.id}',
          e,
          st,
          tag: 'CompanyRolesService',
        );
      }
    }
  }

  Future<void> ensureLoyaltyConvertOnLegacySystemRoles(TenantRef tenant) async {
    for (final id in [
      SystemRoleIds.staff,
      SystemRoleIds.cashier,
      SystemRoleIds.manager,
    ]) {
      final ref = tenant.permissionRoles().doc(id);
      final snap = await ref.get();
      if (!snap.exists) continue;
      final role = CompanyRole.fromFirestore(snap);
      if (!role.isSystem) continue;
      final ids = role.permissionIds.toSet();
      if (!ids.contains(PermissionIds.navLoyalty)) continue;
      if (ids.contains(PermissionIds.opsLoyaltyConvert)) continue;
      await ref.update({
        'permissionIds': FieldValue.arrayUnion([PermissionIds.opsLoyaltyConvert]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<List<CompanyRole>> rolesStream(TenantRef tenant) {
    return tenant.permissionRoles().snapshots().map(
      (s) => s.docs.map(CompanyRole.fromFirestore).toList()
        ..sort((a, b) {
          if (a.isSystem != b.isSystem) return a.isSystem ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }),
    );
  }

  Future<void> saveRole(TenantRef tenant, CompanyRole role) async {
    await tenant
        .permissionRoles()
        .doc(role.id)
        .set(role.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteRole(TenantRef tenant, CompanyRole role) async {
    if (role.isSystem) {
      throw StateError('System roles cannot be deleted');
    }
    await tenant.permissionRoles().doc(role.id).delete();
  }

  /// Copy permissions into a new non-system role.
  Future<String> duplicateRole(TenantRef tenant, CompanyRole source) async {
    final newId = tenant.permissionRoles().doc().id;
    final copy = CompanyRole(
      id: newId,
      name: '${source.name} (copy)',
      description: source.description,
      permissionIds: List<String>.from(source.permissionIds),
      isSystem: false,
    );
    await tenant.permissionRoles().doc(newId).set(copy.toFirestore());
    return newId;
  }
}
