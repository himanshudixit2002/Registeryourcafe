import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/company_module_visibility.dart';
import '../models/company_profile.dart';
import '../models/company_role.dart';
import '../models/venue_kind.dart';
import '../models/venue_ui_config.dart';
import '../navigation/shell_route_titles.dart';
import '../navigation/shell_venue_order.dart';
import '../navigation/shell_visibility.dart';
import '../providers/auth_provider.dart';
import '../providers/company_module_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/shell_route_title_provider.dart';
import '../screens/cafe/cafe_screen.dart';
import '../screens/customers/customer_list_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/inventory/inventory_hub_screen.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/loyalty/loyalty_screen.dart';
import '../screens/merchandise/merchandise_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/settings/settings_hub_screen.dart';
import '../screens/tables/table_grid_screen.dart';
import '../screens/tournament/tournament_list_screen.dart';
import '../services/analytics_service.dart';
import '../services/post_register_onboarding_prefs.dart';
import '../services/printer_service.dart';
import '../theme/app_theme.dart';
import '../theme/shell_chrome.dart';
import '../utils/app_logger.dart';
import '../branding/app_assets.dart';
import '../widgets/bootstrap_error_scaffold.dart';
import '../widgets/notification_bell.dart';
import '../widgets/bootstrap_spinner.dart';
import '../widgets/email_verification_banner.dart';
import '../screens/onboarding/onboarding_wizard_screen.dart';
import '../widgets/workspace_nav_popover.dart';

/// Keeps each visited shell tab mounted (but offstage) so Firestore snapshot
/// listeners are not torn down on every tab change. Disposing a tab while
/// `cloud_firestore_web` is still wiring `onSnapshot` triggers
/// `LateInitializationError` and can corrupt the web client.
class _LazyKeepAliveTabStack extends StatefulWidget {
  const _LazyKeepAliveTabStack({
    required this.currentIndex,
    required this.builders,
  });

  final int currentIndex;
  final List<WidgetBuilder> builders;

  @override
  State<_LazyKeepAliveTabStack> createState() => _LazyKeepAliveTabStackState();
}

class _LazyKeepAliveTabStackState extends State<_LazyKeepAliveTabStack> {
  final Set<int> _mountedTabs = <int>{};

  @override
  void initState() {
    super.initState();
    _mountedTabs.add(_clampIndex(widget.currentIndex));
  }

