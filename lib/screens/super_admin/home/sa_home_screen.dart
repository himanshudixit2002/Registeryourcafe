import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/venue_kind.dart';
import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';
import '../cafes/sa_cafe_detail_screen.dart';

class SAHomeScreen extends ConsumerWidget {
  final ValueChanged<int>? onNavigate;
  const SAHomeScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final companiesAsync = ref.watch(allCompaniesProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final ticketsAsync = ref.watch(supportTicketsProvider);
    final reviewsAsync = ref.watch(allReviewsProvider);
    final ordersAsync = ref.watch(allGuestOrdersProvider);
    final bookingsAsync = ref.watch(allBookingRequestsProvider);
    final guestsAsync = ref.watch(allGuestProfilesProvider);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(allCompaniesProvider);
              ref.invalidate(allUsersProvider);
              ref.invalidate(supportTicketsProvider);
              ref.invalidate(allReviewsProvider);
              ref.invalidate(allGuestOrdersProvider);
              ref.invalidate(allBookingRequestsProvider);
              ref.invalidate(allGuestProfilesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allCompaniesProvider);
          ref.invalidate(allUsersProvider);
          ref.invalidate(supportTicketsProvider);
          ref.invalidate(allReviewsProvider);
          ref.invalidate(allGuestOrdersProvider);
          ref.invalidate(allBookingRequestsProvider);
          ref.invalidate(allGuestProfilesProvider);
          await Future<void>.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          physics: AppTheme.scrollPhysicsFor(context),
          padding: AppTheme.getScreenPadding(context),
          children: [
            const GradientHeader(
              title: 'Overview',
              subtitle: 'Platform dashboard at a glance',
            ),
            const SizedBox(height: AppTheme.kSpacingMedium),
            _OverviewCards(
              companiesAsync: companiesAsync,
              usersAsync: usersAsync,
              isDesktop: isDesktop,
            ),
            const SizedBox(height: AppTheme.kSpacingLarge),
            Text('Cross-Platform Summary', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppTheme.kSpacingSmall),
            _CrossPlatformSummary(
              ticketsAsync: ticketsAsync,
              reviewsAsync: reviewsAsync,
              ordersAsync: ordersAsync,
              bookingsAsync: bookingsAsync,
              guestsAsync: guestsAsync,
              onNavigate: onNavigate,
            ),
            const SizedBox(height: AppTheme.kSpacingLarge),
            Text('Venue Breakdown', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppTheme.kSpacingSmall),
            companiesAsync.when(
              data: (companies) => _VenueBreakdown(companies: companies, onNavigate: onNavigate),
              loading: () => const ShimmerList(itemCount: 3, itemHeight: 48),
              error: (e, _) => AppCard(child: Text('Error: $e', style: TextStyle(color: cs.error))),
            ),
            const SizedBox(height: AppTheme.kSpacingLarge),
            Text('Recent Registrations', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppTheme.kSpacingSmall),
            companiesAsync.when(
              data: (companies) => _RecentRegistrations(companies: companies),
              loading: () => const ShimmerList(itemCount: 4, itemHeight: 64),
              error: (e, _) => AppCard(child: Text('Error loading companies: $e', style: TextStyle(color: cs.error))),
            ),
            const SizedBox(height: AppTheme.kSpacingLarge),
            Text('Quick Actions', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppTheme.kSpacingSmall),
            Wrap(
              spacing: AppTheme.kSpacingSmall,
              runSpacing: AppTheme.kSpacingSmall,
              children: [
                _QuickActionChip(icon: Icons.storefront, label: 'Manage Cafes', color: cs.primary, onTap: () => onNavigate?.call(1)),
                _QuickActionChip(icon: Icons.support_agent, label: 'Support Tickets', color: AppTheme.warningColor, onTap: () => onNavigate?.call(6)),
                _QuickActionChip(icon: Icons.campaign_outlined, label: 'Broadcast', color: AppTheme.infoColor, onTap: () => onNavigate?.call(7)),
                _QuickActionChip(icon: Icons.analytics, label: 'Analytics', color: AppTheme.successColor, onTap: () => onNavigate?.call(4)),
                _QuickActionChip(icon: Icons.toggle_on, label: 'Features', color: cs.tertiary, onTap: () => onNavigate?.call(3)),
              ],
            ),
            const SizedBox(height: AppTheme.kSpacingXLarge),
          ],
        ),
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

class _CrossPlatformSummary extends StatelessWidget {
  final AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>> ticketsAsync;
  final AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>> reviewsAsync;
  final AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>> ordersAsync;
  final AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>> bookingsAsync;
  final AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>> guestsAsync;
  final ValueChanged<int>? onNavigate;

