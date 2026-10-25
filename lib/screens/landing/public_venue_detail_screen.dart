import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../utils/ui_helpers.dart';

import '../../models/public_venue_listing.dart';
import '../../models/table.dart';
import '../../models/tournament.dart';
import '../../models/venue_kind.dart';
import '../../models/public_booking_slot.dart';
import '../../models/public_floor_table.dart';
import '../../theme/app_theme.dart';
import '../tournament/register_tournament_dialog.dart';
import '../../widgets/safe_network_avatar.dart';
import 'landing_providers.dart';
import 'landing_public_widgets.dart';
import 'public_floor_booking_sheet.dart';
import 'public_menu_ordering_tab.dart';

/// Anonymous-friendly venue page with venue-type-specific tabs.
class PublicVenueDetailScreen extends ConsumerWidget {
  const PublicVenueDetailScreen({super.key, required this.listing});

  final PublicVenueListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = listing.venueKind;
    final accent = _accentForKind(kind, Theme.of(context).colorScheme);

    return DefaultTabController(
      length: _tabCount(kind),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(kind.icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Flexible(child: Text(listing.displayName, overflow: TextOverflow.ellipsis)),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabs(kind),
          ),
        ),
        body: TabBarView(children: _tabBodies(context, ref, kind)),
      ),
    );
  }

  int _tabCount(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return 5;
      case VenueKind.diningCafe:
        return 4;
      case VenueKind.restaurantCafe:
        return 4;
    }
  }

  List<Widget> _tabs(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return const [
          Tab(icon: Icon(Icons.info_outline, size: 18), text: 'About'),
          Tab(icon: Icon(Icons.restaurant_menu, size: 18), text: 'Menu'),
          Tab(icon: Icon(Icons.emoji_events_outlined, size: 18), text: 'Events'),
          Tab(icon: Icon(Icons.leaderboard_outlined, size: 18), text: 'Leaderboard'),
          Tab(icon: Icon(Icons.grid_view_outlined, size: 18), text: 'Live Floor'),
        ];
      case VenueKind.diningCafe:
        return const [
          Tab(icon: Icon(Icons.info_outline, size: 18), text: 'About'),
          Tab(icon: Icon(Icons.restaurant_menu, size: 18), text: 'Menu'),
          Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: 'Book a Table'),
          Tab(icon: Icon(Icons.grid_view_outlined, size: 18), text: 'Live Floor'),
        ];
      case VenueKind.restaurantCafe:
        return const [
          Tab(icon: Icon(Icons.info_outline, size: 18), text: 'About'),
          Tab(icon: Icon(Icons.restaurant_menu, size: 18), text: 'Menu & Order'),
          Tab(icon: Icon(Icons.event_seat_outlined, size: 18), text: 'Reservations'),
          Tab(icon: Icon(Icons.kitchen_outlined, size: 18), text: 'Live Kitchen'),
        ];
    }
  }

  List<Widget> _tabBodies(BuildContext context, WidgetRef ref, VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return [
          _PublicAboutTab(listing: listing),
          PublicMenuOrderingTab(companyId: listing.companyId, venueKind: kind),
          _PublicTournamentsTab(companyId: listing.companyId),
          _PublicLeaderboardTab(companyId: listing.companyId),
          _PublicFloorTab(listing: listing),
        ];
      case VenueKind.diningCafe:
        return [
          _PublicAboutTab(listing: listing),
          PublicMenuOrderingTab(companyId: listing.companyId, venueKind: kind),
          _PublicBookingTab(listing: listing),
          _PublicFloorTab(listing: listing),
        ];
      case VenueKind.restaurantCafe:
        return [
          _PublicAboutTab(listing: listing),
          PublicMenuOrderingTab(companyId: listing.companyId, venueKind: kind),
          _PublicBookingTab(listing: listing),
          _PublicKitchenStatusTab(listing: listing),
        ];
    }
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

class _PublicAboutTab extends StatelessWidget {
  const _PublicAboutTab({required this.listing});

  final PublicVenueListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = listing.venueKind;
    final accent = _accentForKind(kind, scheme);

