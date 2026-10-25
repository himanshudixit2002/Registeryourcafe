import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/venue_kind.dart';
import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class SAAnalyticsScreen extends ConsumerWidget {
  const SAAnalyticsScreen({super.key});

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
        title: const Text('Platform Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
      body: ListView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: AppTheme.getScreenPadding(context),
        children: [
          Text('Growth Metrics', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppTheme.kSpacingMedium),
          _buildGrowthCards(context, companiesAsync, usersAsync, isDesktop),
          const SizedBox(height: AppTheme.kSpacingLarge),
          Text('Support Overview', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingSmall),
          ticketsAsync.when(
            data: (tickets) => _SupportStats(tickets: tickets),
            loading: () => const ShimmerList(itemCount: 1, itemHeight: 80),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Failed to load', style: TextStyle(color: cs.error)),
              const SizedBox(height: 4),
              Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () { ref.invalidate(supportTicketsProvider); }, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
            ])),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          Text('Reviews Summary', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingSmall),
          reviewsAsync.when(
            data: (reviews) => _ReviewStats(reviews: reviews),
            loading: () => const ShimmerList(itemCount: 1, itemHeight: 80),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Failed to load', style: TextStyle(color: cs.error)),
              const SizedBox(height: 4),
              Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () { ref.invalidate(allReviewsProvider); }, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
            ])),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          Text('Guest Orders', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingSmall),
          ordersAsync.when(
            data: (orders) => _OrderStats(orders: orders),
            loading: () => const ShimmerList(itemCount: 1, itemHeight: 80),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Failed to load', style: TextStyle(color: cs.error)),
              const SizedBox(height: 4),
              Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () { ref.invalidate(allGuestOrdersProvider); }, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
            ])),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          Text('Booking Requests', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingSmall),
          bookingsAsync.when(
            data: (bookings) => _BookingStats(bookings: bookings),
            loading: () => const ShimmerList(itemCount: 1, itemHeight: 80),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Failed to load', style: TextStyle(color: cs.error)),
              const SizedBox(height: 4),
              Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () { ref.invalidate(allBookingRequestsProvider); }, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
            ])),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          Text('Guest Profiles', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingSmall),
          guestsAsync.when(
            data: (guests) => _GuestStats(guests: guests),
            loading: () => const ShimmerList(itemCount: 1, itemHeight: 80),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Failed to load', style: TextStyle(color: cs.error)),
              const SizedBox(height: 4),
              Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () { ref.invalidate(allGuestProfilesProvider); }, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
            ])),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          Text('Venue Type Distribution', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingSmall),
          companiesAsync.when(
            data: (companies) => _VenueDistribution(companies: companies),
            loading: () => const ShimmerList(itemCount: 3, itemHeight: 60),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Failed to load', style: TextStyle(color: cs.error)),
              const SizedBox(height: 4),
              Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () { ref.invalidate(allCompaniesProvider); }, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
            ])),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          Text('Registration Timeline', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingSmall),
          companiesAsync.when(
            data: (companies) => _RegistrationTimeline(companies: companies),
            loading: () => const ShimmerList(itemCount: 6, itemHeight: 24),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Failed to load', style: TextStyle(color: cs.error)),
              const SizedBox(height: 4),
              Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () { ref.invalidate(allCompaniesProvider); }, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
            ])),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          Text('Platform Health', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingSmall),
          companiesAsync.when(
            data: (companies) => _PlatformHealth(companies: companies),
            loading: () => const ShimmerList(itemCount: 1, itemHeight: 80),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Failed to load', style: TextStyle(color: cs.error)),
              const SizedBox(height: 4),
              Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () { ref.invalidate(allCompaniesProvider); }, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
            ])),
          ),
          const SizedBox(height: AppTheme.kSpacingXLarge),
        ],
      ),
    );
  }

  Widget _buildGrowthCards(
    BuildContext context,
    AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>> companiesAsync,
    AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>> usersAsync,
    bool isDesktop,
  ) {
    final companies = companiesAsync.valueOrNull ?? [];
    final users = usersAsync.valueOrNull ?? [];
    final isLoading = companiesAsync.isLoading || usersAsync.isLoading;

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    int recentCompanies30 = 0;
    int recentCompanies7 = 0;
    for (final doc in companies) {
      final ts = doc.data()['createdAt'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        if (dt.isAfter(thirtyDaysAgo)) recentCompanies30++;
        if (dt.isAfter(sevenDaysAgo)) recentCompanies7++;
      }
    }

    final cards = [
      _MetricCard(
        title: 'Total Cafes',
        valueWidget: isLoading
            ? const ShimmerLoading(height: 28, width: 60)
            : AnimatedCountUp(
                endValue: companies.length.toDouble(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
        icon: Icons.storefront,
        color: Theme.of(context).colorScheme.primary,
      ),
      _MetricCard(
        title: 'Total Users',
        valueWidget: isLoading
            ? const ShimmerLoading(height: 28, width: 60)
            : AnimatedCountUp(
                endValue: users.length.toDouble(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.infoColor,
                ),
              ),
        icon: Icons.people,
        color: AppTheme.infoColor,
      ),
      _MetricCard(
        title: 'Last 30 Days',
        valueWidget: isLoading
            ? const ShimmerLoading(height: 28, width: 60)
            : AnimatedCountUp(
                endValue: recentCompanies30.toDouble(),
                prefix: '+',
                suffix: ' cafes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.successColor,
                ),
              ),
        icon: Icons.trending_up,
        color: AppTheme.successColor,
      ),
      _MetricCard(
        title: 'Last 7 Days',
        valueWidget: isLoading
            ? const ShimmerLoading(height: 28, width: 60)
            : AnimatedCountUp(
                endValue: recentCompanies7.toDouble(),
                prefix: '+',
                suffix: ' cafes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.warningColor,
                ),
              ),
        icon: Icons.bolt,
        color: AppTheme.warningColor,
      ),
    ];

    if (isDesktop) {
      return Row(children: cards.map((c) => Expanded(child: c)).toList());
    }
    return Wrap(
      children: cards.map((c) => SizedBox(
        width: MediaQuery.of(context).size.width / 2 - 20,
        child: c,
      )).toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final Widget valueWidget;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.valueWidget,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeInWidget(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            valueWidget,
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportStats extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> tickets;
  const _SupportStats({required this.tickets});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    int open = 0, inProgress = 0, resolved = 0;
    for (final t in tickets) {
      switch (t.data()['status'] as String? ?? 'open') {
        case 'open': open++;
        case 'inProgress': inProgress++;
        case 'resolved': resolved++;
      }
    }
    return AppCard(
      child: Row(
        children: [
          Expanded(child: _MiniStat(label: 'Total', value: tickets.length, color: cs.primary)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Open', value: open, color: AppTheme.warningColor)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'In Progress', value: inProgress, color: AppTheme.infoColor)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Resolved', value: resolved, color: AppTheme.successColor)),
        ],
      ),
    );
  }
}

