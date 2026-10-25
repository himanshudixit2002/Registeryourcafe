import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/venue_kind.dart';
import '../../theme/app_theme.dart';
import 'landing_providers.dart';
import 'public_venue_detail_screen.dart';

/// Search / discover tab -- filter venues by name, city, tags, and venue type.
class LandingSearchTab extends ConsumerStatefulWidget {
  const LandingSearchTab({super.key});

  @override
  ConsumerState<LandingSearchTab> createState() => _LandingSearchTabState();
}

class _LandingSearchTabState extends ConsumerState<LandingSearchTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  VenueKind? _kindFilter;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final venuesAsync = ref.watch(publicVenuesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Search venues, cuisines, cities...',
            leading: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.search_rounded),
            ),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHighest.withAlpha(120)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) setState(() => _query = v.trim().toLowerCase());
              });
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                avatar: Icon(Icons.grid_view_rounded, size: 16, color: _kindFilter == null ? cs.primary : cs.onSurfaceVariant),
                label: const Text('All'),
                selected: _kindFilter == null,
                onSelected: (_) => setState(() => _kindFilter = null),
              ),
              const SizedBox(width: 8),
              for (final kind in VenueKind.values) ...[
                FilterChip(
                  avatar: Icon(kind.icon, size: 16, color: _kindFilter == kind ? _accentForKind(kind, cs) : cs.onSurfaceVariant),
                  label: Text(kind.label),
                  selected: _kindFilter == kind,
                  onSelected: (_) => setState(() => _kindFilter = _kindFilter == kind ? null : kind),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: venuesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 48, color: cs.error.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text('Could not load venues', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Check your connection and try again.', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(publicVenuesProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
            data: (venues) {
              var filtered = venues.where((v) {
                if (_kindFilter != null && v.venueKind != _kindFilter) return false;
                if (_query.isEmpty) return true;
                final hay = '${v.displayName} ${v.city ?? ''} ${v.area ?? ''} ${v.venueKind.label} ${v.discoveryTags.join(' ')}'.toLowerCase();
                return hay.contains(_query);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _query.isEmpty && _kindFilter == null ? Icons.storefront_outlined : Icons.search_off_rounded,
                        size: 48,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty && _kindFilter == null
                            ? 'No venues available yet'
                            : _kindFilter != null
                                ? 'No ${_kindFilter!.label.toLowerCase()} venues found'
                                : 'No results for "$_query"',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _query.isEmpty && _kindFilter == null
                            ? 'Venues will appear here once cafe owners enable public discovery.'
                            : 'Try a different search or filter.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                      ),
                      if (_query.isNotEmpty || _kindFilter != null) ...[
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _kindFilter = null;
                            });
                          },
                          icon: const Icon(Icons.filter_alt_off, size: 18),
                          label: const Text('Clear filters'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                physics: AppTheme.scrollPhysicsFor(context),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final v = filtered[i];
                  final kind = v.venueKind;
                  final accent = _accentForKind(kind, cs);

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: v.coverImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                v.coverImageUrl!,
                                width: 56,
                                height: 56,
                                cacheWidth: 400,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(kind.icon, size: 28, color: accent),
                                ),
                              ),
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(kind.icon, color: accent, size: 28),
                            ),
                      title: Text(v.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(kind.icon, size: 12, color: accent),
                              const SizedBox(width: 4),
                              Text(kind.label, style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (v.area != null || v.city != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                [v.area, v.city].whereType<String>().where((s) => s.trim().isNotEmpty).join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => PublicVenueDetailScreen(listing: v)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
