import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../auth/role_mapping.dart';
import '../auth/workspace_auth_action_settings.dart';
import '../constants/firestore_collections.dart';
import '../constants/register_ops_firebase.dart';
import '../firestore/tenant_firestore.dart';
import 'firebase_init_provider.dart';
import '../models/app_user.dart';
import '../models/company.dart';
import '../models/company_module_visibility.dart';
import '../models/company_role.dart';
import '../models/venue_kind.dart';
import '../services/analytics_service.dart';
import '../services/company_roles_service.dart';
import '../services/google_auth_service.dart';
import '../utils/app_logger.dart';

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authServiceProvider = Provider<AuthService>((ref) {
  ref.watch(firebaseInitProvider);
  final registerAuth = FirebaseAuth.instanceFor(
    app: Firebase.app(kRegisterOpsFirebaseAppName),
  );
  return AuthService(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
    registerAuth,
  );
});

final appUserProvider = StreamProvider<AppUser?>((ref) {
  ref.keepAlive();

  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user != null) {
        final authService = ref.watch(authServiceProvider);
        return authService.getAppUser(user.uid);
      }
      return Stream.value(null);
    },
    loading: () => Stream.value(null),
    error: (error, stackTrace) => Stream.value(null),
  );
});

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  /// Isolated auth instance so [createUserWithEmailAndPassword] does not replace the primary session.
  final FirebaseAuth _registerAuth;

  AuthService(this._firebaseAuth, this._firestore, this._registerAuth);

  /// Self-serve company registration: creates Firebase user, company doc, and admin user profile.
  Future<UserCredential> registerCompany({
    required String companyName,
    required String adminName,
    required String email,
    required String password,
    required VenueKind venueKind,
    String? phoneNumber,
    String? description,
    String? address,
  }) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = userCredential.user!.uid;
    final companyRef = _firestore
        .collection(FirestoreCollections.companies)
        .doc();
    final now = DateTime.now();
    final company = Company(
      id: companyRef.id,
      name: companyName.trim(),
      ownerUid: uid,
      createdAt: now,
      venueKind: venueKind,
      description: description?.trim().isNotEmpty == true ? description!.trim() : null,
      address: address?.trim().isNotEmpty == true ? address!.trim() : null,
      phone: phoneNumber?.trim().isNotEmpty == true ? phoneNumber!.trim() : null,
    );
    final modulePreset = CompanyModuleVisibility.presetFor(venueKind);

    // Commit company + user first. Default roles must run in a second batch:
    // rules use `isCompanyOwner(companyId)` which reads `companies/{id}`, and
    // Firestore does not expose other writes in the same batch to rule checks.
    final batch = _firestore.batch();
    batch.set(companyRef, {
      ...company.toFirestore(),
      'moduleVisibility': modulePreset.toFirestoreMap(),
    });
    batch.set(_firestore.collection(FirestoreCollections.users).doc(uid), {
      'email': email,
      'role': UserRole.admin.toString().split('.').last,
      'roleId': SystemRoleIds.owner,
      'name': adminName.trim(),
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phoneNumber': phoneNumber.trim(),
      'companyId': companyRef.id,
    }, SetOptions(merge: true));
    batch.set(
      _firestore.collection(FirestoreCollections.publicVenues).doc(companyRef.id),
      {
        'displayName': companyName.trim(),
        'venueKind': venueKind.storageName,
        'showOnDiscovery': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    try {
      await batch.commit();
    } catch (e) {
      try {
        await userCredential.user?.delete();
      } catch (_) {}
      rethrow;
    }

    try {
      await userCredential.user?.sendEmailVerification(
        workspaceAuthActionCodeSettings(),
      );
    } catch (e, st) {
      AppLogger.logNonFatalProviderSideEffect(
        'sendEmailVerification after sign-up',
        e,
        st,
        tag: 'AuthService',
      );
    }

    try {
      await AnalyticsService.logWorkspaceSignUp(
        venueKindStorage: venueKind.storageName,
      );
    } catch (e, st) {
      AppLogger.logNonFatalProviderSideEffect(
        'Analytics workspace_sign_up',
        e,
        st,
        tag: 'AuthService',
      );
    }

    try {
      final rolesBatch = _firestore.batch();
      CompanyRolesService.seedDefaultRolesForBatch(
        rolesBatch,
        companyRef.id,
        _firestore,
        modulesForSeed: modulePreset,
      );
      await rolesBatch.commit();
    } catch (e, st) {
      AppLogger.logNonFatalProviderSideEffect(
        'Default roles batch commit failed; falling back to ensureDefaultRoles',
        e,
        st,
        tag: 'AuthService',
      );
      // Transient failures: idempotent re-seed (no-op if roles already exist).
      await CompanyRolesService(
        _firestore,
      ).ensureDefaultRoles(TenantRef(_firestore, companyRef.id));
    }
    // Force a server read so the next Firestore query sees the profile (avoids
    // permission-denied races right after sign-up when rules use users/{uid}).
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    return userCredential;
  }

  /// Creates a staff Firebase Auth user and Firestore profile without signing out the owner.
  Future<void> createStaffAccount(
    String email,
    String password,
    String name,
    String? phoneNumber, {
    required String companyId,
    required String roleId,
  }) async {
    final userCredential = await _registerAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final newUid = userCredential.user!.uid;
    await _registerAuth.signOut();

    final coarse = coarseUserRoleForRoleId(roleId);
    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(newUid)
          .set({
            'email': email,
            'role': coarse.toString().split('.').last,
            'roleId': roleId,
            'name': name,
            if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
              'phoneNumber': phoneNumber.trim(),
            'companyId': companyId,
          });
    } catch (e) {
      AppLogger.error('Staff Firestore profile failed, orphan Auth user $newUid', error: e, tag: 'AuthService');
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final cred = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Force a server read so the user profile stream picks up the latest
    // companyId / roleId immediately instead of stale cache data.
    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(cred.user!.uid)
          .get(const GetOptions(source: Source.server));
    } catch (_) {}
    return cred;
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: workspaceAuthActionCodeSettings(),
    );
  }

  Stream<AppUser?> getAppUser(String uid) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return AppUser.fromMap(snapshot.data()!, snapshot.id);
          }
          return null;
        });
  }

  Future<GoogleAuthResult?> signInWithGoogle() async {
    return GoogleAuthService(_firebaseAuth).signInWithGoogle();
  }

  Future<void> registerCompanyWithGoogle({
    required String companyName,
    required VenueKind venueKind,
    String? description,
    String? address,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No signed-in user for Google registration');

    final uid = user.uid;
    final companyRef = _firestore.collection(FirestoreCollections.companies).doc();
    final company = Company(
      id: companyRef.id,
      name: companyName.trim(),
      ownerUid: uid,
      createdAt: DateTime.now(),
      venueKind: venueKind,
      description: description?.trim().isNotEmpty == true ? description!.trim() : null,
      address: address?.trim().isNotEmpty == true ? address!.trim() : null,
      phone: user.phoneNumber,
    );
    final modulePreset = CompanyModuleVisibility.presetFor(venueKind);

    final batch = _firestore.batch();
    batch.set(companyRef, {
      ...company.toFirestore(),
      'moduleVisibility': modulePreset.toFirestoreMap(),
    });
    batch.set(_firestore.collection(FirestoreCollections.users).doc(uid), {
      'email': user.email ?? '',
      'role': UserRole.admin.toString().split('.').last,
      'roleId': SystemRoleIds.owner,
      'name': user.displayName ?? 'Admin',
      if (user.phoneNumber != null) 'phoneNumber': user.phoneNumber,
      if (user.photoURL != null) 'photoUrl': user.photoURL,
      'companyId': companyRef.id,
    }, SetOptions(merge: true));
    batch.set(
      _firestore.collection(FirestoreCollections.publicVenues).doc(companyRef.id),
      {
        'displayName': companyName.trim(),
        'venueKind': venueKind.storageName,
        'showOnDiscovery': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    try {
      await batch.commit();
    } catch (e) {
      rethrow;
    }

    try {
      final rolesBatch = _firestore.batch();
      CompanyRolesService.seedDefaultRolesForBatch(rolesBatch, companyRef.id, _firestore, modulesForSeed: modulePreset);
      await rolesBatch.commit();
    } catch (e, st) {
      AppLogger.logNonFatalProviderSideEffect('Default roles batch (Google)', e, st, tag: 'AuthService');
      await CompanyRolesService(_firestore).ensureDefaultRoles(TenantRef(_firestore, companyRef.id));
    }

    await _firestore.collection(FirestoreCollections.users).doc(uid).get(const GetOptions(source: Source.server));
  }

  Future<UserCredential> createCustomerAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = userCredential.user!.uid;

    try {
      await _firestore.collection(FirestoreCollections.users).doc(uid).set({
        'email': email,
        'name': name.trim(),
        'role': 'customer',
      });
    } catch (e) {
      try { await userCredential.user?.delete(); } catch (_) {}
      rethrow;
    }

    try {
      await userCredential.user?.sendEmailVerification(
        workspaceAuthActionCodeSettings(),
      );
    } catch (_) {}

    return userCredential;
  }
}
