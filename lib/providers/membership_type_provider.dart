import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore/tenant_firestore.dart';
import '../models/membership_type_definition.dart';
import '../services/membership_type_service.dart';
import '../utils/app_logger.dart';
import '../utils/provider_scheduler_gate.dart';
import 'company_module_provider.dart';
import 'tenant_provider.dart';

final membershipTypeServiceProvider = Provider<MembershipTypeService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return MembershipTypeService(tenant);
});

final membershipTypeDefinitionsProvider =
    StreamProvider<List<MembershipTypeDefinition>>((ref) async* {
      final TenantRef? tenant = ref.watch(tenantRefProvider);
      if (tenant == null) {
        yield [];
        return;
      }
      ref.keepAlive();

      var disposed = false;
      await awaitProviderSchedulerFrame(ref, () => disposed = true);
      if (disposed) return;

      final profile = await ref.watch(companyProfileProvider.future);
      if (disposed) return;

      final service = MembershipTypeService(tenant);
      try {
        await service.ensureDefaultSeedIfEmpty(venueKind: profile.venueKind);
      } catch (e, st) {
        AppLogger.logNonFatalProviderSideEffect(
          'ensureDefaultSeedIfEmpty failed; continuing with membership stream',
          e,
          st,
          tag: 'MembershipTypeProvider',
        );
      }
      if (disposed) return;

      yield* tenant
          .membershipTypeDefinitions()
          .orderBy('sortOrder')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(MembershipTypeDefinition.fromFirestore)
                .toList(),
          );
    });

final activeMembershipTypeDefinitionsProvider =
    Provider<AsyncValue<List<MembershipTypeDefinition>>>((ref) {
      return ref
          .watch(membershipTypeDefinitionsProvider)
          .whenData((all) => all.where((d) => !d.isArchived).toList());
    });
