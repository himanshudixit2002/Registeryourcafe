import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore/tenant_firestore.dart';
import '../models/company_module_visibility.dart';
import '../models/company_profile.dart';
import '../models/venue_kind.dart';
import 'tenant_provider.dart';

/// Full company document snapshot (venue kind + module visibility).
final companyProfileProvider = StreamProvider<CompanyProfile>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(CompanyProfile.fallback());
  }

  return tenant.companyDoc().snapshots().map((snap) {
    if (!snap.exists) return CompanyProfile.fallback();
    return CompanyProfile.fromFirestoreData(snap.data());
  });
});

final companyModuleVisibilityProvider =
    Provider<AsyncValue<CompanyModuleVisibility>>((ref) {
      return ref
          .watch(companyProfileProvider)
          .when(
            data: (p) => AsyncValue.data(p.modules),
            loading: () => const AsyncValue.loading(),
            error: (e, st) => AsyncValue.error(e, st),
          );
    });

/// [VenueKind] with load/error state — prefer this when assuming gaming during
/// [AsyncLoading] would be wrong for a signed-in tenant.
final venueKindAsyncProvider = Provider<AsyncValue<VenueKind>>((ref) {
  return ref.watch(companyProfileProvider).when(
    data: (p) => AsyncValue.data(p.venueKind),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Resolved kind when available; falls back to [VenueKind.gamingCafe] only when
/// there is no tenant (pre-auth) or data is not yet loaded.
final venueKindProvider = Provider<VenueKind>((ref) {
  return ref.watch(companyProfileProvider).valueOrNull?.venueKind ??
      VenueKind.gamingCafe;
});

/// [CompanyModuleVisibility] after [CompanyModuleVisibility.forVenueKind]:
/// gaming-only modules are off for dining / restaurant venues. Use for shell
/// tabs, dashboard sections, permission filtering, and session UX — not for the
/// raw module toggle list in Settings (that uses [companyModuleVisibilityProvider]).
final workspaceModuleVisibilityProvider =
    Provider<CompanyModuleVisibility>((ref) {
  return ref.watch(companyProfileProvider).maybeWhen(
        data: (p) => p.modules.forVenueKind(p.venueKind),
        orElse: () => CompanyModuleVisibility.defaults,
      );
});

/// Saves `moduleVisibility` on the company document (merge).
Future<void> saveCompanyModuleVisibility(
  TenantRef tenant,
  CompanyModuleVisibility visibility,
) async {
  await tenant.companyDoc().set({
    'moduleVisibility': visibility.toFirestoreMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
