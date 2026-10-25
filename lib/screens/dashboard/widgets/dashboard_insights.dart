import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/venue_kind.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../utils/firestore_utils.dart';
import 'dashboard_section.dart';

class DashboardTopPerformers extends StatelessWidget {
  const DashboardTopPerformers({
    super.key,
    required this.data,
    this.venueKind = VenueKind.gamingCafe,
  });

  final DashboardData data;
  final VenueKind venueKind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;
    final (activeTableTitle, tableIcon, orderLabel) = switch (venueKind) {
      VenueKind.gamingCafe => ('Most active gaming table', Icons.sports_esports_rounded, 'Most ordered snack/drink'),
      VenueKind.diningCafe => ('Busiest dining table', Icons.table_restaurant_rounded, 'Most popular dish'),
      VenueKind.restaurantCafe => ('Busiest seat', Icons.chair_rounded, 'Top menu item'),
    };

    return DashboardSection(
      eyebrow: 'Highlights',
      title: 'Top performers',
      subtitle: switch (venueKind) {
        VenueKind.gamingCafe => 'Gaming session signals from the last 7 days',
        VenueKind.diningCafe => 'Dining insights from the last 7 days',
        VenueKind.restaurantCafe => 'Kitchen and service insights from the last 7 days',
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InsightRow(
            icon: tableIcon,
            title: activeTableTitle,
            value: data.mostActiveTable,
            subtitle: 'Based on today\'s activity',
            accent: theme.colorScheme.tertiary,
            isMobile: isMobile,
          ),
          Divider(
            height: isMobile ? 20 : 24,
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
          _InsightRow(
            icon: venueKind == VenueKind.gamingCafe ? Icons.local_cafe_rounded : Icons.restaurant_menu_rounded,
            title: orderLabel,
            value: data.popularItems.isNotEmpty
                ? data.popularItems.first.key
                : 'N/A',
            subtitle: data.popularItems.isNotEmpty
                ? '${data.popularItems.first.value} orders'
                : '',
            accent: theme.colorScheme.secondary,
            isMobile: isMobile,
          ),
          Divider(
            height: isMobile ? 20 : 24,
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
          _InsightRow(
            icon: Icons.schedule_rounded,
            title: 'Peak hours',
            value: data.peakHours,
            subtitle: 'Based on last 7 days',
            accent: theme.colorScheme.primary,
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }
}

class DashboardPopularItems extends StatelessWidget {
  const DashboardPopularItems({super.key, required this.popularItems});

  final List<MapEntry<String, int>> popularItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;

    return DashboardSection(
      eyebrow: 'Menu',
      title: 'Popular items',
      subtitle: 'By order count this week',
      child: popularItems.isEmpty
          ? _EmptyHint(
              icon: Icons.coffee_outlined,
              message: 'No popular items yet this week',
              isMobile: isMobile,
            )
          : Column(
              children: [
                for (var i = 0; i < popularItems.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.12),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '#${i + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 12 : 14),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.secondary.withValues(
                                  alpha: 0.2,
                                ),
                                theme.colorScheme.secondary.withValues(
                                  alpha: 0.08,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.local_cafe_rounded,
                            color: theme.colorScheme.secondary,
                            size: isMobile ? 20 : 22,
                          ),
                        ),
                        SizedBox(width: isMobile ? 12 : 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                popularItems[i].key,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${popularItems[i].value} orders',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
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

class DashboardRecentOrders extends StatelessWidget {
  const DashboardRecentOrders({
    super.key,
    required this.recentOrders,
    required this.onViewAll,
  });

  final List<Map<String, dynamic>> recentOrders;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;
    final currency = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);

    return DashboardSection(
      eyebrow: 'Activity',
      title: 'Recent orders',
      subtitle: 'Latest cafe and table activity',
      trailing: TextButton.icon(
        onPressed: onViewAll,
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: const Text('View all'),
      ),
      child: recentOrders.isEmpty
          ? _EmptyHint(
              icon: Icons.receipt_long_outlined,
              message: 'No recent orders to show',
              isMobile: isMobile,
            )
          : Column(
              children: [
                for (var index = 0; index < recentOrders.length; index++) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.12),
                    ),
                  Builder(
                    builder: (context) {
                      final order = recentOrders[index];
                      final createdAt = order['createdAt'] as Timestamp?;
                      final totalAmount = parseFirestoreDoubleOrNull(
                        order['totalAmount'],
                      );
                      final type = order['type'] as String? ?? 'Order';

                      final (icon, accent, title, subtitle) = switch (type) {
                        'Table Session' => (
                          Icons.table_restaurant_rounded,
                          theme.colorScheme.tertiary,
                          'Session at ${order['tableName'] ?? 'Table'}',
                          'Session ended',
                        ),
                        _ => (
                          Icons.local_cafe_rounded,
                          theme.colorScheme.secondary,
                          'Order #${(order['id'] as String?) ?? 'N/A'}',
                          'Cafe order',
                        ),
                      };

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 10 : 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    accent.withValues(alpha: 0.22),
                                    accent.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(icon, color: accent, size: 22),
                            ),
                            SizedBox(width: isMobile ? 12 : 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    createdAt != null
                                        ? '${DateFormat('MMM dd, HH:mm').format(createdAt.toDate())} · $subtitle'
                                        : subtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              totalAmount != null
                                  ? currency.format(totalAmount)
                                  : '—',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.isMobile,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.22),
                accent.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent, size: isMobile ? 22 : 24),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: isMobile ? 4 : 6),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.message,
    required this.isMobile,
  });

  final IconData icon;
  final String message;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 28 : 36),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: isMobile ? 40 : 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            SizedBox(height: isMobile ? 10 : 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