class _ReviewStats extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> reviews;
  const _ReviewStats({required this.reviews});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    double totalRating = 0;
    int flagged = 0;
    for (final r in reviews) {
      final d = r.data();
      totalRating += (d['rating'] as num?)?.toDouble() ?? 0;
      if (d['flagged'] == true) flagged++;
    }
    final avgRating = reviews.isNotEmpty ? totalRating / reviews.length : 0.0;

    return AppCard(
      child: Row(
        children: [
          Expanded(child: _MiniStat(label: 'Total', value: reviews.length, color: cs.primary)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.tertiary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.star_rounded, color: cs.tertiary, size: 20),
                  ],
                ),
                Text('Avg Rating', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Flagged', value: flagged, color: cs.error)),
        ],
      ),
    );
  }
}

class _OrderStats extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders;
  const _OrderStats({required this.orders});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    int pending = 0, converted = 0, cancelled = 0;
    for (final o in orders) {
      switch (o.data()['status'] as String? ?? 'pending') {
        case 'pending': pending++;
        case 'converted': converted++;
        case 'cancelled': cancelled++;
      }
    }
    return AppCard(
      child: Row(
        children: [
          Expanded(child: _MiniStat(label: 'Total', value: orders.length, color: cs.primary)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Pending', value: pending, color: AppTheme.warningColor)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Converted', value: converted, color: AppTheme.successColor)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Cancelled', value: cancelled, color: cs.error)),
        ],
      ),
    );
  }
}

