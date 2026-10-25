import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/company_module_visibility.dart';
import '../../../models/venue_kind.dart';
import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../widgets/app_card.dart';

class SACafeDetailScreen extends ConsumerWidget {
  final String companyId;

  const SACafeDetailScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final companyAsync = ref.watch(companyDetailProvider(companyId));

    return companyAsync.when(
      data: (snapshot) {
        if (!snapshot.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Cafe Detail')),
            body: const Center(child: Text('Company not found')),
          );
        }

        final data = snapshot.data()!;
        final name = data['name'] as String? ?? 'Unnamed';
        final kind = VenueKind.parse(data['venueKind']);
        final ownerUid = data['ownerUid'] as String? ?? '';
        final suspended = data['suspended'] == true;
        final deleted = data['deleted'] == true;
        final createdAt = data['createdAt'];
        final modules = CompanyModuleVisibility.fromFirestoreData(data);
        final accent = _accentForKind(kind, cs);

        String dateStr = '';
        if (createdAt is Timestamp) {
          dateStr = DateFormat.yMMMd().add_jm().format(createdAt.toDate());
        }

        return Scaffold(
          body: CustomScrollView(
            physics: AppTheme.scrollPhysicsFor(context),
            slivers: [
              SliverAppBar.large(
                title: Text(name),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () {
                      ref.invalidate(companyDetailProvider(companyId));
                      ref.invalidate(companySubcollectionCountsProvider(companyId));
                    },
                  ),
                  _ActionsMenu(
                    companyId: companyId,
                    name: name,
                    suspended: suspended,
                    deleted: deleted,
                    kind: kind,
                  ),
                ],
              ),
              SliverPadding(
                padding: AppTheme.getScreenPadding(context),
                sliver: SliverList.list(
                  children: [
                    _VenueHeader(
                      name: name,
                      kind: kind,
                      accent: accent,
                      suspended: suspended,
                      deleted: deleted,
                      dateStr: dateStr,
                      ownerUid: ownerUid,
                      companyId: companyId,
                    ),
                    const SizedBox(height: 20),
                    _StatsSection(companyId: companyId, kind: kind),
                    const SizedBox(height: 20),
                    _ModuleVisibilitySection(modules: modules, kind: kind),
                    const SizedBox(height: 20),
                    _VenueConfigSection(kind: kind, data: data),
                    const SizedBox(height: 20),
                    _CustomerConfigSection(companyId: companyId),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('$e', style: TextStyle(color: cs.error))),
      ),
    );
  }
}

Color _accentForKind(VenueKind kind, ColorScheme cs) {
  switch (kind) {
    case VenueKind.gamingCafe:
      return cs.primary;
    case VenueKind.diningCafe:
      return cs.tertiary;
    case VenueKind.restaurantCafe:
      return AppTheme.successColor;
  }
}

class _VenueHeader extends StatelessWidget {
  final String name;
  final VenueKind kind;
  final Color accent;
  final bool suspended;
  final bool deleted;
  final String dateStr;
  final String ownerUid;
  final String companyId;

  const _VenueHeader({
    required this.name,
    required this.kind,
    required this.accent,
    required this.suspended,
    required this.deleted,
    required this.dateStr,
    required this.ownerUid,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.12),
            cs.surfaceContainerHighest,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(kind.icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            kind.label.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (suspended) ...[
                          const SizedBox(width: 8),
                          StatusBadge(label: 'SUSPENDED', color: AppTheme.warningColor),
                        ],
                        if (deleted) ...[
                          const SizedBox(width: 8),
                          StatusBadge(label: 'DELETED', color: cs.error),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      kind.shortDescription,
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: accent.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.calendar_today_outlined, label: 'Registered', value: dateStr.isNotEmpty ? dateStr : 'Unknown'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.person_outline, label: 'Owner UID', value: ownerUid.isNotEmpty ? ownerUid : 'Not set'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: companyId));
              if (context.mounted) context.showInfoSnackbar('Company ID copied');
            },
            child: _InfoRow(icon: Icons.key_outlined, label: 'Company ID', value: companyId),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label: ', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends ConsumerWidget {
  final String companyId;
  final VenueKind kind;

