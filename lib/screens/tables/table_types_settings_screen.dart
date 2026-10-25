import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/company_profile.dart';
import '../../models/table_type_definition.dart';
import '../../models/venue_kind.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/table_type_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/table_type_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_async_error.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

String _tableTypesIntroForProfile(CompanyProfile p) {
  final m = p.modules.forVenueKind(p.venueKind);
  switch (p.venueKind) {
    case VenueKind.gamingCafe:
      if (m.tournaments || m.leaderboard) {
        return 'Names and icons appear on the table grid and dashboard. '
            'The game category links each type to tournaments '
            'and leaderboard / LTP defaults when those modules are on.';
      }
      return 'Names and icons appear on the table grid and dashboard. '
          'Turn on Tournaments or Leaderboard in Settings → Venue modules '
          'if you need per-type game categories.';
    case VenueKind.diningCafe:
      return 'Labels for seating in your dining café: names, icons, and colors '
          'on the table grid and session cards. Game categories and tournaments '
          'apply only to gaming cafés.';
    case VenueKind.restaurantCafe:
      return 'Labels for tables in your restaurant: names, icons, and colors '
          'on the floor and session cards. Game categories and tournaments '
          'apply only to gaming cafés.';
  }
}

class TableTypesSettingsScreen extends ConsumerWidget {
  const TableTypesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final permsAsync = ref.watch(effectivePermissionsProvider);
    final hasTenant =
        user?.companyId != null && user!.companyId!.trim().isNotEmpty;

