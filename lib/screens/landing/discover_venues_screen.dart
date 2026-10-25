import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/ui_helpers.dart';

import '../../models/public_venue_listing.dart';
import '../../models/venue_kind.dart';
import '../../theme/app_theme.dart';
import 'discovery_filters.dart';
import 'landing_providers.dart';
import 'public_venue_detail_screen.dart';

/// Full-screen discovery: debounced search, multi-kind filters, sort, more filters.
class DiscoverVenuesScreen extends ConsumerStatefulWidget {
  const DiscoverVenuesScreen({
    super.key,
    this.initialKind,
    this.initialFilters,
    this.initialSearchQuery,
  });

  /// When set, adds this kind to [initialFilters].kinds (union).
  final VenueKind? initialKind;

  final DiscoveryFilters? initialFilters;

  final String? initialSearchQuery;

  @override
  ConsumerState<DiscoverVenuesScreen> createState() =>
      _DiscoverVenuesScreenState();
}

class _DiscoverVenuesScreenState extends ConsumerState<DiscoverVenuesScreen> {
  late final TextEditingController _search;
  late DiscoveryFilters _filters;
  Timer? _debounce;
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    var f = widget.initialFilters ?? const DiscoveryFilters();
    if (widget.initialKind != null) {
      f = f.copyWith(kinds: {...f.kinds, widget.initialKind!});
    }
    _filters = f;

    final q0 = widget.initialSearchQuery?.trim() ?? '';
    _search = TextEditingController(text: q0);
    _debouncedQuery = q0;