  @override
  void didUpdateWidget(covariant _LazyKeepAliveTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.builders.length != oldWidget.builders.length) {
      _mountedTabs.removeWhere((i) => i >= widget.builders.length);
    }
    _mountedTabs.add(_clampIndex(widget.currentIndex));
  }

  int _clampIndex(int i) {
    if (widget.builders.isEmpty) return 0;
    return i.clamp(0, widget.builders.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final active = _clampIndex(widget.currentIndex);
    final indices =
        _mountedTabs.where((i) => i < widget.builders.length).toList()..sort();

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        for (final i in indices)
          Offstage(
            offstage: i != active,
            child: TickerMode(
              enabled: i == active,
              child: KeyedSubtree(
                key: ValueKey<int>(i),
                child: RepaintBoundary(child: widget.builders[i](context)),
              ),
            ),
          ),
      ],
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _navOverlayController;
  late AnimationController _railGlowController;
  bool _printerInitialized = false;
  bool _postRegisterOfferInFlight = false;

  /// Bounded auto-retry when [companyProfileProvider] hits permission-denied
  /// right after sign-in (see plan: post-auth Firestore propagation race).
  static const int _kMaxCompanyProfilePermissionRetries = 3;
  int _companyProfilePermissionRetriesDone = 0;
  bool _companyProfilePermissionRetryInFlight = false;

  /// Bottom inset so scrollable tab content clears the floating workspace hub
  /// (tablet / desktop — hub sits bottom-start; handsets use [NavigationBar] instead).
  static const double _kWorkspaceHubBottomInset = 88;

  /// Bottom inset so tab content clears the floating mobile nav pill (not in Scaffold slot).
  static const double _kMobileNavBottomInset = 88;

  /// Matches [Ink] width on the hub button (keep in sync with [_buildDesktopNavHubButton]).
  static const double _kWorkspaceHubSize = 52;

  /// Primary destinations on handset bottom nav before a "More" slot opens the full grid.
  static const int _kMobileBottomNavPrimarySlots = 4;

  final List<
    ({
      String title,
      IconData icon,
      IconData activeIcon,
      WidgetBuilder builder,
      bool isPrimary, // Legacy field; workspace hub is used on all form factors
    })
  >
  _allScreens = [
    (
      title: ShellRouteTitles.tables,
      icon: Icons.table_bar_outlined,
      activeIcon: Icons.table_bar,
      builder: (_) => const TableGridScreen(),
      isPrimary: true,
    ),
    (
      title: ShellRouteTitles.cafe,
      icon: Icons.restaurant_menu_outlined,
      activeIcon: Icons.restaurant_menu,
      builder: (_) => const CafeScreen(),
      isPrimary: true,
    ),
    (
      title: ShellRouteTitles.customers,
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      builder: (_) => const CustomerListScreen(),
      isPrimary: true,
    ),
    (
      title: ShellRouteTitles.tournaments,
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events,
      builder: (_) => const TournamentListScreen(),
      isPrimary: true,
    ),
    (
      title: ShellRouteTitles.dashboard,
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      builder: (_) => const DashboardScreen(),
      isPrimary: false,
    ),
    (
      title: ShellRouteTitles.sales,
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale,
      builder: (_) => const SalesScreen(),
      isPrimary: false,
    ),
    (
      title: ShellRouteTitles.merchandise,
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag,
      builder: (_) => const MerchandiseScreen(),
      isPrimary: false,
    ),
    (
      title: ShellRouteTitles.inventory,
      icon: Icons.warehouse_outlined,
      activeIcon: Icons.warehouse_rounded,
      builder: (_) => const InventoryHubScreen(),
      isPrimary: false,
    ),
    (
      title: ShellRouteTitles.leaderboard,
      icon: Icons.leaderboard_outlined,
      activeIcon: Icons.leaderboard,
      builder: (_) => const LeaderboardScreen(),
      isPrimary: false,
    ),
    (
      title: ShellRouteTitles.loyalty,
      icon: Icons.card_giftcard_outlined,
      activeIcon: Icons.card_giftcard,
      builder: (_) => const LoyaltyScreen(),
      isPrimary: false,
    ),
    (
      title: ShellRouteTitles.settings,
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      builder: (_) => const SettingsHubScreen(),
      isPrimary: false,
    ),
    (
      title: ShellRouteTitles.profile,
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      builder: (_) => const ProfileScreen(),
      isPrimary: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _railGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _navOverlayController.addStatusListener(_syncRailGlow);
    if (!_printerInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _printerInitialized = true;
        PrinterService.clearCache();
        PrinterService.initialize();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navOverlayController.removeStatusListener(_syncRailGlow);
    _navOverlayController.dispose();
    _railGlowController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.emailVerified) return;
    unawaited(() async {
      try {
        await user.reload();
      } catch (_) {}
      if (!mounted) return;
      ref.invalidate(authStateChangesProvider);
    }());
  }

  Future<void> _scheduleCompanyProfilePermissionRetry() async {
    final attempt = _companyProfilePermissionRetriesDone;
    await Future<void>.delayed(
      Duration(milliseconds: 300 + (attempt * 150)),
    );
    if (!mounted) return;
    _companyProfilePermissionRetryInFlight = false;
    ref.invalidate(appUserProvider);
    ref.invalidate(companyProfileProvider);
  }

  void _syncRailGlow(AnimationStatus status) {
    if (status == AnimationStatus.forward || status == AnimationStatus.reverse) {
      _railGlowController.stop();
    } else if (status == AnimationStatus.dismissed) {
      if (!_railGlowController.isAnimating) {
        _railGlowController.repeat(reverse: true);
      }
    }
  }

  void _ensureRailGlowRunning() {
    if (!_railGlowController.isAnimating &&
        _navOverlayController.value == 0) {
      _railGlowController.repeat(reverse: true);
    }
  }

  void _toggleWorkspaceNavOverlay() {
    if (_navOverlayController.isAnimating) return;
    if (_navOverlayController.value == 0) {
      _navOverlayController.forward();
      HapticFeedback.selectionClick();
    } else {
      _navOverlayController.reverse();
      HapticFeedback.selectionClick();
    }
  }

  void _closeWorkspaceNavOverlay() {
    if (_navOverlayController.value > 0) {
      _navOverlayController.reverse();
    }
  }

  /// Tab stack, blur overlay, slide-in module grid; handsets get a floating nav pill in-stack.
  /// Workspace chrome (hub / mobile pill) is merged into descendant [MediaQuery] padding so
  /// scroll views can use full viewport height without a dead full-width band at the bottom.
  Widget _buildWorkspaceShellStack({
    required BuildContext context,
    required ThemeData theme,
    required List<
      ({
        String title,
        IconData icon,
        IconData activeIcon,
        WidgetBuilder builder,
        bool isPrimary,
      })
    >
    screens,
    required int currentIndex,
    required List<WorkspaceNavItem> navItems,
    required double panelWidth,
  }) {
    final mq = MediaQuery.of(context);
    final isHandset = AppTheme.isHandset(context);
    final showFloatingHub = !isHandset;
    final chromeBottom = showFloatingHub
        ? _kWorkspaceHubBottomInset
        : _kMobileNavBottomInset;
    final shellMediaQuery = mq.copyWith(
      padding: mq.padding.copyWith(bottom: mq.padding.bottom + chromeBottom),
      viewPadding: mq.viewPadding.copyWith(
        bottom: mq.viewPadding.bottom + chromeBottom,
      ),
    );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: shellMediaQuery,
            child: _LazyKeepAliveTabStack(
              currentIndex: currentIndex,
              builders: screens.map((s) => s.builder).toList(),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _navOverlayController,
          builder: (context, child) {
            if (_navOverlayController.value == 0) {
              return const SizedBox.shrink();
            }
            final curve = CurvedAnimation(
              parent: _navOverlayController,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeWorkspaceNavOverlay,
                child: FadeTransition(
                  opacity: curve,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 4 * _navOverlayController.value,
                      sigmaY: 4 * _navOverlayController.value,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: 0.14 * _navOverlayController.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _navOverlayController,
          builder: (context, _) {
            if (_navOverlayController.value == 0 &&
                _navOverlayController.status == AnimationStatus.dismissed) {
              return const SizedBox.shrink();
            }
            final slide = CurvedAnimation(
              parent: _navOverlayController,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: panelWidth,
              child: IgnorePointer(
                ignoring: _navOverlayController.value == 0,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1.04, 0),
                    end: Offset.zero,
                  ).animate(slide),
                  child: FadeTransition(
                    opacity: slide,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.94, end: 1).animate(slide),
                      alignment: Alignment.centerLeft,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: panelWidth,
                          child: WorkspaceNavPopover(
                            items: navItems,
                            selectedIndex: currentIndex,
                            onSelected: (i) {
                              ref.read(shellRouteTitleProvider.notifier).state =
                                  screens[i].title;
                              _closeWorkspaceNavOverlay();
                            },
                            onClose: _closeWorkspaceNavOverlay,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (showFloatingHub)
          Positioned(
            left: 16,
            bottom: 20,
            child: SafeArea(
              left: true,
              bottom: true,
              minimum: const EdgeInsets.only(left: 4, bottom: 4),
              child: _buildDesktopNavHubButton(context, theme),
            ),
          ),
        if (isHandset)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildMobileWorkspaceNavigationBar(
              context,
              theme,
              screens,
              currentIndex,
            ),
          ),
      ],
    );
  }

  List<
    ({
      String title,
      IconData icon,
      IconData activeIcon,
      WidgetBuilder builder,
      bool isPrimary,
    })
  >
  _visibleScreens(
    CompanyModuleVisibility modules,
    UserRole? legacyRole,
    EffectivePermissions permissions,
    VenueKind venueKind,
  ) {
    final filtered = _allScreens
        .where(
          (s) => isShellTitleVisible(
            title: s.title,
            modules: modules,
            permissions: permissions,
            legacyRole: legacyRole,
          ),
        )
        .toList();

    orderDashboardFirst(
      items: filtered,
      isDashboard: (s) => s.title == ShellRouteTitles.dashboard,
      shouldPrioritizeDashboard: shouldPrioritizeDashboard(
        permissions: permissions,
        legacyRole: legacyRole,
      ),
    );

    final byTitle = {for (final s in filtered) s.title: s};
    final titles = filtered.map((s) => s.title).toList();
    orderVisibleShellRoutesForVenue(titles, venueKind);
    return titles.map((t) => byTitle[t]!).toList();
  }

  Future<void> _offerPostRegisterIfNeeded(
    BuildContext context,
    WidgetRef ref,
    String companyId,
  ) async {
    if (_postRegisterOfferInFlight) return;
    if (!mounted) return;
    if (await PostRegisterOnboardingPrefs.isDismissed(companyId)) return;
    _postRegisterOfferInFlight = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted || !context.mounted) return;
      if (await PostRegisterOnboardingPrefs.isDismissed(companyId)) return;
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (routeContext) => OnboardingWizardScreen(
            onComplete: () => Navigator.of(routeContext).pop(),
          ),
        ),
      );
      await PostRegisterOnboardingPrefs.markDismissed(companyId);
    } finally {
      _postRegisterOfferInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppUser?>>(appUserProvider, (previous, next) {
      next.whenData((u) {
        if (u == null || !mounted) return;
        final cid = u.companyId;
        if (cid == null || cid.isEmpty) return;
        if (u.resolvedRoleId != SystemRoleIds.owner) return;
        unawaited(_offerPostRegisterIfNeeded(context, ref, cid));
      });
    });

    ref.listen<AsyncValue<CompanyProfile>>(companyProfileProvider, (
      previous,
      next,
    ) {
      if (next.hasValue) {
        _companyProfilePermissionRetriesDone = 0;
        _companyProfilePermissionRetryInFlight = false;
      }
      if (next.hasError &&
          AppLogger.isLikelyFirestorePermissionDenied(next.error!)) {
        final u = ref.read(appUserProvider).valueOrNull;
        AppLogger.debug(
          'companyProfileProvider: permission denied '
          '(uid=${u?.uid}, companyId=${u?.companyId})',
          tag: 'CompanyProfile',
        );
        if (!_companyProfilePermissionRetryInFlight &&
            _companyProfilePermissionRetriesDone <
                _kMaxCompanyProfilePermissionRetries &&
            mounted) {
          _companyProfilePermissionRetryInFlight = true;
          _companyProfilePermissionRetriesDone++;
          setState(() {});
          unawaited(_scheduleCompanyProfilePermissionRetry());
        }
      }
      next.whenData((profile) {
        final prevKind = previous?.valueOrNull?.venueKind;
        if (previous?.hasValue == true && prevKind == profile.venueKind) {
          return;
        }
        unawaited(
          AnalyticsService.setWorkspaceUserProperties(
            venueKindStorage: profile.venueKind.storageName,
          ),
        );
      });
    });

    final userAsync = ref.watch(appUserProvider);
    final theme = Theme.of(context);

    return userAsync.when(
      loading: () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(AppAssets.appLogo, height: 60),
              const SizedBox(height: 20),
              const BootstrapSpinner(),
            ],
          ),
        ),
      ),
      error: (err, stack) {
        final copy = BootstrapFailureCopy.forError(err);
        return BootstrapErrorScaffold(
          title: copy.title,
          userMessage: copy.userMessage,
          errorDetail: err.toString(),
          showSignOut: true,
          onRetry: () {
            ref.invalidate(appUserProvider);
          },
        );
      },
      data: (user) {
        final profileAsync = ref.watch(companyProfileProvider);
        final hasTenant =
            user?.companyId != null && user!.companyId!.trim().isNotEmpty;
        if (hasTenant && profileAsync.isLoading) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(AppAssets.appLogo, height: 60),
                  const SizedBox(height: 20),
                  const BootstrapSpinner(),
                ],
              ),
            ),
          );
        }
        if (hasTenant && profileAsync.hasError) {
          final err = profileAsync.error!;
          final permDenied = AppLogger.isLikelyFirestorePermissionDenied(err);
          final showPermissionRetrySpinner = permDenied &&
              (_companyProfilePermissionRetryInFlight ||
                  _companyProfilePermissionRetriesDone <
                      _kMaxCompanyProfilePermissionRetries);
          if (showPermissionRetrySpinner) {
            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(AppAssets.appLogo, height: 60),
                    const SizedBox(height: 20),
                    const BootstrapSpinner(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Syncing your workspace…',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final copy = BootstrapFailureCopy.forError(err);
          final extraHint = permDenied
              ? ' This often clears up right after sign-in; automatic retries '
                  'already ran. You can tap Try again or sign out and back in.'
              : '';
          return BootstrapErrorScaffold(
            title: copy.title,
            userMessage: '${copy.userMessage}$extraHint',
            errorDetail: err.toString(),
            showSignOut: true,
            onRetry: () {
              _companyProfilePermissionRetriesDone = 0;
              _companyProfilePermissionRetryInFlight = false;
              ref.invalidate(appUserProvider);
              ref.invalidate(companyProfileProvider);
            },
          );
        }

        ref.listen(visibleShellTitlesProvider, (previous, next) {
          final cur = ref.read(shellRouteTitleProvider);
          if (cur != null && !next.contains(cur)) {
            ref.read(shellRouteTitleProvider.notifier).state = next.isNotEmpty
                ? next.first
                : null;
          }
        });

        final role = user?.role;
        final permissions = resolvedEffectivePermissions(
          ref.watch(effectivePermissionsProvider),
          user,
        );
        final modules = ref.watch(workspaceModuleVisibilityProvider);
        final venueKind = ref.watch(venueKindProvider);
        final screens = _visibleScreens(modules, role, permissions, venueKind);
        if (screens.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Workspace')),
            body: const Center(
              child: Text(
                'No workspace modules are available for this account.',
              ),
            ),
          );
        }
        final titles = screens.map((s) => s.title).toList();
        final rawTitle = ref.watch(shellRouteTitleProvider);
        final selectedTitle = (rawTitle != null && titles.contains(rawTitle))
            ? rawTitle
            : titles.first;
        var currentIndex = titles.indexOf(selectedTitle);
        if (currentIndex < 0) {
          currentIndex = 0;
        }
        currentIndex = currentIndex.clamp(0, screens.length - 1);

        final navItems = screens.map((s) {
          final displayLabel = shellTitleDisplayLabel(s.title, venueKind);
          final venueIcons = shellTitleIcons(s.title, venueKind);
          final useVenueIcons = venueIcons.$1 != Icons.circle_outlined;
          return WorkspaceNavItem(
            title: displayLabel,
            icon: useVenueIcons ? venueIcons.$1 : s.icon,
            activeIcon: useVenueIcons ? venueIcons.$2 : s.activeIcon,
          );
        }).toList();
        final screenW = MediaQuery.sizeOf(context).width;
        final panelWidth = math.min(
          420.0,
          screenW * (AppTheme.isHandset(context) ? 0.88 : 0.44),
        );

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildWorkspaceAppBar(
            context,
            theme,
            shellTitleDisplayLabel(screens[currentIndex].title, venueKind),
            user,
            visibleScreens: screens,
            venueKind: venueKind,
          ),
          bottomNavigationBar: null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EmailVerificationBanner(),
              Expanded(
                child: SizedBox.expand(
                  child: _buildWorkspaceShellStack(
                    context: context,
                    theme: theme,
                    screens: screens,
                    currentIndex: currentIndex,
                    navItems: navItems,
                    panelWidth: panelWidth,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Same workspace chrome on phone, tablet, and desktop (scaled for width).
  PreferredSizeWidget _buildWorkspaceAppBar(
    BuildContext context,
    ThemeData theme,
    String screenTitle,
    AppUser? user, {
    required List<
      ({
        String title,
        IconData icon,
        IconData activeIcon,
        WidgetBuilder builder,
        bool isPrimary,
      })
    >
    visibleScreens,
    VenueKind venueKind = VenueKind.gamingCafe,
  }) {
    final isPhoneChrome = AppTheme.isHandset(context);
    final isCompact = isPhoneChrome || AppTheme.isTablet(context);
    final showTopShortcuts =
        !isPhoneChrome &&
        MediaQuery.sizeOf(context).width >= AppTheme.kTabletBreakpoint &&
        visibleScreens.length > 1;
    return AppBar(
      toolbarHeight: isPhoneChrome ? 56 : 72,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(ShellChrome.appBarBottomCornerRadius),
        ),
      ),
      scrolledUnderElevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      centerTitle: false,
      automaticallyImplyLeading: false,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surfaceContainer,
              theme.colorScheme.surfaceContainer,
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.16),
            ),
          ),
        ),
      ),
      foregroundColor: theme.colorScheme.onSurface,
      titleSpacing: isPhoneChrome ? 12 : AppTheme.kSpacingLarge,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Workspace',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  fontSize: isPhoneChrome ? 10 : null,
                ),
              ),
              SizedBox(height: isPhoneChrome ? 1 : 2),
              Text(
                screenTitle,
                style:
                    (isPhoneChrome
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
              ),
            ],
          ),
          if (showTopShortcuts) ...[
            const SizedBox(width: 20),
            Expanded(
              child: _buildWorkspaceTopShortcuts(
                context,
                theme,
                screenTitle,
                visibleScreens,
                venueKind,
              ),
            ),
          ],
        ],
      ),
      actions: [
        const NotificationBell(),
        if (user != null)
          Padding(
            padding: EdgeInsets.only(
              right: isPhoneChrome ? 2 : 4,
              left: 4,
              top: 4,
              bottom: 4,
            ),
            child: Tooltip(
              message: '${user.name} — Open profile',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.42),
                      blurRadius: isCompact ? 10 : 12,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                      blurRadius: isCompact ? 18 : 22,
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      navigateToShellTitleIfVisible(
                        ref,
                        ShellRouteTitles.profile,
                      );
                    },
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: isCompact ? 17 : 19,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.22,
                      ),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: isCompact ? 15 : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (isPhoneChrome)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.14,
                ),
              ),
              icon: Icon(
                Icons.logout_rounded,
                color: theme.colorScheme.primary,
              ),
              tooltip: 'Sign out',
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
              },
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.kSpacingMedium),
            child: FilledButton.tonalIcon(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
              },
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Sign out'),
            ),
          ),
      ],
    );
  }

  static const int _kDesktopShortcutCap = 8;

  Widget _buildWorkspaceTopShortcuts(
    BuildContext context,
    ThemeData theme,
    String currentTitle,
    List<
      ({
        String title,
        IconData icon,
        IconData activeIcon,
        WidgetBuilder builder,
        bool isPrimary,
      })
    >
    screens,
    VenueKind venueKind,
  ) {
    final shortcuts = screens
        .take(_kDesktopShortcutCap)
        .where((s) => shellTitleDisplayLabel(s.title, venueKind) != currentTitle);
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in shortcuts)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(
                  style:
                      TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ).copyWith(
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.hovered)) {
                            return theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            );
                          }
                          return theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.55);
                        }),
                      ),
                  onPressed: () {
                    ref.read(shellRouteTitleProvider.notifier).state = s.title;
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(shellTitleIcons(s.title, venueKind).$1 != Icons.circle_outlined ? shellTitleIcons(s.title, venueKind).$1 : s.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        shellTitleDisplayLabel(s.title, venueKind),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileWorkspaceNavigationBar(
    BuildContext context,
    ThemeData theme,
    List<
      ({
        String title,
        IconData icon,
        IconData activeIcon,
        WidgetBuilder builder,
        bool isPrimary,
      })
    >
    screens,
    int currentIndex,
  ) {
    final n = screens.length;
    final primaryCount = math.min(_kMobileBottomNavPrimarySlots, n);
    final hasMore = n > primaryCount;
    final barLen = hasMore ? primaryCount + 1 : primaryCount;

    final selectedIndex = currentIndex < primaryCount
        ? currentIndex
        : (hasMore ? primaryCount : currentIndex.clamp(0, barLen - 1));

    final cs = theme.colorScheme;
    final indicator = cs.primary.withValues(alpha: 0.22);

    Widget pillItem({
      required IconData icon,
      required IconData activeIcon,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppTheme.kAnimationDurationMedium,
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected ? indicator : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 24,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 76,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Floating pill: width hugs icon destinations only (not full screen).
    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomCenter,
            child: Material(
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              color: cs.surfaceContainer.withValues(alpha: 0.92),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: cs.outlineVariant.withValues(
                    alpha: ShellChrome.mobileNavBorderOpacity,
                  ),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < primaryCount; i++)
                    pillItem(
                      icon: screens[i].icon,
                      activeIcon: screens[i].activeIcon,
                      label: screens[i].title,
                      selected: selectedIndex == i,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(shellRouteTitleProvider.notifier).state =
                            screens[i].title;
                      },
                    ),
                  if (hasMore)
                    pillItem(
                      icon: Icons.apps_outlined,
                      activeIcon: Icons.apps_rounded,
                      label: 'More',
                      selected: selectedIndex == primaryCount,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _toggleWorkspaceNavOverlay();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Floating hub: opens the full workspace module grid (no persistent rail).
  Widget _buildDesktopNavHubButton(BuildContext context, ThemeData theme) {
    _ensureRailGlowRunning();
    final brightness = theme.brightness;
    final primary = theme.colorScheme.primary;
    return AnimatedBuilder(
      animation: Listenable.merge([_navOverlayController, _railGlowController]),
      builder: (context, _) {
        final open = _navOverlayController.value > 0.35;
        final t = open
            ? 0.0
            : Curves.easeInOut.transform(_railGlowController.value);
        final scale = 1.0 + (open ? 0.0 : 0.045 * t);
        final glowA = open ? 0.0 : (0.32 + 0.48 * t);
        final blur1 = open ? 4.0 : (10.0 + 12.0 * t);
        final spread1 = open ? 0.0 : (1.0 + 2.5 * t);
        return Tooltip(
          message: open ? 'Close menu' : 'Workspace modules',
          child: Transform.scale(
            scale: scale,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              elevation: open ? 8 : 4,
              shadowColor: Colors.black.withValues(
                alpha: brightness == Brightness.dark ? 0.45 : 0.18,
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _toggleWorkspaceNavOverlay,
                child: Ink(
                  width: _kWorkspaceHubSize,
                  height: _kWorkspaceHubSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: open ? 0.98 : 0.92,
                        ),
                        theme.colorScheme.surfaceContainerHigh.withValues(
                          alpha: open ? 0.92 : 0.85,
                        ),
                      ],
                    ),
                    border: Border.all(
                      color: primary.withValues(
                        alpha: open ? 0.58 : 0.32 + 0.2 * t,
                      ),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (!open) ...[
                        BoxShadow(
                          color: primary.withValues(alpha: 0.5 * glowA),
                          blurRadius: blur1,
                          spreadRadius: spread1,
                        ),
                        BoxShadow(
                          color: primary.withValues(alpha: 0.22 * glowA),
                          blurRadius: 22 + 8 * t,
                          spreadRadius: 0,
                        ),
                      ],
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: AppTheme.kAnimationDurationMedium,
                      transitionBuilder: (child, anim) {
                        return RotationTransition(
                          turns: Tween<double>(
                            begin: 0.85,
                            end: 1,
                          ).animate(anim),
                          child: FadeTransition(opacity: anim, child: child),
                        );
                      },
                      child: Icon(
                        open ? Icons.close_rounded : Icons.apps_rounded,
                        key: ValueKey<bool>(open),
                        size: 24,
                        color: primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