    if (hasTenant) {
      if (permsAsync.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Table types'), centerTitle: true),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (permsAsync.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Table types'), centerTitle: true),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load access settings.\n'
                '${permsAsync.error}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
    }

    final perms = ref.watchResolvedPermissions();
    final canOpen = perms.canOpenTableTypesSettings();
    final canMutate = perms.canMutateTableTypeDefinitions();
    if (!canOpen) {
      return Scaffold(
        appBar: AppBar(title: const Text('Table types'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              hasTenant
                  ? 'You don’t have permission to open table types. '
                      'Ask the venue owner to grant Tables access or turn on '
                      'the Tables module under Settings → Venue modules.'
                  : 'Sign in with a venue account to manage table types.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final async = ref.watch(tableTypeDefinitionsProvider);
    final service = ref.watch(tableTypeServiceProvider);
    final profileAsync = ref.watch(companyProfileProvider);
    final showGameCategoryForTournaments = profileAsync.maybeWhen(
      data: (p) {
        if (p.venueKind != VenueKind.gamingCafe) return false;
        final m = p.modules.forVenueKind(p.venueKind);
        return m.tournaments || m.leaderboard;
      },
      orElse: () => false,
    );
    final introText = profileAsync.maybeWhen(
      data: _tableTypesIntroForProfile,
      orElse: () =>
          'Names and icons appear on the table grid and dashboard.',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(profileAsync.maybeWhen(
          data: (p) => p.venueKind == VenueKind.gamingCafe ? 'Table types' : p.venueKind == VenueKind.diningCafe ? 'Seating types' : 'Table zones',
          orElse: () => 'Table types',
        )),
        centerTitle: true,
      ),
      body: async.when(
        data: (defs) {
          final visible = List<TableTypeDefinition>.from(defs)
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return ListView(
            padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
                child: Text(
                  introText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (!canMutate) ...[
                const SizedBox(height: AppTheme.kSpacingMedium),
                Text(
                  'View only. To add or edit types you need Configure tables or '
                  'Table types permission, and the Tables module must be enabled '
                  'under Settings → Venue modules. An owner can grant this under '
                  'Settings → Staff & access → Roles.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.kSpacingMedium),
              ...visible.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: d.color.withValues(alpha: 0.15),
                        child: Icon(
                          tableTypeIconFromKey(d.iconKey),
                          color: d.color,
                        ),
                      ),
                      title: Text(d.name),
                      subtitle: Text(
                        showGameCategoryForTournaments
                            ? '${d.id} · ${TableTypeDefinition.gameCategoryDisplayLabel(d.gameCategoryKey)}'
                                '${d.isArchived ? ' · archived' : ''}'
                            : '${d.id}${d.isArchived ? ' · archived' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: !canMutate || service == null
                                ? null
                                : () => _openEditor(
                                    context,
                                    ref,
                                    existing: d,
                                    service: service,
                                    showGameCategory: showGameCategoryForTournaments,
                                  ),
                          ),
                          IconButton(
                            icon: Icon(
                              d.isArchived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                            ),
                            onPressed: !canMutate || service == null
                                ? null
                                : () async {
                                    try {
                                      await service.setArchived(
                                        d.id,
                                        !d.isArchived,
                                      );
                                      if (context.mounted) {
                                        context.showSuccessSnackbar(
                                          d.isArchived
                                              ? 'Type restored'
                                              : 'Type archived (existing tables keep this label)',
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        context.showErrorSnackbar('$e');
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SectionAsyncError(error: e),
      ),
      floatingActionButton: !canMutate || service == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-table-types-settings',
              onPressed: () => _openEditor(
                    context,
                    ref,
                    service: service,
                    showGameCategory: showGameCategoryForTournaments,
                  ),
              icon: const Icon(Icons.add),
              label: const Text('Add type'),
            ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    TableTypeDefinition? existing,
    required TableTypeService? service,
    bool showGameCategory = true,
  }) async {
    if (service == null) return;
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    String iconKey = existing?.iconKey ?? kTableTypeIconChoices.first.$1;
    int colorArgb = existing?.colorArgb ?? 0xFF4CAF50;
    String category = existing?.gameCategoryKey ?? 'other';
    final allDefs = ref.read(tableTypeDefinitionsProvider).valueOrNull ?? [];
    final maxSortOrder = allDefs.isEmpty
        ? -1
        : allDefs
            .map((d) => d.sortOrder)
            .reduce((a, b) => a > b ? a : b);
    final sortOrder = existing?.sortOrder ?? (maxSortOrder + 1);
    final sortCtrl = TextEditingController(text: '$sortOrder');

    final isEditing = existing != null;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final dialogTheme = Theme.of(ctx);
            final cs = dialogTheme.colorScheme;
            return AlertDialog(
              title: Text(isEditing ? 'Edit table type' : 'New table type'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: AppTheme.inputDecoration(
                        dialogTheme,
                        'Display name',
                      ),
                      onChanged: (_) {
                        if (!isEditing && idCtrl.text.trim().isEmpty) {
                          setLocal(() {});
                        }
                      },
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: idCtrl,
                        decoration: AppTheme.inputDecoration(
                          dialogTheme,
                          'Id (optional slug)',
                        ).copyWith(
                          helperText:
                              'Leave blank to generate from the name (a–z, 0–9). '
                              'Non-Latin names: enter an id here or one is auto-generated.',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Builder(
                      builder: (iconCtx) {
                        final iconItems = kTableTypeIconChoices
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e.$1,
                                child: Row(
                                  children: [
                                    Icon(e.$2, size: 20),
                                    const SizedBox(width: 8),
                                    Text(e.$3),
                                  ],
                                ),
                              ),
                            )
                            .toList();
                        final t = Theme.of(iconCtx);
                        return DropdownButtonFormField<String>(
                          key: ValueKey(iconKey),
                          initialValue: iconKey,
                          isExpanded: true,
                          decoration: AppTheme.inputDecoration(t, 'Icon'),
                          items: iconItems,
                          selectedItemBuilder: (context) =>
                              AppTheme.dropdownSelectedItemBuilders(
                                t,
                                iconItems,
                              ),
                          onChanged: (v) =>
                              setLocal(() => iconKey = v ?? iconKey),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Accent color',
                      style: dialogTheme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            0xFF4CAF50,
                            0xFF2196F3,
                            0xFF795548,
                            0xFFF44336,
                            0xFF9C27B0,
                            0xFFFF9800,
                            0xFF009688,
                            0xFF607D8B,
                            0xFFE91E63,
                            0xFF3F51B5,
                          ].map((c) {
                            final selected = colorArgb == c;
                            return InkWell(
                              onTap: () => setLocal(() => colorArgb = c),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? cs.primary
                                        : cs.outline.withValues(alpha: 0.45),
                                    width: selected ? 3 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: Color(
                                              c,
                                            ).withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    if (showGameCategory) ...[
                      const SizedBox(height: 12),
                      Builder(
                        builder: (catCtx) {
                          final categoryItems =
                              TableTypeDefinition.orderedGameCategoryKeys
                                  .map(
                                    (k) => DropdownMenuItem<String>(
                                      value: k,
                                      child: Text(
                                        TableTypeDefinition
                                            .gameCategoryDisplayLabel(k),
                                      ),
                                    ),
                                  )
                                  .toList();
                          final t = Theme.of(catCtx);
                          return DropdownButtonFormField<String>(
                            key: ValueKey(category),
                            initialValue:
                                TableTypeDefinition.normalizeGameCategoryKey(
                              category,
                            ),
                            isExpanded: true,
                            decoration: AppTheme.inputDecoration(
                              t,
                              'Game category (tournaments & leaderboard)',
                            ),
                            items: categoryItems,
                            selectedItemBuilder: (context) =>
                                AppTheme.dropdownSelectedItemBuilders(
                                  t,
                                  categoryItems,
                                ),
                            onChanged: (v) =>
                                setLocal(() => category = v ?? category),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      decoration: AppTheme.inputDecoration(
                        dialogTheme,
                        'Sort order',
                      ),
                      keyboardType: TextInputType.number,
                      controller: sortCtrl,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(AppStrings.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      if (ctx.mounted) {
                        context.showErrorSnackbar('Enter a name');
                      }
                      return;
                    }
                    var id = isEditing ? existing.id : idCtrl.text.trim();
                    if (!isEditing) {
                      if (id.isEmpty) {
                        id = name;
                      }
                      id = id.toLowerCase().replaceAll(
                        RegExp(r'[^a-z0-9_]+'),
                        '_',
                      );
                      id = id.replaceAll(RegExp(r'_+'), '_');
                      id = id.replaceAll(RegExp(r'^_|_$'), '');
                      if (id.isEmpty) {
                        id =
                            'type_${DateTime.now().millisecondsSinceEpoch}';
                      }
                    }
                    if (id.isEmpty) {
                      if (ctx.mounted) {
                        context.showErrorSnackbar(
                          'Enter a display name (id is generated from it if left blank).',
                        );
                      }
                      return;
                    }
                    if (!isEditing) {
                      try {
                        final exists = await tenant
                            .tableTypeDefinitions()
                            .doc(id)
                            .get();
                        if (exists.exists && ctx.mounted) {
                          context.showErrorSnackbar(
                            'That id is already in use. Pick another.',
                          );
                          return;
                        }
                      } catch (e) {
                        if (context.mounted) {
                          context.showErrorSnackbar(
                            SnackbarHelper.messageForFirestoreMutationFailure(
                              e,
                            ),
                          );
                        }
                        return;
                      }
                    }

                    final parsedOrder = int.tryParse(sortCtrl.text.trim());
                    final resolvedCategory = showGameCategory
                        ? TableTypeDefinition.normalizeGameCategoryKey(category)
                        : TableTypeDefinition.normalizeGameCategoryKey(
                            existing?.gameCategoryKey ?? 'other',
                          );
                    final def = TableTypeDefinition(
                      id: id,
                      name: name,
                      iconKey: iconKey,
                      colorArgb: colorArgb,
                      sortOrder: parsedOrder ?? sortOrder,
                      isArchived: existing?.isArchived ?? false,
                      gameCategoryKey: resolvedCategory,
                    );
                    try {
                      if (isEditing) {
                        await service.update(def);
                      } else {
                        await service.createWithId(id, def);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        context.showSuccessSnackbar(
                          isEditing ? 'Type updated' : 'Type created',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        context.showErrorSnackbar(
                          SnackbarHelper.messageForFirestoreMutationFailure(e),
                        );
                      }
                    }
                  },
                  child: const Text(AppStrings.save),
                ),
              ],
            );
          },
        );
      },
    );

    void disposeCtrls() {
      nameCtrl.dispose();
      idCtrl.dispose();
      sortCtrl.dispose();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => disposeCtrls());
  }
}
