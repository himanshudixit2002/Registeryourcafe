import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/public_venue_listing.dart';
import '../../../models/venue_kind.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';
import '../landing_providers.dart';
import '../public_venue_detail_screen.dart';

class LandingSearchTab extends ConsumerStatefulWidget {
  const LandingSearchTab({super.key});

  @override
  ConsumerState<LandingSearchTab> createState() => _LandingSearchTabState();
}

class _LandingSearchTabState extends ConsumerState<LandingSearchTab> {
  final _searchController = TextEditingController();
  String _query = '';
  VenueKind? _kindFilter;
  String _sortBy = 'name';
  bool _gridView = true;
  final List<String> _searchHistory = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String val) {
    setState(() => _query = val.trim().toLowerCase());
    if (val.trim().isNotEmpty && !_searchHistory.contains(val.trim())) {
      _searchHistory.insert(0, val.trim());
      if (_searchHistory.length > 10) _searchHistory.removeLast();
    }
  }

  List<PublicVenueListing> _filter(List<PublicVenueListing> venues) {
    var filtered = venues.where((v) {
      if (_query.isNotEmpty) {
        final match = v.displayName.toLowerCase().contains(_query) ||
            (v.tagline?.toLowerCase().contains(_query) ?? false) ||
            (v.address?.toLowerCase().contains(_query) ?? false) ||
            (v.city?.toLowerCase().contains(_query) ?? false) ||
            v.discoveryTags.any((t) => t.contains(_query));
        if (!match) return false;
      }
      if (_kindFilter != null && v.venueKind != _kindFilter) return false;
      return true;
    }).toList();

    switch (_sortBy) {
      case 'name':
        filtered
            .sort((a, b) => a.displayName.compareTo(b.displayName));
      case 'recent':
        filtered.sort((a, b) =>
            (b.updatedAt ?? DateTime(2000))
                .compareTo(a.updatedAt ?? DateTime(2000)));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venuesAsync = ref.watch(publicVenuesProvider);
    final isDesktop = AppTheme.isDesktop(context);
    final pad =
        isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium;

    return CustomScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchBar(
                  controller: _searchController,
                  hintText: 'Search venues, menu items, events...',
                  leading: const Icon(Icons.search, size: 22),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                    IconButton(
                      icon: Icon(
                          _gridView ? Icons.view_list : Icons.grid_view),
                      onPressed: () =>
                          setState(() => _gridView = !_gridView),
                    ),
                  ],
                  onChanged: _onSearch,
                  padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 16)),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(theme, 'All', _kindFilter == null,
                          () => setState(() => _kindFilter = null)),
                      for (final k in VenueKind.values) ...[
                        const SizedBox(width: 8),
                        _filterChip(
                          theme,
                          k.label,
                          _kindFilter == k,
                          () => setState(() =>
                              _kindFilter = _kindFilter == k ? null : k),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    PopupMenuButton<String>(
                      initialValue: _sortBy,
                      onSelected: (v) => setState(() => _sortBy = v),
                      child: Chip(
                        avatar: const Icon(Icons.sort, size: 16),
                        label: const Text('Sort'),
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'name', child: Text('Name A-Z')),
                        PopupMenuItem(
                            value: 'recent',
                            child: Text('Recently updated')),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      avatar: const Icon(Icons.filter_list, size: 16),
                      label: const Text('Filters'),
                    ),
                  ],
                ),
                if (_query.isEmpty && _searchHistory.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Recent searches',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final h in _searchHistory)
                        ActionChip(
                          avatar: const Icon(Icons.history, size: 16),
                          label: Text(h),
                          onPressed: () {
                            _searchController.text = h;
                            _onSearch(h);
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        venuesAsync.when(
          loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: ShimmerList()),
          error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Error: $e'))),
          data: (venues) {
            final filtered = _filter(venues);
            if (filtered.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(
                        _query.isEmpty
                            ? 'No venues available'
                            : 'No results for "$_query"',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 12, pad, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${filtered.length} venues found',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurfaceVariant),
                        ),
                      );
                    }
                    final venue = filtered[i - 1];
                    return FadeInWidget(
                      delay: Duration(milliseconds: 60 * (i - 1)),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _VenueSearchCard(venue: venue),
                      ),
                    );
                  },
                  childCount: filtered.length + 1,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _filterChip(
      ThemeData theme, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _VenueSearchCard extends StatelessWidget {
  final PublicVenueListing venue;
  const _VenueSearchCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
              builder: (_) =>
                  PublicVenueDetailScreen(listing: venue)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (venue.coverImageUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  venue.coverImageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Icon(Icons.storefront,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.displayName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          venue.venueKind.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (venue.tagline != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      venue.tagline!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (venue.address != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14,
                            color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            venue.address!,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (venue.discoveryTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final tag in venue.discoveryTags.take(4))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme
                                  .colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(tag,
                                style: theme.textTheme.labelSmall),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
