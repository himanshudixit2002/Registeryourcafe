import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/venue_kind.dart';
import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';
import 'sa_cafe_detail_screen.dart';

class SACafesScreen extends ConsumerStatefulWidget {
  const SACafesScreen({super.key});

  @override
  ConsumerState<SACafesScreen> createState() => _SACafesScreenState();
}

class _SACafesScreenState extends ConsumerState<SACafesScreen> {
  String _search = '';
  VenueKind? _venueFilter;
  String _statusFilter = 'active';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final companiesAsync = ref.watch(allCompaniesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Cafes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(allCompaniesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchAndFilters(
            search: _search,
            venueFilter: _venueFilter,
            statusFilter: _statusFilter,
            onSearchChanged: (v) => setState(() => _search = v.toLowerCase()),
            onSearchCleared: () => setState(() => _search = ''),
            onVenueFilterChanged: (v) => setState(() => _venueFilter = v),
            onStatusFilterChanged: (v) => setState(() => _statusFilter = v),
          ),
          companiesAsync.when(
            data: (companies) {
              final counts = <VenueKind, int>{};
              for (final doc in companies) {
                final kind = VenueKind.parse(doc.data()['venueKind']);
                counts[kind] = (counts[kind] ?? 0) + 1;
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    _CountChip(
                      label: 'Total',
                      count: companies.length,
                      color: cs.primary,
                      icon: Icons.business,
                    ),
                    const SizedBox(width: 8),
                    for (final kind in VenueKind.values) ...[
                      _CountChip(
                        label: kind.label,
                        count: counts[kind] ?? 0,
                        color: _accentForKind(kind, cs),
                        icon: kind.icon,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: companiesAsync.when(
              data: (companies) {
                final filtered = companies.where((doc) {
                  final data = doc.data();
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final owner = (data['ownerUid'] as String? ?? '').toLowerCase();
                  final kind = VenueKind.parse(data['venueKind']);
                  final suspended = data['suspended'] == true;
                  final deleted = data['deleted'] == true;

                  final matchesSearch = _search.isEmpty ||
                      name.contains(_search) ||
                      owner.contains(_search) ||
                      doc.id.toLowerCase().contains(_search);
                  final matchesVenue = _venueFilter == null || kind == _venueFilter;
                  final matchesStatus = switch (_statusFilter) {
                    'active' => !suspended && !deleted,
                    'suspended' => suspended,
                    'deleted' => deleted,
                    _ => true,
                  };
                  return matchesSearch && matchesVenue && matchesStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('No cafes match your filters', style: theme.textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _search = '';
                            _venueFilter = null;
                            _statusFilter = 'all';
                          }),
                          icon: const Icon(Icons.filter_alt_off, size: 18),
                          label: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  physics: AppTheme.scrollPhysicsFor(context),
                  padding: AppTheme.getScreenPadding(context),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    return FadeInWidget(
                      delay: Duration(milliseconds: 40 * (index % 20)),
                      child: _CafeCard(doc: doc),
                    );
                  },
                );
              },
              loading: () => const ShimmerList(),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: cs.error),
                      const SizedBox(height: 12),
                      Text('Failed to load cafes', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(allCompaniesProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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

class _SearchAndFilters extends StatelessWidget {
  final String search;
  final VenueKind? venueFilter;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<VenueKind?> onVenueFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;

  const _SearchAndFilters({
    required this.search,
    required this.venueFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onVenueFilterChanged,
    required this.onStatusFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, owner, or ID...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: onSearchCleared)
                  : null,
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  avatar: Icon(Icons.business, size: 16, color: venueFilter == null ? cs.primary : cs.onSurfaceVariant),
                  label: const Text('All types'),
                  selected: venueFilter == null,
                  onSelected: (_) => onVenueFilterChanged(null),
                ),
                const SizedBox(width: 8),
                for (final kind in VenueKind.values) ...[
                  FilterChip(
                    avatar: Icon(kind.icon, size: 16, color: venueFilter == kind ? _accentForKind(kind, cs) : cs.onSurfaceVariant),
                    label: Text(kind.label),
                    selected: venueFilter == kind,
                    onSelected: (_) => onVenueFilterChanged(kind),
                  ),
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'active', label: Text('Active')),
                    ButtonSegment(value: 'suspended', label: Text('Suspended')),
                    ButtonSegment(value: 'deleted', label: Text('Deleted')),
                  ],
                  selected: {statusFilter},
                  onSelectionChanged: (s) => onStatusFilterChanged(s.first),
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _CafeCard extends ConsumerWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _CafeCard({required this.doc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final data = doc.data();
    final name = data['name'] as String? ?? 'Unnamed';
    final kind = VenueKind.parse(data['venueKind']);
    final ownerUid = data['ownerUid'] as String? ?? '';
    final suspended = data['suspended'] == true;
    final deleted = data['deleted'] == true;
    final createdAt = data['createdAt'];
    final accent = _accentForKind(kind, cs);

    String dateStr = '';
    if (createdAt is Timestamp) {
      dateStr = DateFormat.yMMMd().format(createdAt.toDate());
    }

    final iconBg = suspended
        ? AppTheme.warningColor.withValues(alpha: 0.15)
        : deleted
            ? cs.error.withValues(alpha: 0.15)
            : accent.withValues(alpha: 0.12);
    final iconColor = suspended ? AppTheme.warningColor : deleted ? cs.error : accent;

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SACafeDetailScreen(companyId: doc.id),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(kind.icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: AppTheme.kSpacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(kind.icon, size: 13, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      kind.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (dateStr.isNotEmpty) ...[
                      Text('  ·  ', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      Text(dateStr, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
                if (ownerUid.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Owner: $ownerUid',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}
