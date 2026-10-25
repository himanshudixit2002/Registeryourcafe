import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/ui_helpers.dart';

import '../../branding/app_assets.dart';
import '../../models/venue_kind.dart';
import '../../theme/app_theme.dart';
import '../../widgets/legal_footer_links.dart';
import 'discovery_filters.dart';
import 'discover_venues_screen.dart';
import 'landing_providers.dart';
import 'public_venue_detail_screen.dart';

/// Premium first-touch surface: discover venues, hero, workspace paths.
class LandingHomeTab extends ConsumerWidget {
  final VoidCallback onGoLive;
  final VoidCallback onLogin;
  final void Function(VenueKind kind) onRegisterWithVenue;

  const LandingHomeTab({
    super.key,
    required this.onGoLive,
    required this.onLogin,
    required this.onRegisterWithVenue,
  });

  static const _featureChips = <({IconData icon, String label})>[
    (icon: Icons.table_restaurant_outlined, label: 'Live floor'),
    (icon: Icons.local_cafe_outlined, label: 'Café & POS'),
    (icon: Icons.people_outline, label: 'Members'),
    (icon: Icons.emoji_events_outlined, label: 'Events'),
    (icon: Icons.leaderboard_outlined, label: 'Leaderboard'),
    (icon: Icons.inventory_2_outlined, label: 'Inventory'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;
    final width = MediaQuery.sizeOf(context).width;
    // Edge padding; on wide web use slightly more gutter so content doesn’t touch the window edge.
    final padH = isMobile
        ? 20.0
        : math.min(72.0, math.max(32.0, width * 0.035));
    // Use full viewport width minus gutters (fixes narrow “column in the middle” on web).
    final maxContent = math.max(280.0, width - 2 * padH);

    return CustomScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padH, 12, padH, 0),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContent),
                child: SizedBox(
                  width: double.infinity,
                  child: _DiscoverSection(key: const ValueKey('discover'), contentWidth: maxContent),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padH, 28, padH, 0),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContent),
                child: SizedBox(
                  width: double.infinity,
                  child: _HeroPanel(
                    theme: theme,
                    isMobile: isMobile,
                    onLogin: onLogin,
                    onGoLive: onGoLive,
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padH, 28, padH, 0),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContent),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start your workspace',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick a template — modules stay flexible in Settings.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final kind in VenueKind.values) ...[
                        _VenueChoiceCard(
                          theme: theme,
                          icon: kind.outlinedIcon,
                          accent: switch (kind) {
                            VenueKind.gamingCafe => theme.colorScheme.primary,
                            VenueKind.diningCafe => theme.colorScheme.tertiary,
                            VenueKind.restaurantCafe => AppTheme.successColor,
                          },
                          title: kind.label,
                          subtitle: kind.shortDescription,
                          onTap: () => onRegisterWithVenue(kind),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: onLogin,
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: Text(isMobile ? 'Login' : 'Sign in'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onGoLive,
                            icon: const Icon(
                              Icons.emoji_events_outlined,
                              size: 18,
                            ),
                            label: const Text('Public events'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padH, 32, padH, 0),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContent),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Built for serious operators',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _featureChips
                            .map(
                              (c) => _FeatureChip(icon: c.icon, label: c.label),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padH, 36, padH, 32 + padH),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContent),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            AppAssets.appLogo,
                            height: 32,
                            filterQuality: FilterQuality.medium,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'One ledger. One floor. One calm night of service.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      LegalFooterLinks(compact: isMobile),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiscoverSection extends ConsumerStatefulWidget {
  const _DiscoverSection({super.key, required this.contentWidth});

  final double contentWidth;

  @override
  ConsumerState<_DiscoverSection> createState() => _DiscoverSectionState();
}

class _DiscoverSectionState extends ConsumerState<_DiscoverSection> {
  static const _homePreviewMax = 6;
  final _homeSearch = TextEditingController();

  @override
  void dispose() {
    _homeSearch.dispose();
    super.dispose();
  }

  int get _gridColumns {
    if (widget.contentWidth >= AppTheme.kDesktopBreakpoint) return 3;
    if (widget.contentWidth >= 720) return 2;
    return 1;
  }

