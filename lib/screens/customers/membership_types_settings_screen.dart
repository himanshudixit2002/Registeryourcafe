import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/company_profile.dart';
import '../../models/membership_type_definition.dart';
import '../../models/venue_kind.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/membership_type_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/membership_type_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_async_error.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

String _membershipPlansIntroForProfile(CompanyProfile p) {
  switch (p.venueKind) {
    case VenueKind.gamingCafe:
      return 'Plans appear when adding customers and upgrading membership. '
          'Fees and credits suit prepaid play time; ID prefix drives card numbers '
          '(e.g. BRONZE1-001). The walk-in tier cannot be deleted.';
    case VenueKind.diningCafe:
      return 'Plans appear when adding guests and upgrading membership. '
          'Credits can cover tabs or prepaid balances; tune tiers for your dining café. '
          'ID prefix drives card numbers. The walk-in tier cannot be deleted.';
    case VenueKind.restaurantCafe:
      return 'Plans appear when adding guests and upgrading membership. '
          'Credits can cover dining or prepaid house accounts; adjust fees and discounts here. '
          'ID prefix drives card numbers. The walk-in tier cannot be deleted.';
  }
}

/// Tenant-configurable membership plans (fee, credits, card ID prefix, etc.).
class MembershipTypesSettingsScreen extends ConsumerWidget {
  const MembershipTypesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final permsAsync = ref.watch(effectivePermissionsProvider);
    final hasTenant =
        user?.companyId != null && user!.companyId!.trim().isNotEmpty;

