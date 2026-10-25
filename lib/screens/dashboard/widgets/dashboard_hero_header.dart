import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/glass_panel.dart';

class DashboardHeroHeader extends StatelessWidget {
  const DashboardHeroHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    final greetingIcon = now.hour < 12
        ? Icons.wb_sunny_rounded
        : now.hour < 17
        ? Icons.wb_cloudy_rounded
        : Icons.nights_stay_rounded;

    return GlassPanel(
      blur: GlassBlur.auto,
      borderRadius: isMobile ? 18 : 22,
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.35),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 14 : 18,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.28),
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              greetingIcon,
              size: isMobile ? 22 : 28,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: isMobile ? 12 : 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        DateFormat(
                          isMobile ? 'EEE, MMM d' : 'EEEE, MMMM d, y',
                        ).format(now),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Text(
                  'Last 7 days of sales, sessions, and cafe activity',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
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
