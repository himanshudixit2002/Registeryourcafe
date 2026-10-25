import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

class AnalyticsAdvancedScreen extends ConsumerWidget {
  const AnalyticsAdvancedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced analytics')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.all(
            isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(theme, 'Real-Time Dashboard', Icons.speed,
                'Live metrics updating every 30 seconds. Monitor active sessions, pending orders, and revenue as it happens.'),
            const SizedBox(height: 16),
            _section(theme, 'Customer Visit Heatmap', Icons.grid_on,
                'Visualize customer visit patterns by day of week and time of day to optimize staffing and promotions.'),
            const SizedBox(height: 16),
            _section(theme, 'Revenue Prediction', Icons.trending_up,
                'ML-based revenue forecasting using historical data patterns to predict next week/month revenue.'),
            const SizedBox(height: 16),
            _section(theme, 'Churn Risk Analysis', Icons.person_off,
                'Identify customers at risk of leaving based on declining visit frequency and spending patterns.'),
            const SizedBox(height: 16),
            _section(theme, 'Basket Analysis', Icons.shopping_basket,
                'Discover which items are frequently ordered together to create better combos and upsell opportunities.'),
            const SizedBox(height: 16),
            _section(theme, 'Period Comparison', Icons.compare_arrows,
                'Compare performance metrics across different time periods to identify trends and seasonality.'),
            const SizedBox(height: 16),
            _section(theme, 'Custom Report Builder', Icons.dashboard_customize,
                'Build custom reports by selecting metrics, filters, and visualization types to match your needs.'),
            const SizedBox(height: 16),
            _section(theme, 'KPI Alerts', Icons.notifications_active,
                'Set threshold alerts for key metrics. Get notified when revenue drops, wait times increase, or stock runs low.'),
            const SizedBox(height: 16),
            _section(theme, 'Staff Efficiency', Icons.person_search,
                'Track staff performance: orders per hour, average service time, customer ratings by staff member.'),
            const SizedBox(height: 16),
            _section(theme, 'Menu Performance Matrix', Icons.grid_view,
                'Categorize menu items by popularity and profitability: stars, puzzles, plowhorses, and dogs.'),
            const SizedBox(height: 16),
            _section(theme, 'Inventory Turnover', Icons.inventory,
                'Analyze stock turnover rates to optimize ordering and reduce waste from slow-moving items.'),
            const SizedBox(height: 16),
            _section(theme, 'Customer Lifetime Value', Icons.timeline,
                'Calculate the predicted total revenue from each customer over their entire relationship with your cafe.'),
          ],
        ),
      ),
    );
  }

  Widget _section(
      ThemeData theme, String title, IconData icon, String description) {
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
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