    String? fmtUpdated() {
      final u = listing.updatedAt;
      if (u == null) return null;
      return DateFormat.yMMMd().add_jm().format(u);
    }

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.all(20),
      children: [
        if (listing.coverImageUrl != null && listing.coverImageUrl!.trim().isNotEmpty) ...[
          Hero(
            tag: 'venue-cover-${listing.companyId}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  listing.coverImageUrl!.trim(),
                  cacheWidth: 800,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant, size: 40),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        FadeInWidget(
          delay: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: accent.withValues(alpha: 0.08),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(kind.icon, color: accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kind.label,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: accent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kind.shortDescription,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (listing.tagline != null && listing.tagline!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            listing.tagline!.trim(),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.4, color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 20),
        if (listing.address != null && listing.address!.trim().isNotEmpty)
          _AboutRow(icon: Icons.place_outlined, label: 'Address', value: listing.address!.trim()),
        if (listing.phone != null && listing.phone!.trim().isNotEmpty)
          _AboutRow(icon: Icons.phone_outlined, label: 'Phone', value: listing.phone!.trim()),
        if (listing.hoursNote != null && listing.hoursNote!.trim().isNotEmpty)
          _AboutRow(icon: Icons.schedule_outlined, label: 'Hours', value: listing.hoursNote!.trim()),
        if (fmtUpdated() != null)
          _AboutRow(icon: Icons.update_outlined, label: 'Listing updated', value: fmtUpdated()!),
        if (_hasNoContactDetails())
          Text(
            'This venue has not added contact details yet.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
      ],
    );
  }

  bool _hasNoContactDetails() {
    return (listing.address?.trim().isEmpty ?? true) &&
        (listing.phone?.trim().isEmpty ?? true) &&
        (listing.hoursNote?.trim().isEmpty ?? true);
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge?.copyWith(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicTournamentsTab extends ConsumerWidget {
  const _PublicTournamentsTab({required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(publicTournamentsForCompanyFamily(companyId));
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 52, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No tournaments right now', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'This gaming cafe hasn\'t published any tournaments yet. Check back for upcoming events.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final t = list[i];
            return FadeInWidget(
              delay: Duration(milliseconds: 60 * i),
              child: PublicTournamentCard(
                tournament: t,
                onRegister: t.status == TournamentStatus.registration
                    ? () => showDialog<void>(context: context, builder: (_) => RegisterTournamentDialog(tournament: t))
                    : null,
              ),
            );
          },
        );
      },
      loading: () => const ShimmerList(),
      error: (_, _) => _ErrorRetry(
        message: 'Could not load events.',
        onRetry: () => ref.invalidate(publicTournamentsForCompanyFamily(companyId)),
      ),
    );
  }
}

class _PublicLeaderboardTab extends ConsumerWidget {
  const _PublicLeaderboardTab({required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.leaderboard_outlined, size: 48, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text('Leaderboard', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Player rankings and scores for this gaming cafe. Stats are updated after each session.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Leaderboard data is visible to registered players.',
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicBookingTab extends ConsumerWidget {
  const _PublicBookingTab({required this.listing});

  final PublicVenueListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = listing.venueKind;
    final accent = _accentForKind(kind, scheme);
    final tablesAsync = ref.watch(publicFloorTablesFamily(listing.companyId));

    final title = kind == VenueKind.restaurantCafe ? 'Make a Reservation' : 'Book a Table';
    final subtitle = kind == VenueKind.restaurantCafe
        ? 'Reserve your spot for a great dining experience.'
        : 'Pick an available table and request a time slot.';

    return tablesAsync.when(
      data: (tables) {
        final available = tables.where((t) => t.status == TableStatus.available).toList();
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: 0.12), scheme.surfaceContainerHighest],
                ),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(kind == VenueKind.restaurantCafe ? Icons.event_seat : Icons.calendar_month, size: 32, color: accent),
                  const SizedBox(height: 12),
                  Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${available.length} available',
                          style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${tables.length} total',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (tables.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No tables published for booking yet.', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              )
            else
              ...tables.map((t) {
                final isAvailable = t.status == TableStatus.available;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      onTap: () => showPublicFloorBookingSheet(
                        context,
                        companyId: listing.companyId,
                        table: t,
                        venuePhone: listing.phone,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isAvailable ? AppTheme.successColor.withValues(alpha: 0.12) : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.table_restaurant,
                          color: isAvailable ? AppTheme.successColor : scheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${t.capacity} seats  ·  ${isAvailable ? 'Available now' : t.status.name}',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      trailing: isAvailable
                          ? FilledButton.tonal(
                              onPressed: () => showPublicFloorBookingSheet(
                                context,
                                companyId: listing.companyId,
                                table: t,
                                venuePhone: listing.phone,
                              ),
                              child: const Text('Book'),
                            )
                          : Chip(
                              label: Text(t.status.name),
                              backgroundColor: scheme.surfaceContainerHighest,
                              side: BorderSide.none,
                              labelStyle: theme.textTheme.labelSmall,
                            ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
      loading: () => const ShimmerList(),
      error: (_, _) => _ErrorRetry(
        message: 'Could not load tables.',
        onRetry: () => ref.invalidate(publicFloorTablesFamily(listing.companyId)),
      ),
    );
  }
}

class _PublicKitchenStatusTab extends ConsumerWidget {
  const _PublicKitchenStatusTab({required this.listing});

  final PublicVenueListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tablesAsync = ref.watch(publicFloorTablesFamily(listing.companyId));

    return tablesAsync.when(
      data: (tables) {
        final occupied = tables.where((t) => t.status == TableStatus.occupied).length;
        final available = tables.where((t) => t.status == TableStatus.available).length;
        final total = tables.length;

        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.successColor.withValues(alpha: 0.12),
                    scheme.surfaceContainerHighest,
                  ],
                ),
                border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(Icons.kitchen_outlined, size: 40, color: AppTheme.successColor),
                  const SizedBox(height: 14),
                  Text('Kitchen Status', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Real-time view of the restaurant floor.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _KitchenStat(label: 'Occupied', value: '$occupied', color: scheme.error),
                      _KitchenStat(label: 'Available', value: '$available', color: AppTheme.successColor),
                      _KitchenStat(label: 'Total', value: '$total', color: scheme.primary),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (tables.isEmpty)
              Center(
                child: Text('No live floor data available.', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
              )
            else
              ...tables.map((t) {
                final statusColor = switch (t.status) {
                  TableStatus.available => AppTheme.successColor,
                  TableStatus.occupied => scheme.error,
                  TableStatus.maintenance => scheme.outline,
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${t.capacity} seats', style: theme.textTheme.bodySmall),
                      trailing: Chip(
                        label: Text(t.status.name),
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        side: BorderSide.none,
                        labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
      loading: () => const ShimmerList(),
      error: (_, _) => _ErrorRetry(
        message: 'Could not load kitchen status.',
        onRetry: () => ref.invalidate(publicFloorTablesFamily(listing.companyId)),
      ),
    );
  }
}

class _KitchenStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KitchenStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _PublicFloorTab extends ConsumerWidget {
  const _PublicFloorTab({required this.listing});

  final PublicVenueListing listing;

  String get _companyId => listing.companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tablesAsync = ref.watch(publicFloorTablesFamily(_companyId));
    final slotsAsync = ref.watch(publicBookingSlotsFamily(_companyId));
    final isGaming = listing.venueKind == VenueKind.gamingCafe;

    return tablesAsync.when(
      data: (tables) {
        final slots = slotsAsync.maybeWhen(data: (s) => s, orElse: () => <PublicBookingSlot>[]);
        if (tables.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_outlined, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No live floor data', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'This venue hasn\'t published floor information yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.all(16),
          itemCount: tables.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = tables[i];
            return FadeInWidget(
              delay: Duration(milliseconds: 50 * i),
              child: Card(
                child: ListTile(
                  onTap: () => showPublicFloorBookingSheet(
                    context,
                    companyId: _companyId,
                    table: t,
                    venuePhone: listing.phone,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isGaming
                          ? (t.tablePurpose == TablePurpose.dining ? Icons.restaurant : Icons.sports_esports)
                          : Icons.table_restaurant,
                      color: scheme.primary,
                    ),
                  ),
                  title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${isGaming ? (t.tablePurpose == TablePurpose.dining ? 'Dining' : 'Gaming') + ' · ' : ''}'
                    '${t.capacity} seats · Tap to request a time',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  trailing: _PublicFloorStatusChip(table: t, slots: slots),
                ),
              ),
            );
          },
        );
      },
      loading: () => const ShimmerList(),
      error: (_, _) => _ErrorRetry(
        message: 'Could not load floor.',
        onRetry: () {
          ref.invalidate(publicFloorTablesFamily(_companyId));
          ref.invalidate(publicBookingSlotsFamily(_companyId));
        },
      ),
    );
  }
}

class _PublicFloorStatusChip extends StatelessWidget {
  const _PublicFloorStatusChip({required this.table, required this.slots});

  final PublicFloorTable table;
  final List<PublicBookingSlot> slots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    final (String label, Color color) = switch (table.status) {
      TableStatus.maintenance => ('Closed', scheme.outline),
      TableStatus.occupied => ('Occupied', scheme.error),
      TableStatus.available => () {
          final reserved = slots.any((s) => s.tableId == table.id && s.containsInstant(now));
          if (reserved) return ('Reserved', scheme.secondary);
          return ('Available', AppTheme.successColor);
        }(),
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelStyle: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'This data may not be publicly available yet.\nThe venue owner can enable it in their settings.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card used on landing lists to open [PublicVenueDetailScreen].
class PublicVenueListTile extends StatelessWidget {
  const PublicVenueListTile({super.key, required this.listing});

  final PublicVenueListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = listing.venueKind;
    final accent = _accentForKind(kind, theme.colorScheme);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SafeNetworkAvatar(
          imageUrl: listing.coverImageUrl,
          radius: 26,
          fallbackIcon: kind.outlinedIcon,
          fallbackIconColor: accent,
          fallbackBackgroundColor: accent.withValues(alpha: 0.12),
        ),
        title: Text(
          listing.displayName,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Row(
          children: [
            Icon(kind.icon, size: 12, color: accent),
            const SizedBox(width: 4),
            Text(kind.label, style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w600)),
            if (listing.city != null && listing.city!.trim().isNotEmpty) ...[
              Text('  ·  ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Flexible(child: Text(listing.city!.trim(), overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            ],
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => PublicVenueDetailScreen(listing: listing)),
          );
        },
      ),
    );
  }
}
