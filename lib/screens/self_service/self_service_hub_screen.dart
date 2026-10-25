import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

class SelfServiceHubScreen extends ConsumerWidget {
  const SelfServiceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Self-service & tools')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.all(AppTheme.isDesktop(context)
            ? AppTheme.kSpacingXLarge
            : AppTheme.kSpacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _featureCard(theme, Icons.self_improvement, 'Self-Checkout Kiosk',
                'Full-screen kiosk mode for customer self-checkout with touch-friendly interface.'),
            const SizedBox(height: 12),
            _featureCard(theme, Icons.tablet_android, 'Table-Side Ordering',
                'Customers order directly from their table using a tablet or their phone via QR code.'),
            const SizedBox(height: 12),
            _featureCard(theme, Icons.tv, 'Digital Menu Board',
                'Large-screen display mode for TV/monitor menu boards in your venue.'),
            const SizedBox(height: 12),
            _featureCard(
                theme,
                Icons.card_membership,
                'Customer Loyalty Dashboard',
                'Self-service portal where customers view points, rewards, and tier status.'),
            const SizedBox(height: 12),
            _featureCard(theme, Icons.location_searching, 'Order Status Tracking',
                'Live order preparation status visible to customers on their device.'),
            const SizedBox(height: 12),
            _featureCard(
                theme,
                Icons.account_balance_wallet,
                'Pre-Payment System',
                'Collect deposits and advance payments for reservations and events.'),
            const SizedBox(height: 12),
            _featureCard(theme, Icons.rate_review, 'Feedback Kiosk',
                'Dedicated feedback collection station at exit with quick-tap ratings.'),
            const SizedBox(height: 24),
            Text('Maintenance & Safety',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            _featureCard(theme, Icons.build, 'Equipment Maintenance',
                'Track equipment service schedules, warranty dates, and repair history.'),
            const SizedBox(height: 12),
            _featureCard(theme, Icons.cleaning_services, 'Cleaning Schedule',
                'Assign and track cleaning tasks by area, shift, and staff member.'),
            const SizedBox(height: 12),
            _featureCard(
                theme,
                Icons.health_and_safety,
                'Health & Safety Checklist',
                'Daily health and safety compliance checklists with sign-off tracking.'),
            const SizedBox(height: 12),
            _featureCard(theme, Icons.cloud, 'Weather Suggestions',
                'Automatic menu and promotion suggestions based on current weather conditions.'),
            const SizedBox(height: 12),
            _featureCard(theme, Icons.auto_awesome, 'AI Business Insights',
                'AI-powered recommendations for pricing, staffing, inventory, and marketing optimization.'),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(
      ThemeData theme, IconData icon, String title, String description) {
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon,
              color: theme.colorScheme.onPrimaryContainer, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(description,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4)),
            ],
          ),
        ),
      ]),
    );
  }
}
