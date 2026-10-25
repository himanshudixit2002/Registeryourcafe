import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class LandingOrdersTab extends ConsumerWidget {
  final VoidCallback? onLogin;
  const LandingOrdersTab({super.key, this.onLogin});

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
                Text('My orders',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Track active orders and view history',
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
                  child: Text('Active orders',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                FadeInWidget(
                  delay: const Duration(milliseconds: 200),
                  child: AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48,
                              color:
                                  theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('No active orders',
                              style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            'Place an order from a venue menu\n'
                            'and track it here in real-time.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme
                                    .colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
                const SizedBox(height: 24),
                FadeInWidget(
                  delay: const Duration(milliseconds: 300),
                  child: Text('Order history',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                FadeInWidget(
                  delay: const Duration(milliseconds: 400),
                  child: AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              size: 48,
                              color:
                                  theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('No past orders',
                              style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            'Your completed orders will appear here\n'
                            'with the option to reorder.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme
                                    .colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
                const SizedBox(height: 24),
                FadeInWidget(
                  delay: const Duration(milliseconds: 500),
                  child: Text('Quick reorder',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                FadeInWidget(
                  delay: const Duration(milliseconds: 600),
                  child: AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.replay,
                              size: 48,
                              color:
                                  theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            'Your favorite orders will appear here',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
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
