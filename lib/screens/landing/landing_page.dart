import 'package:firebase_auth/firebase_auth.dart';
import 'package:registeryourcafe/branding/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/google_auth_service.dart';
import '../../utils/ui_helpers.dart';

import '../../models/venue_kind.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/register_company_screen.dart';
import 'landing_bookings_tab.dart';
import 'landing_home_tab.dart';
import 'landing_orders_tab.dart';
import 'landing_profile_tab.dart';
import 'landing_search_tab.dart';

export 'landing_providers.dart';

/// Public marketing shell: **Home** · **Search** · **Bookings** · **Orders** · **Profile**
/// with swipe + animated tab sync.
class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int i) {
    if (i == _index) return;
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _navigateLogin() {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    try {
      final result = await GoogleAuthService().signInWithGoogle();
      if (result == null || !mounted) return;
      ref.invalidate(authStateChangesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $e')),
        );
      }
    }
  }

  Future<void> _pickVenueAndRegister() async {
    final kind = await showModalBottomSheet<VenueKind>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'Choose a workspace template',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'You can adjust modules later in Settings. This only sets the starting layout.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
              for (final k in VenueKind.values)
                ListTile(
                  leading: Icon(k.outlinedIcon),
                  title: Text(k.label),
                  subtitle: Text(
                    k.shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  onTap: () => Navigator.pop(ctx, k),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (kind != null && mounted) {
      _navigateRegister(kind);
    }
  }

  void _navigateRegister(VenueKind venueKind) {
    final fbUser = FirebaseAuth.instance.currentUser;
    final isExistingUser = fbUser != null && !fbUser.isAnonymous;
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RegisterCompanyScreen(
              venueKind: venueKind,
              prefilledName: isExistingUser ? fbUser.displayName : null,
              prefilledEmail: isExistingUser ? fbUser.email : null,
              isGoogleUser: isExistingUser,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;
    ref.watch(authStateChangesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Image.asset(
              AppAssets.appLogo,
              height: isMobile ? 28 : 32,
              filterQuality: FilterQuality.medium,
            ),
            if (!isMobile) ...[
              const SizedBox(width: 10),
              Text(
                'Registeryourcafe',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (FirebaseAuth.instance.currentUser == null || FirebaseAuth.instance.currentUser!.isAnonymous) ...[
            TextButton(
              onPressed: _pickVenueAndRegister,
              child: const Text('Register'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton.tonal(
                onPressed: _navigateLogin,
                child: Text(isMobile ? 'Login' : 'Sign in'),
              ),
            ),
          ] else ...[
            TextButton(
              onPressed: _pickVenueAndRegister,
              child: const Text('Register venue'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _goToPage(4),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                      ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                      : null,
                  child: FirebaseAuth.instance.currentUser?.photoURL == null
                      ? Icon(Icons.person, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer)
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Home'),
                      icon: Icon(Icons.home_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Search'),
                      icon: Icon(Icons.search_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('Bookings'),
                      icon: Icon(Icons.calendar_month_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: 3,
                      label: Text('Orders'),
                      icon: Icon(Icons.receipt_long_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: 4,
                      label: Text('Profile'),
                      icon: Icon(Icons.person_outline_rounded, size: 18),
                    ),
                  ],
                  selected: {_index},
                  onSelectionChanged: (s) => _goToPage(s.first),
                ),
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                RepaintBoundary(child: FadeInWidget(delay: const Duration(milliseconds: 100), child: const _LandingHomePage())),
                RepaintBoundary(child: FadeInWidget(delay: const Duration(milliseconds: 150), child: const LandingSearchTab())),
                RepaintBoundary(
                  child: FadeInWidget(delay: const Duration(milliseconds: 150), child: LandingBookingsTab(onLogin: _navigateLogin, onBrowseVenues: () => _goToPage(1))),
                ),
                RepaintBoundary(
                  child: FadeInWidget(delay: const Duration(milliseconds: 150), child: LandingOrdersTab(onLogin: _navigateLogin, onBrowseMenus: () => _goToPage(1))),
                ),
                RepaintBoundary(
                  child: FadeInWidget(delay: const Duration(milliseconds: 150), child: _LandingProfilePage()),
                ),
              ],
            ),
          ),
          if (isMobile)
            NavigationBar(
              height: 64,
              selectedIndex: _index,
              onDestinationSelected: _goToPage,
              animationDuration: const Duration(milliseconds: 280),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Bridges [LandingHomeTab] callbacks to parent navigation (cannot be const).
class _LandingHomePage extends ConsumerWidget {
  const _LandingHomePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.findAncestorStateOfType<_LandingPageState>();
    return LandingHomeTab(
      onGoLive: () => state?._goToPage(1),
      onLogin: () => state?._navigateLogin(),
      onRegisterWithVenue: (kind) => state?._navigateRegister(kind),
    );
  }
}

/// Bridges [LandingProfileTab] callbacks to parent navigation.
class _LandingProfilePage extends ConsumerWidget {
  const _LandingProfilePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.findAncestorStateOfType<_LandingPageState>();
    return LandingProfileTab(
      onLogin: () => state?._navigateLogin(),
      onRegister: () => state?._pickVenueAndRegister(),
      onGoogleSignIn: () => state?._signInWithGoogle(),
      onGoToBookings: () => state?._goToPage(2),
      onGoToOrders: () => state?._goToPage(3),
      onGoToSearch: () => state?._goToPage(1),
    );
  }
}