  const _StatsSection({required this.companyId, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final countsAsync = ref.watch(companySubcollectionCountsProvider(companyId));

    return SectionCard(
      title: 'Statistics',
      icon: Icons.bar_chart_rounded,
      child: countsAsync.when(
        data: (counts) {
          final isGaming = kind == VenueKind.gamingCafe;
          final isRestaurant = kind == VenueKind.restaurantCafe;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatTile(icon: kind.icon, label: 'Tables', value: '${counts['tables'] ?? 0}', color: cs.primary),
              _StatTile(
                icon: isGaming ? Icons.people : Icons.person_search,
                label: isGaming ? 'Customers' : 'Guests',
                value: '${counts['customers'] ?? 0}',
                color: AppTheme.infoColor,
              ),
              _StatTile(
                icon: isGaming ? Icons.receipt_long : Icons.restaurant_menu,
                label: isRestaurant ? 'Kitchen Orders' : 'Orders',
                value: '${counts['orders'] ?? 0}',
                color: cs.tertiary,
              ),
              _StatTile(
                icon: isGaming ? Icons.timer : Icons.event_seat,
                label: isGaming ? 'Sessions' : 'Seatings',
                value: '${counts['sessions'] ?? 0}',
                color: AppTheme.successColor,
              ),
              if (isGaming)
                _StatTile(icon: Icons.emoji_events, label: 'Tournaments', value: '${counts['tournaments'] ?? 0}', color: AppTheme.warningColor),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text('Could not load stats: $e', style: TextStyle(color: cs.error, fontSize: 13)),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ModuleVisibilitySection extends StatelessWidget {
  final CompanyModuleVisibility modules;
  final VenueKind kind;

  const _ModuleVisibilitySection({required this.modules, required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final effective = modules.forVenueKind(kind);

    final items = [
      ('Dashboard', Icons.dashboard_outlined, effective.dashboard),
      ('Tables', Icons.table_restaurant_outlined, effective.tables),
      ('Cafe / Kitchen', Icons.local_cafe_outlined, effective.cafe),
      ('Sales', Icons.point_of_sale_outlined, effective.sales),
      ('Inventory', Icons.inventory_2_outlined, effective.inventory),
      ('Customers', Icons.people_outline, effective.customers),
      ('Loyalty', Icons.loyalty_outlined, effective.loyalty),
      ('Leaderboard', Icons.leaderboard_outlined, effective.leaderboard),
      ('Tournaments', Icons.emoji_events_outlined, effective.tournaments),
      ('Merchandise', Icons.shopping_bag_outlined, effective.merchandise),
    ];

    return SectionCard(
      title: 'Module Visibility',
      icon: Icons.toggle_on_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final (label, icon, enabled) = item;
          return Chip(
            avatar: Icon(icon, size: 16, color: enabled ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.5)),
            label: Text(label),
            backgroundColor: enabled ? cs.primaryContainer.withValues(alpha: 0.5) : cs.surfaceContainerHighest,
            side: BorderSide(
              color: enabled ? cs.primary.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.15),
            ),
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: enabled ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5),
              fontWeight: enabled ? FontWeight.w600 : FontWeight.w400,
              decoration: enabled ? null : TextDecoration.lineThrough,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _VenueConfigSection extends StatelessWidget {
  final VenueKind kind;
  final Map<String, dynamic> data;

  const _VenueConfigSection({required this.kind, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = _accentForKind(kind, cs);

    final List<(String, String, IconData)> configItems = switch (kind) {
      VenueKind.gamingCafe => [
          ('Default Table Type', 'snooker', Icons.sports_esports_outlined),
          ('Leaderboard', 'Enabled', Icons.leaderboard_outlined),
          ('Tournaments', 'Enabled', Icons.emoji_events_outlined),
          ('Merchandise', 'Enabled', Icons.shopping_bag_outlined),
        ],
      VenueKind.diningCafe => [
          ('Default Table Type', 'cafe_table', Icons.table_restaurant_outlined),
          ('Focus', 'Dining sessions & kitchen', Icons.restaurant_outlined),
          ('Leaderboard', 'Disabled', Icons.leaderboard_outlined),
          ('Tournaments', 'Disabled', Icons.emoji_events_outlined),
        ],
      VenueKind.restaurantCafe => [
          ('Default Table Type', 'dining_room', Icons.table_restaurant_outlined),
          ('Focus', 'Kitchen & orders first', Icons.restaurant_menu_outlined),
          ('Merchandise', 'Disabled by default', Icons.shopping_bag_outlined),
          ('Table Purpose', 'Dining only', Icons.chair_outlined),
        ],
    };

    return SectionCard(
      title: 'Venue Configuration',
      icon: kind.icon,
      child: Column(
        children: configItems.map((item) {
          final (label, value, icon) = item;
          final isDisabled = value.toLowerCase().contains('disabled');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? cs.surfaceContainerHighest
                        : accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: isDisabled ? cs.onSurfaceVariant.withValues(alpha: 0.5) : accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                      Text(
                        value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDisabled ? cs.onSurfaceVariant.withValues(alpha: 0.6) : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CustomerConfigSection extends ConsumerWidget {
  final String companyId;

  const _CustomerConfigSection({required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final service = ref.watch(superAdminServiceProvider);

    return SectionCard(
      title: 'Customer & Loyalty Config',
      icon: Icons.loyalty_outlined,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: service.watchCompanyLoyaltySettings(companyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }

          final loyaltyData = snapshot.data?.data();
          if (loyaltyData == null || loyaltyData.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No loyalty settings configured for this cafe yet.',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            );
          }

          final pointsPerUnit = loyaltyData['pointsPerUnit'] ?? loyaltyData['pointsPerRupee'] ?? 0;
          final conversionRate = loyaltyData['conversionRate'] ?? 0;
          final enabled = loyaltyData['enabled'] == true;

          return Column(
            children: [
              _LoyaltyRow(label: 'Loyalty Program', value: enabled ? 'Active' : 'Inactive', color: enabled ? AppTheme.successColor : cs.onSurfaceVariant),
              const SizedBox(height: 6),
              _LoyaltyRow(label: 'Points per unit spent', value: '$pointsPerUnit', color: cs.primary),
              const SizedBox(height: 6),
              _LoyaltyRow(label: 'Conversion rate', value: '$conversionRate pts = 1 unit', color: cs.tertiary),
            ],
          );
        },
      ),
    );
  }
}

class _LoyaltyRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LoyaltyRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _ActionsMenu extends ConsumerWidget {
  final String companyId;
  final String name;
  final bool suspended;
  final bool deleted;
  final VenueKind kind;

  const _ActionsMenu({
    required this.companyId,
    required this.name,
    required this.suspended,
    required this.deleted,
    required this.kind,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => _handleAction(context, ref, action),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'change_type', child: ListTile(leading: Icon(Icons.swap_horiz), title: Text('Change venue type'), dense: true, contentPadding: EdgeInsets.zero)),
        if (!suspended)
          const PopupMenuItem(value: 'suspend', child: ListTile(leading: Icon(Icons.pause_circle_outline), title: Text('Suspend'), dense: true, contentPadding: EdgeInsets.zero))
        else
          const PopupMenuItem(value: 'reactivate', child: ListTile(leading: Icon(Icons.play_circle_outline), title: Text('Reactivate'), dense: true, contentPadding: EdgeInsets.zero)),
        if (!deleted)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final service = ref.read(superAdminServiceProvider);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    try {
      switch (action) {
        case 'change_type':
          final newKind = await showDialog<VenueKind>(
            context: context,
            builder: (ctx) => _ChangeVenueKindDialog(currentKind: kind),
          );
          if (newKind != null && newKind != kind && context.mounted) {
            await service.updateCompanyVenueKind(companyId, newKind.storageName);
            final preset = CompanyModuleVisibility.presetFor(newKind);
            await service.updateCompanyModuleVisibility(companyId, preset.toFirestoreMap());
            service.logSuperAdminAction(
              action: 'venue_kind_changed',
              actorEmail: email,
              entityType: 'company',
              entityId: companyId,
              details: 'Changed $name from ${kind.label} to ${newKind.label}',
            );
            if (context.mounted) context.showSuccessSnackbar('Venue type changed to ${newKind.label}');
          }
        case 'suspend':
          await service.suspendCompany(companyId);
          service.logSuperAdminAction(action: 'company_suspended', actorEmail: email, entityType: 'company', entityId: companyId, details: 'Suspended $name');
          if (context.mounted) context.showSuccessSnackbar('$name suspended');
        case 'reactivate':
          await service.reactivateCompany(companyId);
          service.logSuperAdminAction(action: 'company_reactivated', actorEmail: email, entityType: 'company', entityId: companyId, details: 'Reactivated $name');
          if (context.mounted) context.showSuccessSnackbar('$name reactivated');
        case 'delete':
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: Icon(Icons.delete_forever, color: Theme.of(ctx).colorScheme.error, size: 36),
              title: const Text('Delete Company?'),
              content: Text('This will soft-delete "$name". It can be recovered later by removing the deleted flag.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await service.deleteCompany(companyId);
            service.logSuperAdminAction(action: 'company_deleted', actorEmail: email, entityType: 'company', entityId: companyId, details: 'Deleted $name');
            if (context.mounted) {
              context.showSuccessSnackbar('$name deleted');
              Navigator.of(context).pop();
            }
          }
      }
    } catch (e) {
      if (context.mounted) context.showErrorSnackbar('Error: $e');
    }
  }
}

class _ChangeVenueKindDialog extends StatelessWidget {
  final VenueKind currentKind;

  const _ChangeVenueKindDialog({required this.currentKind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: const Text('Change Venue Type'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: VenueKind.values.map((kind) {
          final isCurrent = kind == currentKind;
          final accent = _accentForKind(kind, cs);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: isCurrent ? accent.withValues(alpha: 0.1) : null,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(kind.icon, color: accent, size: 22),
              ),
              title: Text(kind.label, style: TextStyle(fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600)),
              subtitle: Text(kind.shortDescription, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              trailing: isCurrent ? Icon(Icons.check_circle, color: accent) : null,
              onTap: isCurrent ? null : () => Navigator.pop(context, kind),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