    if (hasTenant) {
      if (permsAsync.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Membership plans'), centerTitle: true),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (permsAsync.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Membership plans'), centerTitle: true),
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
    final canOpen = perms.canOpenMembershipTypesSettings();
    final canMutate = perms.canMutateMembershipTypeDefinitions();
    if (!canOpen) {
      return Scaffold(
        appBar: AppBar(title: const Text('Membership plans'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              hasTenant
                  ? 'You don’t have permission to open membership plans. '
                      'Ask the venue owner to grant Customers access or turn on '
                      'the Customers module under Settings → Venue modules.'
                  : 'Sign in with a venue account to manage membership plans.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final async = ref.watch(membershipTypeDefinitionsProvider);
    final service = ref.watch(membershipTypeServiceProvider);
    final profileAsync = ref.watch(companyProfileProvider);
    final introText = profileAsync.maybeWhen(
      data: _membershipPlansIntroForProfile,
      orElse: () =>
          'Plans appear when adding customers and upgrading membership. '
          'ID prefix drives card numbers (e.g. BRONZE1-001). '
          'The walk-in tier cannot be deleted.',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Membership plans'), centerTitle: true),
      body: async.when(
        data: (defs) {
          final visible = List<MembershipTypeDefinition>.from(defs)
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return ListView(
            physics: AppTheme.scrollPhysicsFor(context),
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
                  'View only. To add or edit plans you need Customers admin or '
                  'Membership plans permission, and the Customers module must be '
                  'enabled under Settings → Venue modules. An owner can grant this '
                  'under Settings → Staff & access → Roles.',
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
                          d.isRegular
                              ? Icons.person_outline_rounded
                              : Icons.workspace_premium_rounded,
                          color: d.color,
                        ),
                      ),
                      title: Text(d.name),
                      subtitle: Text(
                        '${d.id}'
                        '${d.isRegular ? ' · walk-in' : ' · ${d.fee} → ${d.creditsToAdd} cr'}'
                        '${d.isArchived ? ' · archived' : ''}',
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
                                  ),
                          ),
                          if (!d.isRegular)
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
                                                ? 'Plan restored'
                                                : 'Plan archived (existing customers keep this tier)',
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
              heroTag: 'fab-membership-types-settings',
              onPressed: () => _openEditor(context, ref, service: service),
              icon: const Icon(Icons.add),
              label: const Text('Add plan'),
            ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    MembershipTypeDefinition? existing,
    required MembershipTypeService? service,
  }) async {
    if (service == null) return;
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final feeCtrl = TextEditingController(text: '${existing?.fee ?? 0}');
    final creditsCtrl = TextEditingController(
      text: '${existing?.creditsToAdd ?? 0}',
    );
    final durationCtrl = TextEditingController(
      text: existing?.durationInDays?.toString() ?? '',
    );
    final discountCtrl = TextEditingController(
      text: '${existing?.discountPercentage ?? 0}',
    );
    final tierCtrl = TextEditingController(text: '${existing?.tierLevel ?? 0}');
    final prefixCtrl = TextEditingController(text: existing?.idPrefix ?? '');
    int colorArgb = existing?.colorArgb ?? 0xFF795548;
    final allDefs =
        ref.read(membershipTypeDefinitionsProvider).valueOrNull ?? [];
    final maxSortOrder = allDefs.isEmpty
        ? -1
        : allDefs
            .map((d) => d.sortOrder)
            .reduce((a, b) => a > b ? a : b);
    final sortOrder = existing?.sortOrder ?? (maxSortOrder + 1);
    final sortCtrl = TextEditingController(text: '$sortOrder');

    final isEditing = existing != null;
    final isRegularLocked = existing?.isRegular == true;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final theme = Theme.of(ctx);
            return AlertDialog(
              title: Text(
                isEditing
                    ? (isRegularLocked ? 'Edit walk-in tier' : 'Edit plan')
                    : 'New plan',
              ),
              content: SingleChildScrollView(
                physics: AppTheme.scrollPhysicsFor(ctx),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: AppTheme.inputDecoration(theme, 'Display name'),
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: idCtrl,
                        decoration: AppTheme.inputDecoration(
                          theme,
                          'Id (optional slug, e.g. bronze1)',
                        ).copyWith(
                          helperText:
                              'Leave blank to generate from the display name (a–z, 0–9). '
                              'Non-Latin names: enter an id or one is auto-generated. '
                              'Stored on customers as membershipType.',
                        ),
                      ),
                    ],
                    if (!isRegularLocked) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: feeCtrl,
                        decoration: AppTheme.inputDecoration(theme, 'Fee (₹)'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: creditsCtrl,
                        decoration: AppTheme.inputDecoration(
                          theme,
                          'Credits to add',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: durationCtrl,
                        decoration: AppTheme.inputDecoration(
                          theme,
                          'Duration (days), empty = no expiry',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: discountCtrl,
                        decoration: AppTheme.inputDecoration(
                          theme,
                          'Table discount %',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tierCtrl,
                        decoration: AppTheme.inputDecoration(
                          theme,
                          'Tier level (for ordering / comparison)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: prefixCtrl,
                        decoration: AppTheme.inputDecoration(
                          theme,
                          'Card ID prefix (e.g. BRONZE1)',
                        ).copyWith(
                          helperText: 'Used for membership card numbers.',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Accent color',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            0xFF9E9E9E,
                            0xFF8D6E63,
                            0xFF795548,
                            0xFF6D4C41,
                            0xFF607D8B,
                            0xFFFFD700,
                            0xFF4CAF50,
                            0xFF2196F3,
                            0xFFE91E63,
                            0xFF9C27B0,
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
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outline
                                            .withValues(alpha: 0.45),
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
                    const SizedBox(height: 12),
                    TextField(
                      decoration: AppTheme.inputDecoration(theme, 'Sort order'),
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
                    late String id;
                    if (isEditing) {
                      id = existing.id;
                    } else {
                      var raw = idCtrl.text.trim();
                      if (raw.isEmpty) {
                        raw = name;
                      }
                      id = raw.toLowerCase().replaceAll(
                        RegExp(r'[^a-z0-9_]+'),
                        '_',
                      );
                      id = id.replaceAll(RegExp(r'_+'), '_');
                      id = id.replaceAll(RegExp(r'^_|_$'), '');
                      if (id.isEmpty) {
                        id =
                            'plan_${DateTime.now().millisecondsSinceEpoch}';
                      }
                    }
                    if (id == kRegularMembershipTypeId && !isRegularLocked) {
                      if (ctx.mounted) {
                        context.showErrorSnackbar(
                          'Reserved id: use another slug for paid plans.',
                        );
                      }
                      return;
                    }
                    if (!isEditing) {
                      final exists = await tenant
                          .membershipTypeDefinitions()
                          .doc(id)
                          .get();
                      if (exists.exists && ctx.mounted) {
                        context.showErrorSnackbar(
                          'That id is already in use. Pick another.',
                        );
                        return;
                      }
                    }

                    final parsedOrder = int.tryParse(sortCtrl.text.trim());
                    final fee = int.tryParse(feeCtrl.text.trim()) ?? 0;
                    final credits = int.tryParse(creditsCtrl.text.trim()) ?? 0;
                    final durRaw = durationCtrl.text.trim();
                    final durationDays = durRaw.isEmpty
                        ? null
                        : int.tryParse(durRaw);
                    final discount =
                        double.tryParse(discountCtrl.text.trim()) ?? 0;
                    final tier = int.tryParse(tierCtrl.text.trim()) ?? 0;
                    final prefix = prefixCtrl.text.trim().toUpperCase();

                    if (!isRegularLocked && fee < 0) {
                      if (ctx.mounted) {
                        context.showErrorSnackbar('Fee cannot be negative');
                      }
                      return;
                    }

                    final def = MembershipTypeDefinition(
                      id: id,
                      name: name,
                      fee: isRegularLocked ? 0 : fee,
                      creditsToAdd: isRegularLocked ? 0 : credits,
                      durationInDays: isRegularLocked ? null : durationDays,
                      discountPercentage: isRegularLocked ? 0 : discount,
                      tierLevel: isRegularLocked ? 0 : tier,
                      idPrefix: isRegularLocked ? '' : prefix,
                      colorArgb: colorArgb,
                      sortOrder: parsedOrder ?? sortOrder,
                      isArchived: existing?.isArchived ?? false,
                      isRegular: existing?.isRegular ?? false,
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
                          isEditing ? 'Plan updated' : 'Plan created',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        context.showErrorSnackbar('$e');
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

    // [showDialog]'s future can complete before the route finishes unmounting;
    // disposing controllers immediately races TextField teardown (web especially).
    void disposeCtrls() {
      nameCtrl.dispose();
      idCtrl.dispose();
      feeCtrl.dispose();
      creditsCtrl.dispose();
      durationCtrl.dispose();
      discountCtrl.dispose();
      tierCtrl.dispose();
      prefixCtrl.dispose();
      sortCtrl.dispose();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => disposeCtrls());
  }
}
