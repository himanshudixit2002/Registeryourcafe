import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/venue_kind.dart';
import '../navigation/shell_route_titles.dart';
import '../providers/shell_route_title_provider.dart';
import '../screens/admin/create_staff_screen.dart';
import '../screens/settings/public_discovery_settings_screen.dart';
import '../screens/settings/public_menu_editor_screen.dart';
import '../services/post_register_onboarding_prefs.dart';
import '../theme/app_page_transitions.dart';
import '../theme/app_theme.dart';

/// First-launch tips for new company owners after registration.
Future<void> showPostRegisterOnboardingSheet(
  BuildContext context,
  WidgetRef ref, {
  required String companyId,
  required VenueKind venueKind,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      final intro = _quickStartIntro(venueKind);
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Quick start',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  intro,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _QuickStartRow(
                  icon: Icons.tune_rounded,
                  title: 'Workspace modules',
                  subtitle: _modulesSubtitle(venueKind),
                  onTap: () {
                    Navigator.pop(ctx);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      navigateToShellTitleIfVisible(ref, ShellRouteTitles.settings);
                    });
                  },
                ),
                const SizedBox(height: 12),
                _QuickStartRow(
                  icon: Icons.table_bar_rounded,
                  title: 'Tables & floor',
                  subtitle: _tablesSubtitle(venueKind),
                  onTap: () {
                    Navigator.pop(ctx);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      navigateToShellTitleIfVisible(ref, ShellRouteTitles.tables);
                    });
                  },
                ),
                const SizedBox(height: 12),
                _QuickStartRow(
                  icon: Icons.public_rounded,
                  title: 'Public listing',
                  subtitle:
                      'Open discovery settings to appear on the home map when you are ready.',
                  onTap: () {
                    _switchSettingsAndPush(
                      rootContext: context,
                      ref: ref,
                      sheetContext: ctx,
                      page: const PublicDiscoverySettingsScreen(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _QuickStartRow(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Public menu',
                  subtitle:
                      'Curate what guests see (names, descriptions, prices).',
                  onTap: () {
                    _switchSettingsAndPush(
                      rootContext: context,
                      ref: ref,
                      sheetContext: ctx,
                      page: const PublicMenuEditorScreen(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _QuickStartRow(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Invite staff',
                  subtitle:
                      'Create sign-in accounts for your team under Settings.',
                  onTap: () {
                    _switchSettingsAndPush(
                      rootContext: context,
                      ref: ref,
                      sheetContext: ctx,
                      page: const CreateStaffScreen(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  await PostRegisterOnboardingPrefs.markDismissed(companyId);
}

void _switchSettingsAndPush({
  required BuildContext rootContext,
  required WidgetRef ref,
  required BuildContext sheetContext,
  required Widget page,
}) {
  Navigator.pop(sheetContext);
  navigateToShellTitleIfVisible(ref, ShellRouteTitles.settings);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!rootContext.mounted) return;
    Navigator.of(rootContext).push<void>(
      AppMaterialPageRoute<void>(builder: (_) => page),
    );
  });
}

String _quickStartIntro(VenueKind venueKind) {
  switch (venueKind) {
    case VenueKind.gamingCafe:
      return 'Your workspace is ready. Start with the floor, optional public '
          'listing, and team accounts — open anything below from Settings anytime.';
    case VenueKind.diningCafe:
      return 'Your dining workspace is ready. Set up tables, optional guest-facing '
          'listing and menu, then invite staff — all paths open from Settings.';
    case VenueKind.restaurantCafe:
      return 'Your restaurant workspace is ready. Focus on tables and kitchen '
          'flows first; add public listing, menu, and staff when you are ready.';
  }
}

String _modulesSubtitle(VenueKind venueKind) {
  switch (venueKind) {
    case VenueKind.gamingCafe:
      return 'Turn tabs on or off under Settings to match how you operate.';
    case VenueKind.diningCafe:
      return 'Dining template hides esports tabs; tune modules anytime in Settings.';
    case VenueKind.restaurantCafe:
      return 'Restaurant template keeps merchandise off by default — adjust in Settings.';
  }
}

String _tablesSubtitle(VenueKind venueKind) {
  switch (venueKind) {
    case VenueKind.gamingCafe:
      return 'Add or open tables, then start sessions when guests arrive.';
    case VenueKind.diningCafe:
      return 'Use the table grid for seating and dining sessions.';
    case VenueKind.restaurantCafe:
      return 'Manage seated service and orders from the floor.';
  }
}

class _QuickStartRow extends StatelessWidget {
  const _QuickStartRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
