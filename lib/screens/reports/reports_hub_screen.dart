import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.all(AppTheme.isDesktop(context)
            ? AppTheme.kSpacingXLarge
            : AppTheme.kSpacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _reportCard(theme, Icons.today, 'Daily Summary',
                'Automatic end-of-day report with revenue, sessions, and top items'),
            const SizedBox(height: 12),
            _reportCard(theme, Icons.date_range, 'Weekly Performance',
                'Week-over-week comparison of key metrics'),
            const SizedBox(height: 12),
            _reportCard(theme, Icons.calendar_month, 'Monthly Financial',
                'Complete P&L statement and expense breakdown'),
            const SizedBox(height: 12),
            _reportCard(theme, Icons.assessment, 'Quarterly Review',
                'Business review with growth trends and forecasts'),
            const SizedBox(height: 12),
            _reportCard(theme, Icons.summarize, 'Annual Report',
                'Full year-end summary with YoY comparison'),
            const SizedBox(height: 12),
            _reportCard(theme, Icons.dashboard_customize, 'Custom Templates',
                'Build your own report with selected metrics'),
            const SizedBox(height: 12),
            _reportCard(theme, Icons.schedule_send, 'Scheduled Delivery',
                'Auto-send reports to email on a schedule'),
            const SizedBox(height: 12),
            _reportCard(theme, Icons.share, 'Report Sharing',
                'Share reports with team members with permissions'),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(
      ThemeData theme, IconData icon, String title, String description) {
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon,
              color: theme.colorScheme.onPrimaryContainer, size: 22),
        ),
        title: Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(description,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
