import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class LandingBookingsTab extends ConsumerWidget {
  final VoidCallback? onLogin;
  const LandingBookingsTab({super.key, this.onLogin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);
    final pad =
        isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium;

    return CustomScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My bookings',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Manage your reservations and walk-in queue',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeInWidget(
                  delay: const Duration(milliseconds: 100),
                  child: _ActionCard(
                    icon: Icons.event_seat,
                    title: 'Join walk-in queue',
                    subtitle: 'Skip the wait by joining the queue now',
                    color: theme.colorScheme.primary,
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 12),
                FadeInWidget(
                  delay: const Duration(milliseconds: 200),
                  child: _ActionCard(
                    icon: Icons.calendar_today,
                    title: 'Make a reservation',
                    subtitle: 'Book a table at your favorite venue',
                    color: theme.colorScheme.tertiary,
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 12),
                FadeInWidget(
                  delay: const Duration(milliseconds: 300),
                  child: _ActionCard(
                    icon: Icons.repeat,
                    title: 'Recurring bookings',
                    subtitle:
                        'Set up weekly game nights or regular visits',
                    color: theme.colorScheme.secondary,
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 24),
                Text('Upcoming bookings',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.event_available,
                              size: 48,
                              color:
                                  theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('No upcoming bookings',
                              style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            'Your reservations will appear here',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme
                                    .colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Past bookings',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.history,
                              size: 48,
                              color:
                                  theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('No past bookings',
                              style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
