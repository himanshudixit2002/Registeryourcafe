import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore/tenant_firestore.dart';
import '../models/table_type_definition.dart';
import '../services/table_type_service.dart';
import '../utils/app_logger.dart';
import '../utils/provider_scheduler_gate.dart';
import 'company_module_provider.dart';
import 'tenant_provider.dart';

final tableTypeServiceProvider = Provider<TableTypeService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return TableTypeService(tenant);
});

/// All definitions (including archived) for resolving labels on existing tables.
final tableTypeDefinitionsProvider = StreamProvider<List<TableTypeDefinition>>((
  ref,
) async* {
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

  final service = TableTypeService(tenant);
  try {
    await service.ensureDefaultSeedIfEmpty(venueKind: profile.venueKind);
  } catch (e, st) {
    AppLogger.logNonFatalProviderSideEffect(
      'ensureDefaultSeedIfEmpty failed; continuing with table type stream',
      e,
      st,
      tag: 'TableTypeProvider',
    );
  }
  if (disposed) return;
  try {
    await service.migrateGamingSeedTableTypesIfNeeded(
      venueKind: profile.venueKind,
    );
  } catch (e, st) {
    AppLogger.logNonFatalProviderSideEffect(
      'migrateGamingSeedTableTypesIfNeeded failed; continuing with stream',
      e,
      st,
      tag: 'TableTypeProvider',
    );
  }
  if (disposed) return;

  yield* tenant
      .tableTypeDefinitions()
      .orderBy('sortOrder')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(TableTypeDefinition.fromFirestore).toList(),
      );
});

/// Pickers (add/edit table) should use non-archived types only.
final activeTableTypeDefinitionsProvider =
    Provider<AsyncValue<List<TableTypeDefinition>>>((ref) {
      return ref
          .watch(tableTypeDefinitionsProvider)
          .whenData((all) => all.where((d) => !d.isArchived).toList());
    });