class _BookingStats extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings;
  const _BookingStats({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    int pending = 0, approved = 0, declined = 0;
    for (final b in bookings) {
      switch (b.data()['status'] as String? ?? 'pending') {
        case 'pending': pending++;
        case 'approved': approved++;
        case 'declined': declined++;
      }
    }
    return AppCard(
      child: Row(
        children: [
          Expanded(child: _MiniStat(label: 'Total', value: bookings.length, color: cs.primary)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Pending', value: pending, color: AppTheme.warningColor)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Approved', value: approved, color: AppTheme.successColor)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Declined', value: declined, color: cs.error)),
        ],
      ),
    );
  }
}

class _GuestStats extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> guests;
  const _GuestStats({required this.guests});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    int active = 0, suspended = 0;
    for (final g in guests) {
      if (g.data()['suspended'] == true) {
        suspended++;
      } else {
        active++;
      }
    }
    return AppCard(
      child: Row(
        children: [
          Expanded(child: _MiniStat(label: 'Total', value: guests.length, color: cs.primary)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Active', value: active, color: AppTheme.successColor)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _MiniStat(label: 'Suspended', value: suspended, color: AppTheme.warningColor)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        AnimatedCountUp(
          endValue: value.toDouble(),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
      ],
    );
  }
}

class _VenueDistribution extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> companies;

  const _VenueDistribution({required this.companies});

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

    final Map<VenueKind, int> distribution = {};
    for (final doc in companies) {
      final kind = VenueKind.parse(doc.data()['venueKind']);
      distribution[kind] = (distribution[kind] ?? 0) + 1;
    }

    final sorted = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = companies.length;

    return AppCard(
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _accentForKind(sorted[i].key, cs).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(sorted[i].key.icon, size: 18, color: _accentForKind(sorted[i].key, cs)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sorted[i].key.label,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${sorted[i].value} (${total > 0 ? (sorted[i].value * 100 / total).toStringAsFixed(1) : 0}%)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _accentForKind(sorted[i].key, cs),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? sorted[i].value / total : 0,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: _accentForKind(sorted[i].key, cs),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RegistrationTimeline extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> companies;

  const _RegistrationTimeline({required this.companies});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Map<String, int> monthlyCount = {};
    for (final doc in companies) {
      final ts = doc.data()['createdAt'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        monthlyCount[key] = (monthlyCount[key] ?? 0) + 1;
      }
    }

    final sorted = monthlyCount.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final last12 = sorted.length > 12 ? sorted.sublist(sorted.length - 12) : sorted;
    final maxCount = last12.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    if (last12.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
          child: Center(child: Text('No registration data', style: TextStyle(color: cs.onSurfaceVariant))),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (final entry in last12)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: cs.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: maxCount > 0 ? entry.value / maxCount : 0,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: cs.primary,
                        minHeight: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${entry.value}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlatformHealth extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> companies;

  const _PlatformHealth({required this.companies});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    int active = 0;
    int suspended = 0;
    int deleted = 0;
    for (final doc in companies) {
      final data = doc.data();
      if (data['deleted'] == true) {
        deleted++;
      } else if (data['suspended'] == true) {
        suspended++;
      } else {
        active++;
      }
    }

    return AppCard(
      child: Row(
        children: [
          Expanded(child: _HealthStat(label: 'Active', valueWidget: AnimatedCountUp(endValue: active.toDouble(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.successColor)), color: AppTheme.successColor)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _HealthStat(label: 'Suspended', valueWidget: AnimatedCountUp(endValue: suspended.toDouble(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.warningColor)), color: AppTheme.warningColor)),
          Container(width: 1, height: 40, color: cs.outlineVariant),
          Expanded(child: _HealthStat(label: 'Deleted', valueWidget: AnimatedCountUp(endValue: deleted.toDouble(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.error)), color: cs.error)),
        ],
      ),
    );
  }
}

class _HealthStat extends StatelessWidget {
  final String label;
  final Widget valueWidget;
  final Color color;

  const _HealthStat({required this.label, required this.valueWidget, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        valueWidget,
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