    _search.addListener(_onSearchEdited);
  }

  void _onSearchEdited() {
    _scheduleSearchDebounce();
  }

  void _scheduleSearchDebounce() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _debouncedQuery = _search.text.trim());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearchEdited);
    _search.dispose();
    super.dispose();
  }

  void _clearSearchAndFilters() {
    _search.clear();
    _debouncedQuery = '';
    setState(() => _filters = const DiscoveryFilters());
  }

  bool get _hasActiveSearchOrFilters =>
      _debouncedQuery.isNotEmpty || _filters.hasActiveConstraints;

  Future<void> _openMoreFilters(List<PublicVenueListing> allVenues) async {
    final tags = discoveryTagsUnion(allVenues);
    var local = _filters;
    final bottom = await showModalBottomSheet<DiscoveryFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.paddingOf(ctx).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'More filters',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Has cover photo'),
                      value: local.requireCoverPhoto,
                      onChanged: (v) =>
                          setModal(() => local = local.copyWith(
                                requireCoverPhoto: v,
                              )),
                    ),
                    SwitchListTile(
                      title: const Text('Has address'),
                      value: local.requireAddress,
                      onChanged: (v) =>
                          setModal(() => local = local.copyWith(
                                requireAddress: v,
                              )),
                    ),
                    SwitchListTile(
                      title: const Text('Has phone'),
                      value: local.requirePhone,
                      onChanged: (v) =>
                          setModal(() => local = local.copyWith(
                                requirePhone: v,
                              )),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tags',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((t) {
                          final sel = local.selectedTags.contains(t);
                          return FilterChip(
                            label: Text(t),
                            selected: sel,
                            onSelected: (_) {
                              setModal(() {
                                final next = Set<String>.from(
                                  local.selectedTags,
                                );
                                if (sel) {
                                  next.remove(t);
                                } else {
                                  next.add(t);
                                }
                                local = local.copyWith(selectedTags: next);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () {
                        setModal(() {
                          local = local.copyWith(
                            requireCoverPhoto: false,
                            requireAddress: false,
                            requirePhone: false,
                            selectedTags: {},
                          );
                        });
                      },
                      child: const Text('Reset these filters'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, local),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (bottom != null && mounted) {
      setState(() => _filters = bottom);
    }
  }

  bool _presetAllSelected() => _filters.kinds.isEmpty;

  bool _presetFoodSelected() =>
      _filters.kinds.length == DiscoveryFilters.foodAndDrinkKinds.length &&
      DiscoveryFilters.foodAndDrinkKinds.every(_filters.kinds.contains);

  void _setKindsPreset(Set<VenueKind> kinds) {
    setState(() => _filters = _filters.copyWith(kinds: kinds));
  }

  void _toggleKind(VenueKind k) {
    setState(() {
      final next = Set<VenueKind>.from(_filters.kinds);
      if (next.contains(k)) {
        next.remove(k);
      } else {
        next.add(k);
      }
      _filters = _filters.copyWith(kinds: next);
    });
  }

  bool _kindChipSelected(VenueKind k) =>
      _filters.kinds.isEmpty || _filters.kinds.contains(k);

  int _gridColumns(double width) {
    if (width >= AppTheme.kDesktopBreakpoint) return 3;
    if (width >= 720) return 2;
    return 1;
  }

  int _moreFiltersBadgeCount() {
    var n = 0;
    if (_filters.requireCoverPhoto) n++;
    if (_filters.requireAddress) n++;
    if (_filters.requirePhone) n++;
    n += _filters.selectedTags.length;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final asyncVenues = ref.watch(publicVenuesProvider);
    final width = MediaQuery.sizeOf(context).width;
    final padH = width < AppTheme.kMobileBreakpoint
        ? 16.0
        : math.min(56.0, math.max(24.0, width * 0.04));
    final badge = _moreFiltersBadgeCount();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover venues'),
        actions: [
          PopupMenuButton<DiscoverySort>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            initialValue: _filters.sort,
            onSelected: (s) {
              setState(() => _filters = _filters.copyWith(sort: s));
            },
            itemBuilder: (ctx) => DiscoverySort.values
                .map(
                  (s) => PopupMenuItem(
                    value: s,
                    child: Text(s.menuLabel),
                  ),
                )
                .toList(),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(publicVenuesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: asyncVenues.when(
        data: (venues) {
          final filtered =
              applyDiscoveryQuery(venues, _debouncedQuery, _filters);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(publicVenuesProvider);
              await Future<void>.delayed(const Duration(milliseconds: 350));
            },
            child: CustomScrollView(
              physics: AppTheme.scrollPhysicsFor(context),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padH, 8, padH, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SearchBar(
                          controller: _search,
                          hintText:
                              'Search name, city, area, tagline, or tags…',
                          leading: const Icon(Icons.search_rounded),
                          trailing: _search.text.isEmpty
                              ? null
                              : [
                                  IconButton(
                                    tooltip: 'Clear',
                                    onPressed: () {
                                      _search.clear();
                                      setState(
                                        () => _debouncedQuery = '',
                                      );
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openMoreFilters(venues),
                                icon: Badge(
                                  isLabelVisible: badge > 0,
                                  label: Text('$badge'),
                                  child: const Icon(Icons.tune_rounded),
                                ),
                                label: const Text('More filters'),
                              ),
                            ),
                            if (_hasActiveSearchOrFilters) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _clearSearchAndFilters,
                                child: const Text('Clear all'),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('All types'),
                                selected: _presetAllSelected(),
                                onSelected: (_) =>
                                    _setKindsPreset({}),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Food & drink'),
                                selected: _presetFoodSelected(),
                                onSelected: (_) => _setKindsPreset(
                                  Set.from(
                                    DiscoveryFilters.foodAndDrinkKinds,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: Text(VenueKind.gamingCafe.label),
                                selected: _kindChipSelected(
                                  VenueKind.gamingCafe,
                                ),
                                onSelected: (_) =>
                                    _toggleKind(VenueKind.gamingCafe),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: Text(VenueKind.diningCafe.label),
                                selected: _kindChipSelected(
                                  VenueKind.diningCafe,
                                ),
                                onSelected: (_) =>
                                    _toggleKind(VenueKind.diningCafe),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: Text(VenueKind.restaurantCafe.label),
                                selected: _kindChipSelected(
                                  VenueKind.restaurantCafe,
                                ),
                                onSelected: (_) =>
                                    _toggleKind(VenueKind.restaurantCafe),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sort: ${_filters.sort.menuLabel}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          venues.isEmpty
                              ? 'No public listings'
                              : '${filtered.length} of ${venues.length} shown',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (venues.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No venues on the map yet',
                      subtitle:
                          'Owners can enable public discovery in workspace Settings.',
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No matches',
                      subtitle:
                          'Try another search, clear filters, or change venue type.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(padH, 0, padH, 24 + padH),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final cols = _gridColumns(constraints.crossAxisExtent);
                        if (cols > 1) {
                          final ratio = cols == 3 ? 2.2 : 2.4;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: ratio,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                return PublicVenueListTile(
                                  listing: filtered[i],
                                );
                              },
                              childCount: filtered.length,
                            ),
                          );
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              return FadeInWidget(
                                delay: Duration(milliseconds: 60 * i),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: i < filtered.length - 1 ? 12 : 0,
                                  ),
                                  child: PublicVenueListTile(
                                    listing: filtered[i],
                                  ),
                                ),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const ShimmerList(),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: scheme.error),
                const SizedBox(height: 16),
                Text(
                  'Could not load venues',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your connection and Firestore rules. If this persists, '
                  'ask the venue owner to confirm public discovery is enabled.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(publicVenuesProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
