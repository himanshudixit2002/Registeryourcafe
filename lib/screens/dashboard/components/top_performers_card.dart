import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/dashboard_provider.dart';

class TopPerformersCard extends StatelessWidget {
  final DashboardData data;

  const TopPerformersCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        boxShadow: AppTheme.cardShadowFor(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Performers',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 24),
          _TopPerformerItem(
            icon: Icons.table_bar,
            title: 'Most Active Table',
            value: data.mostActiveTable,
            subtitle: "Based on today's orders",
            color: sem.warning,
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _TopPerformerItem(
            icon: Icons.coffee,
            title: 'Most Ordered Item',
            value: data.popularItems.isNotEmpty
                ? data.popularItems.first.key
                : 'N/A',
            subtitle: data.popularItems.isNotEmpty
                ? '${data.popularItems.first.value} orders'
                : '',
            color: sem.success,
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _TopPerformerItem(
            icon: Icons.access_time,
            title: 'Peak Hours',
            value: data.peakHours,
            subtitle: 'Based on last 7 days',
            color: cs.tertiary,
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }
}

class _TopPerformerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final bool isMobile;

  const _TopPerformerItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: isMobile ? 20 : 24),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 14 : 16,
                  color: cs.onSurface,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: isMobile ? 10 : 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