  void _openDiscover({
    DiscoveryFilters? filters,
    String? query,
  }) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiscoverVenuesScreen(
          initialFilters: filters,
          initialSearchQuery: query,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final venuesAsync = ref.watch(publicVenuesProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.85),
            scheme.tertiaryContainer.withValues(alpha: 0.75),
            scheme.surfaceContainerHighest,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.explore_rounded,
                        color: scheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discover venues',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Live table status & menus from venues that went public.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _homeSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Find your next cafe...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Open advanced search',
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: () => _openDiscover(
                        query: _homeSearch.text,
                      ),
                    ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onSubmitted: (q) => _openDiscover(query: q),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        avatar: Icon(VenueKind.gamingCafe.icon, size: 16),
                        label: const Text('Gaming cafes'),
                        onSelected: (_) => _openDiscover(
                          filters: DiscoveryFilters(kinds: Set.from(DiscoveryFilters.gamingKinds)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: Icon(VenueKind.diningCafe.icon, size: 16),
                        label: const Text('Dining'),
                        onSelected: (_) => _openDiscover(
                          filters: DiscoveryFilters(kinds: {VenueKind.diningCafe}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: Icon(VenueKind.restaurantCafe.icon, size: 16),
                        label: const Text('Restaurants'),
                        onSelected: (_) => _openDiscover(
                          filters: DiscoveryFilters(kinds: {VenueKind.restaurantCafe}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Browse all'),
                        onSelected: (_) => _openDiscover(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                venuesAsync.when(
                  data: (venues) {
                    if (venues.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(children: [
                          Icon(Icons.storefront_outlined, size: 40, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text('No venues listed yet', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            'Venues appear here when cafe owners enable public discovery. Register your venue to be the first!',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                          ),
                        ]),
                      );
                    }
                    final preview = venues.length.clamp(0, _homePreviewMax);
                    final cols = _gridColumns;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${venues.length} live ${venues.length == 1 ? 'listing' : 'listings'}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Browse cafes near you. Book tables, view menus, and check live availability.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (cols > 1)
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: cols == 3 ? 2.15 : 2.35,
                                ),
                            itemCount: preview,
                            itemBuilder: (context, i) {
                              return FadeInWidget(
                                delay: Duration(milliseconds: 60 * i),
                                child: PublicVenueListTile(listing: venues[i]),
                              );
                            },
                          )
                        else
                          Column(
                            children: [
                              for (var i = 0; i < preview; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                FadeInWidget(
                                  delay: Duration(milliseconds: 60 * i),
                                  child: PublicVenueListTile(listing: venues[i]),
                                ),
                              ],
                            ],
                          ),
                        if (venues.length > _homePreviewMax) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _openDiscover(),
                              icon: const Icon(Icons.explore_rounded, size: 20),
                              label: Text('Browse all ${venues.length} venues'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ] else if (venues.length > 1) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openDiscover(),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Search & filter venues'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: ShimmerList(itemCount: 3, itemHeight: 64),
                  ),
                  error: (err, _) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.error.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Could not load venues',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Network or Firestore rules may be blocking anonymous reads. '
                          'You can retry — listings load without extra indexes now.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () =>
                              ref.invalidate(publicVenuesProvider),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.theme,
    required this.isMobile,
    required this.onLogin,
    required this.onGoLive,
  });

  final ThemeData theme;
  final bool isMobile;
  final VoidCallback onLogin;
  final VoidCallback onGoLive;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.35) ?? scheme.primary,
            scheme.tertiary,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.blur_on_rounded,
              size: 160,
              color: scheme.onPrimary.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -10,
            child: Icon(
              Icons.grid_4x4_rounded,
              size: 120,
              color: scheme.onPrimary.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 22 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'VENUE OPERATIONS PLATFORM',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 18 : 22),
                Text(
                  'Run tables, kitchen,\nand members — in sync.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                    letterSpacing: -0.8,
                    fontSize: isMobile ? 30 : 38,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Built for gaming cafés, dining rooms, and full-service restaurants. '
                  'Real-time sessions, stock, loyalty, and events without duct tape.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.88),
                    height: 1.45,
                  ),
                ),
                SizedBox(height: isMobile ? 22 : 26),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.onPrimary,
                        foregroundColor: scheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                      ),
                      onPressed: onLogin,
                      child: Text(isMobile ? 'Sign in' : 'Open workspace'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onPrimary,
                        side: BorderSide(
                          color: scheme.onPrimary.withValues(alpha: 0.55),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onPressed: onGoLive,
                      child: const Text('Browse events'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueChoiceCard extends StatelessWidget {
  const _VenueChoiceCard({
    required this.theme,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final ThemeData theme;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.12),
                theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.9,
                ),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 26, color: accent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: accent.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
