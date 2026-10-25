import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class LandingOrdersTab extends ConsumerWidget {
  final VoidCallback onLogin;
  final VoidCallback? onBrowseMenus;

  const LandingOrdersTab({super.key, required this.onLogin, this.onBrowseMenus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;
    final fbUser = FirebaseAuth.instance.currentUser;
    final isSignedIn = fbUser != null && !fbUser.isAnonymous;

    if (!isSignedIn) return _buildSignInPrompt(context, theme, isMobile);
    return _buildEmptyOrders(context, theme, isMobile);
  }

  Widget _buildSignInPrompt(BuildContext context, ThemeData theme, bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48),
        child: FadeInWidget(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, size: 48, color: theme.colorScheme.tertiary),
              ),
              const SizedBox(height: 20),
              Text('Your Orders', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Sign in to track your food orders, view order history, and quickly reorder your favourites.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Sign in to continue'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrders(BuildContext context, ThemeData theme, bool isMobile) {
    final pad = isMobile ? AppTheme.kSpacingMedium : AppTheme.kSpacingXLarge;
    return SingleChildScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeInWidget(
            child: Text('My orders', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          FadeInWidget(
            delay: const Duration(milliseconds: 100),
            child: Text('Track active orders and reorder favourites',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 24),
          FadeInWidget(
            delay: const Duration(milliseconds: 200),
            child: AppCard(
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_bag_outlined, size: 40, color: theme.colorScheme.tertiary),
                ),
                const SizedBox(height: 16),
                Text('No orders yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Visit a venue menu to place your first order. Your order history and favourites will appear here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onBrowseMenus,
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                  label: const Text('Browse menus'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
