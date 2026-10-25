import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/ui_helpers.dart';
import 'home/sa_home_screen.dart';
import 'cafes/sa_cafes_screen.dart';
import 'users/sa_users_screen.dart';
import 'features/sa_features_screen.dart';
import 'analytics/sa_analytics_screen.dart';
import 'billing/sa_billing_screen.dart';
import 'support/sa_support_screen.dart';
import 'system/sa_system_screen.dart';
import 'reviews/sa_reviews_screen.dart';
import 'guests/sa_guests_screen.dart';
import 'orders/sa_guest_orders_screen.dart';
import 'bookings/sa_bookings_screen.dart';
import 'loyalty/sa_loyalty_screen.dart';

class SuperAdminShell extends ConsumerStatefulWidget {
  const SuperAdminShell({super.key});

  @override
  ConsumerState<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends ConsumerState<SuperAdminShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Home')),
    NavigationRailDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: Text('Cafes')),
    NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Users')),
    NavigationRailDestination(icon: Icon(Icons.toggle_on_outlined), selectedIcon: Icon(Icons.toggle_on), label: Text('Features')),
    NavigationRailDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Analytics')),
    NavigationRailDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: Text('Billing')),
    NavigationRailDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: Text('Support')),
    NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('System')),
    NavigationRailDestination(icon: Icon(Icons.rate_review_outlined), selectedIcon: Icon(Icons.rate_review), label: Text('Reviews')),
    NavigationRailDestination(icon: Icon(Icons.person_search_outlined), selectedIcon: Icon(Icons.person_search), label: Text('Guests')),
    NavigationRailDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: Text('Orders')),
    NavigationRailDestination(icon: Icon(Icons.event_seat_outlined), selectedIcon: Icon(Icons.event_seat), label: Text('Bookings')),
    NavigationRailDestination(icon: Icon(Icons.loyalty_outlined), selectedIcon: Icon(Icons.loyalty), label: Text('Loyalty')),
  ];

  void _navigateTo(int index) => setState(() => _selectedIndex = index);

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return SAHomeScreen(onNavigate: _navigateTo);
      case 1: return const SACafesScreen();
      case 2: return const SAUsersScreen();
      case 3: return const SAFeaturesScreen();
      case 4: return const SAAnalyticsScreen();
      case 5: return const SABillingScreen();
      case 6: return const SASupportScreen();
      case 7: return const SASystemScreen();
      case 8: return const SAReviewsScreen();
      case 9: return const SAGuestsScreen();
      case 10: return const SAGuestOrdersScreen();
      case 11: return const SABookingsScreen();
      case 12: return const SALoyaltyScreen();
      default: return SAHomeScreen(onNavigate: _navigateTo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Icon(Icons.admin_panel_settings, color: theme.colorScheme.primary, size: 32),
                    const SizedBox(height: 4),
                    Text('Admin', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'Sign out',
                      onPressed: () => ref.read(authServiceProvider).signOut(),
                    ),
                  ),
                ),
              ),
              destinations: _destinations,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: FadeInWidget(
                key: ValueKey(_selectedIndex),
                duration: const Duration(milliseconds: 250),
                child: _ScreenErrorBoundary(
                  index: _selectedIndex,
                  onRetry: () => setState(() {}),
                  child: _buildScreen(_selectedIndex),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final mobileIndex = _selectedIndex > 3 ? 4 : _selectedIndex;
    return Scaffold(
      body: FadeInWidget(
        key: ValueKey(_selectedIndex),
        duration: const Duration(milliseconds: 250),
        child: _ScreenErrorBoundary(
          index: _selectedIndex,
          onRetry: () => setState(() {}),
          child: _buildScreen(_selectedIndex),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIndex,
        onDestinationSelected: (i) {
          if (i == 4) {
            _showMoreSheet();
          } else {
            setState(() => _selectedIndex = i);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Cafes'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.toggle_on_outlined), selectedIcon: Icon(Icons.toggle_on), label: 'Features'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  void _showMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.analytics), title: const Text('Analytics'), onTap: () { Navigator.pop(ctx); setState(() => _selectedIndex = 4); }),
              ListTile(leading: const Icon(Icons.payments), title: const Text('Billing'), onTap: () { Navigator.pop(ctx); setState(() => _selectedIndex = 5); }),
              ListTile(leading: const Icon(Icons.support_agent), title: const Text('Support'), onTap: () { Navigator.pop(ctx); setState(() => _selectedIndex = 6); }),
              ListTile(leading: const Icon(Icons.settings), title: const Text('System'), onTap: () { Navigator.pop(ctx); setState(() => _selectedIndex = 7); }),
              ListTile(leading: const Icon(Icons.rate_review), title: const Text('Reviews'), onTap: () { Navigator.pop(ctx); setState(() => _selectedIndex = 8); }),
              ListTile(leading: const Icon(Icons.person_search), title: const Text('Guests'), onTap: () { Navigator.pop(ctx); setState(() => _selectedIndex = 9); }),
              ListTile(leading: const Icon(Icons.shopping_bag), title: const Text('Guest Orders'), onTap: () { Navigator.pop(ctx); setState(() => _selectedIndex = 10); }),
              ListTile(leading: const Icon(Icons.event_seat), title: const Text('Bookings'), onTap: () { Navigator.pop(ctx); setState(() => _selectedIndex = 11); }),
              ListTile(leading: const Icon(Icons.loyalty), title: const Text('Loyalty Programs'), onTap: () { Navigator.pop(ctx); setState(() => _selectedIndex = 12); }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenErrorBoundary extends StatefulWidget {
  final int index;
  final Widget child;
  final VoidCallback onRetry;

  const _ScreenErrorBoundary({
    required this.index,
    required this.child,
    required this.onRetry,
  });

  @override
  State<_ScreenErrorBoundary> createState() => _ScreenErrorBoundaryState();
}

class _ScreenErrorBoundaryState extends State<_ScreenErrorBoundary> {
  Object? _error;

  @override
  void didUpdateWidget(covariant _ScreenErrorBoundary old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _error = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error.toString(),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _error = null);
                  widget.onRetry();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    ErrorWidget.builder = (FlutterErrorDetails details) {
      AppLogger.error(
        'SuperAdmin screen ${ widget.index} crashed',
        tag: 'SuperAdminShell',
        error: details.exception,
        stackTrace: details.stack,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _error = details.exception);
      });
      return const SizedBox.shrink();
    };

    return widget.child;
  }
}