  const _CrossPlatformSummary({
    required this.ticketsAsync,
    required this.reviewsAsync,
    required this.ordersAsync,
    required this.bookingsAsync,
    required this.guestsAsync,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    int openTickets = 0;
    for (final t in ticketsAsync.valueOrNull ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      if ((t.data()['status'] ?? 'open') == 'open') openTickets++;
    }
    int pendingOrders = 0;
    for (final o in ordersAsync.valueOrNull ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      if ((o.data()['status'] ?? 'pending') == 'pending') pendingOrders++;
    }
    int pendingBookings = 0;
    for (final b in bookingsAsync.valueOrNull ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      if ((b.data()['status'] ?? 'pending') == 'pending') pendingBookings++;
    }

    final isLoading = ticketsAsync.isLoading || reviewsAsync.isLoading || ordersAsync.isLoading || bookingsAsync.isLoading || guestsAsync.isLoading;
    final hasAnyError = ticketsAsync.hasError || reviewsAsync.hasError || ordersAsync.hasError || bookingsAsync.hasError || guestsAsync.hasError;
    final effectiveLoading = isLoading && !hasAnyError;

    return Wrap(
      spacing: AppTheme.kSpacingSmall,
      runSpacing: AppTheme.kSpacingSmall,
      children: [
        _SummaryChip(icon: Icons.support_agent, label: 'Open Tickets', count: openTickets, color: AppTheme.warningColor, isLoading: effectiveLoading, onTap: () => onNavigate?.call(6)),
        _SummaryChip(icon: Icons.rate_review, label: 'Reviews', count: (reviewsAsync.valueOrNull ?? []).length, color: cs.tertiary, isLoading: effectiveLoading, onTap: () => onNavigate?.call(8)),
        _SummaryChip(icon: Icons.shopping_bag, label: 'Pending Orders', count: pendingOrders, color: AppTheme.infoColor, isLoading: effectiveLoading, onTap: () => onNavigate?.call(10)),
        _SummaryChip(icon: Icons.event_seat, label: 'Pending Bookings', count: pendingBookings, color: cs.tertiary, isLoading: effectiveLoading, onTap: () => onNavigate?.call(11)),
        _SummaryChip(icon: Icons.person_search, label: 'Guests', count: (guestsAsync.valueOrNull ?? []).length, color: AppTheme.successColor, isLoading: effectiveLoading, onTap: () => onNavigate?.call(9)),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _SummaryChip({required this.icon, required this.label, required this.count, required this.color, required this.isLoading, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
          const SizedBox(width: 6),
          isLoading
              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
        ],
      ),
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.06),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>> companiesAsync;
  final AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>> usersAsync;
  final bool isDesktop;

  const _OverviewCards({required this.companiesAsync, required this.usersAsync, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final companyCount = companiesAsync.valueOrNull?.length ?? 0;
    final userCount = usersAsync.valueOrNull?.length ?? 0;
    final isLoading = companiesAsync.isLoading || usersAsync.isLoading;
    final hasError = companiesAsync.hasError || usersAsync.hasError;

    Widget valueFor(double value, Color color) {
      if (isLoading) return const ShimmerLoading(height: 32, width: 60);
      if (hasError) {
        return Text('--', style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800, color: cs.onSurfaceVariant,
        ));
      }
      return AnimatedCountUp(
        endValue: value,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800, color: color,
        ),
      );
    }

    final cards = [
      _StatCard(
        icon: Icons.storefront,
        label: hasError ? 'Cafes (error)' : 'Total Cafes',
        valueWidget: valueFor(companyCount.toDouble(), cs.primary),
        color: cs.primary,
      ),
      _StatCard(
        icon: Icons.people,
        label: hasError ? 'Users (error)' : 'Total Users',
        valueWidget: valueFor(userCount.toDouble(), AppTheme.infoColor),
        color: AppTheme.infoColor,
      ),
      _StatCard(
        icon: Icons.trending_up,
        label: 'Avg Users/Cafe',
        valueWidget: valueFor(
          companyCount > 0 ? userCount / companyCount : 0,
          AppTheme.successColor,
        ),
        color: AppTheme.successColor,
      ),
    ];

    if (isDesktop) {
      return Row(children: cards.map((c) => Expanded(child: c)).toList());
    }
    return Column(children: cards);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget valueWidget;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.valueWidget, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AppTheme.kSpacingMedium),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              valueWidget,
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _VenueBreakdown extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> companies;
  final ValueChanged<int>? onNavigate;

  const _VenueBreakdown({required this.companies, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Map<VenueKind, int> breakdown = {};
    for (final doc in companies) {
      final kind = VenueKind.parse(doc.data()['venueKind']);
      breakdown[kind] = (breakdown[kind] ?? 0) + 1;
    }

    if (breakdown.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
          child: Center(child: Text('No cafes registered yet', style: TextStyle(color: cs.onSurfaceVariant))),
        ),
      );
    }

    final sortedEntries = breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        children: [
          for (int i = 0; i < sortedEntries.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onNavigate?.call(1),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _accentForKind(sortedEntries[i].key, cs).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(sortedEntries[i].key.icon, size: 20, color: _accentForKind(sortedEntries[i].key, cs)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sortedEntries[i].key.label,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: companies.isNotEmpty ? sortedEntries[i].value / companies.length : 0,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: _accentForKind(sortedEntries[i].key, cs),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${sortedEntries[i].value}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _accentForKind(sortedEntries[i].key, cs),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${(sortedEntries[i].value * 100 / companies.length).round()}%',
                          style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentRegistrations extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> companies;

  const _RecentRegistrations({required this.companies});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final recent = companies.take(10).toList();

    if (recent.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
          child: Center(child: Text('No companies registered yet', style: TextStyle(color: cs.onSurfaceVariant))),
        ),
      );
    }

    return Column(
      children: recent.map((doc) {
        final data = doc.data();
        final name = data['name'] as String? ?? 'Unnamed';
        final kind = VenueKind.parse(data['venueKind']);
        final accent = _accentForKind(kind, cs);
        final createdAt = data['createdAt'];
        String dateStr = '';
        if (createdAt is Timestamp) {
          dateStr = DateFormat.yMMMd().add_jm().format(createdAt.toDate());
        }
        final suspended = data['suspended'] == true;
        final deleted = data['deleted'] == true;

        return AppCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => SACafeDetailScreen(companyId: doc.id)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(kind.icon, color: accent, size: 20),
              ),
              const SizedBox(width: AppTheme.kSpacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(kind.icon, size: 12, color: accent),
                        const SizedBox(width: 4),
                        Text(kind.label, style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w600)),
                        if (dateStr.isNotEmpty) ...[
                          Text('  ·  ', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          Text(dateStr, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}
