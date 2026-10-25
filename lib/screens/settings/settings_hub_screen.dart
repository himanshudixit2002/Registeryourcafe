import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

import '../../auth/permission_id.dart';
import '../../models/company_module_visibility.dart';
import '../../models/venue_kind.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../models/user_ui_prefs.dart';
import '../../providers/user_ui_prefs_provider.dart';
import '../../services/company_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../admin/create_staff_screen.dart';
import '../admin/staff_management_screen.dart';
import '../leaderboard/leaderboard_settings_screen.dart';
import '../loyalty/loyalty_settings_screen.dart';
import '../tables/table_settings_screen.dart';
import '../customers/membership_types_settings_screen.dart';
import '../tables/table_types_settings_screen.dart';
import '../admin/audit_log_screen.dart';
import '../admin/shift_management_screen.dart';
import 'edit_company_profile_screen.dart';
import 'floor_booking_requests_screen.dart';
import 'public_discovery_settings_screen.dart';
import 'qr_code_generator_screen.dart';
import 'public_menu_editor_screen.dart';
import 'roles/company_roles_list_screen.dart';
import 'tax_settings_screen.dart';
import 'diagnostics_screen.dart';
import '../debug/widget_catalog_screen.dart';
import 'export_screen.dart';
import 'communication_settings_screen.dart';
import 'subscription_screen.dart';
import '../help/help_center_screen.dart';

class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final perms = ref.watchResolvedPermissions();
    final canManageModules = perms.can(PermissionIds.settingsModules);
    final canManageRoles = perms.can(PermissionIds.settingsRoles);
    final canInviteStaff = perms.can(PermissionIds.staffInvite);
    final canOpenTableSettings = perms.canOpenTableSettingsScreens();
    final canOpenTableTypesSettings = perms.canOpenTableTypesSettings();
    final canOpenMembershipPlans = perms.canOpenMembershipTypesSettings();
    final prefs = ref.watch(userUiPrefsProvider);
    final modulesAsync = ref.watch(companyModuleVisibilityProvider);
    final profileAsync = ref.watch(companyProfileProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final canOwnerCreateStaffAccounts = canInviteStaff &&
        appUser != null &&
        isRegisteredCompanyOwner(
          profileAsync.valueOrNull?.ownerUid,
          appUser.uid,
        );
    final venueKind = ref.watch(venueKindProvider);
    final workspaceModules = ref.watch(workspaceModuleVisibilityProvider);
    final canConfigureLoyalty = perms.canConfigureLoyaltySettings();
    final showDiagnosticsEntry = kDebugMode ||
        isRegisteredCompanyOwner(
          profileAsync.valueOrNull?.ownerUid,
          appUser?.uid ?? '',
        );
    final hasFeatureSettingsTiles =
        venueKind == VenueKind.gamingCafe ||
        (workspaceModules.loyalty && canConfigureLoyalty) ||
        canOpenTableSettings ||
        canOpenTableTypesSettings ||
        canOpenMembershipPlans;
    final isDesktop = AppTheme.isDesktop(context);

    Future<void> persistModules(CompanyModuleVisibility next) async {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) return;
      try {
        await saveCompanyModuleVisibility(
          tenant,
          next.forVenueKind(ref.read(venueKindProvider)),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not save modules: $e')));
        }
      }
    }

    return Scaffold(
      body: CustomScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        slivers: [
          SliverAppBar.large(
            floating: false,
            pinned: true,
            title: const Text('Settings'),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              0,
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingXLarge + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionLabel(context, 'Venue'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: profileAsync.when(
                    data: (p) => ListTile(
                      leading: Icon(p.venueKind.outlinedIcon, color: theme.colorScheme.primary),
                      title: Text(
                        p.venueKind.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${p.venueKind.shortDescription} '
                        'Tap to change the venue template.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      trailing: canManageModules
                          ? Icon(Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurfaceVariant)
                          : null,
                      onTap: canManageModules
                          ? () => _showVenueKindPicker(
                              context, ref, p.venueKind)
                          : null,
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppTheme.kSpacingLarge),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
                      child: Text(
                        'Could not load venue type: $e',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.kSpacingSmall),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _linkTile(
                    context,
                    icon: Icons.edit_outlined,
                    title: 'Edit company profile',
                    subtitle:
                        'Name, description, address, hours, logo, and social links',
                    onTap: () => Navigator.of(context).push(
                      AppMaterialPageRoute<void>(
                        builder: (_) => const EditCompanyProfileScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.kSpacingSmall),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _linkTile(
                    context,
                    icon: Icons.workspace_premium_outlined,
                    title: 'Subscription & billing',
                    subtitle: 'View plan, limits, and upgrade options',
                    onTap: () => Navigator.of(context).push(
                      AppMaterialPageRoute<void>(
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.kSpacingLarge),
                if (canManageModules) ...[
                  _sectionLabel(context, 'Public discovery'),
                  _sectionHint(context, _publicDiscoverySectionHint(venueKind)),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _linkTile(
                          context,
                          icon: Icons.public_outlined,
                          title: 'Public landing listing',
                          subtitle: _publicLandingListingSubtitle(venueKind),
                          onTap: () => Navigator.of(context).push(
                            AppMaterialPageRoute<void>(
                              builder: (_) =>
                                  const PublicDiscoverySettingsScreen(),
                            ),
                          ),
                        ),
                        _divider(theme),
                        _linkTile(
                          context,
                          icon: Icons.restaurant_menu_outlined,
                          title: 'Public menu',
                          subtitle: _publicMenuEditorSubtitle(
                            profileAsync.valueOrNull?.venueKind,
                          ),
                          onTap: () => Navigator.of(context).push(
                            AppMaterialPageRoute<void>(
                              builder: (_) => const PublicMenuEditorScreen(),
                            ),
                          ),
                        ),
                        _divider(theme),
                        _linkTile(
                          context,
                          icon: Icons.event_seat_outlined,
                          title: 'Floor booking requests',
                          subtitle: _floorBookingRequestsSubtitle(venueKind),
                          onTap: () => Navigator.of(context).push(
                            AppMaterialPageRoute<void>(
                              builder: (_) =>
                                  const FloorBookingRequestsScreen(),
                            ),
                          ),
                        ),
                        _divider(theme),
                        _linkTile(
                          context,
                          icon: Icons.qr_code_2_outlined,
                          title: 'QR codes',
                          subtitle: 'Generate QR codes for venue, menu, and individual tables',
                          onTap: () => Navigator.of(context).push(
                            AppMaterialPageRoute<void>(
                              builder: (_) => const QrCodeGeneratorScreen(),
                            ),
                          ),
                        ),
                        _divider(theme),
                        _linkTile(
                          context,
                          icon: Icons.message_outlined,
                          title: 'Message templates',
                          subtitle: 'WhatsApp message templates for customer communication',
                          onTap: () => Navigator.of(context).push(
                            AppMaterialPageRoute<void>(
                              builder: (_) => const CommunicationSettingsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.kSpacingLarge),
                ],
                if (canManageModules) ...[
                  _sectionLabel(context, 'Venue modules'),
                  _sectionHint(context, _venueModulesSectionHint(venueKind)),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: modulesAsync.when(
                      data: (m) => Column(
                        children: venueKind == VenueKind.gamingCafe
                            ? _gamingModuleTiles(
                                context,
                                theme,
                                m,
                                persistModules,
                              )
                            : _diningStyleModuleTiles(
                                context,
                                theme,
                                venueKind,
                                m,
                                persistModules,
                              ),
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppTheme.kSpacingLarge),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
                        child: Text(
                          'Could not load module settings: $e',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.kSpacingLarge),
                ],
                if (hasFeatureSettingsTiles) ...[
                  _sectionLabel(context, 'Feature settings'),
                  _sectionHint(context, _featureSettingsSectionHint(venueKind)),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Builder(
                      builder: (ctx) {
                        final gaming = venueKind == VenueKind.gamingCafe;
                        final tiles = <Widget>[];
                        if (gaming) {
                          tiles.add(
                            _linkTile(
                              ctx,
                              icon: Icons.leaderboard_outlined,
                              title: 'Leaderboard',
                              subtitle: 'Points, table types, and display',
                              onTap: () => Navigator.of(ctx).push(
                                AppMaterialPageRoute<void>(
                                  builder: (_) =>
                                      const LeaderboardSettingsScreen(),
                                ),
                              ),
                            ),
                          );
                        }
                        if (workspaceModules.loyalty && canConfigureLoyalty) {
                          if (tiles.isNotEmpty) tiles.add(_divider(theme));
                          tiles.add(
                            _linkTile(
                              ctx,
                              icon: Icons.card_giftcard_outlined,
                              title: 'Loyalty',
                              subtitle: 'Points conversion and rewards',
                              onTap: () => Navigator.of(ctx).push(
                                AppMaterialPageRoute<void>(
                                  builder: (_) => const LoyaltySettingsScreen(),
                                ),
                              ),
                            ),
                          );
                        }
                        if (canOpenTableSettings || canOpenTableTypesSettings) {
                          if (tiles.isNotEmpty) tiles.add(_divider(theme));
                          if (canOpenTableSettings) {
                            tiles.add(
                              _linkTile(
                                ctx,
                                icon: Icons.table_restaurant_outlined,
                                title: _tablesFeatureTitle(venueKind),
                                subtitle: _tablesFeatureSubtitle(venueKind),
                                onTap: () => Navigator.of(ctx).push(
                                  AppMaterialPageRoute<void>(
                                    builder: (_) => const TableSettingsScreen(),
                                  ),
                                ),
                              ),
                            );
                          }
                          if (canOpenTableSettings && canOpenTableTypesSettings) {
                            tiles.add(_divider(theme));
                          }
                          if (canOpenTableTypesSettings) {
                            tiles.add(
                              _linkTile(
                                ctx,
                                icon: Icons.category_outlined,
                                title: 'Table types',
                                subtitle: gaming
                                    ? 'Labels, icons, and tournament categories'
                                    : 'Labels and icons for the table grid',
                                onTap: () => Navigator.of(ctx).push(
                                  AppMaterialPageRoute<void>(
                                    builder: (_) =>
                                        const TableTypesSettingsScreen(),
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                        if (canOpenMembershipPlans) {
                          if (tiles.isNotEmpty) tiles.add(_divider(theme));
                          tiles.add(
                            _linkTile(
                              ctx,
                              icon: Icons.workspace_premium_outlined,
                              title: 'Membership plans',
                              subtitle:
                                  'Fees, credits, discounts, and card prefixes',
                              onTap: () => Navigator.of(ctx).push(
                                AppMaterialPageRoute<void>(
                                  builder: (_) =>
                                      const MembershipTypesSettingsScreen(),
                                ),
                              ),
                            ),
                          );
                        }
                        if (tiles.isNotEmpty) tiles.add(_divider(theme));
                        tiles.add(
                          _linkTile(
                            ctx,
                            icon: Icons.receipt_long_outlined,
                            title: 'Tax & invoices',
                            subtitle: 'GST/tax rates, invoice prefix, and numbering',
                            onTap: () => Navigator.of(ctx).push(
                              AppMaterialPageRoute<void>(
                                builder: (_) => const TaxSettingsScreen(),
                              ),
                            ),
                          ),
                        );
                        return Column(children: tiles);
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.kSpacingLarge),
                ],
                if (canInviteStaff || canManageRoles) ...[
                  _sectionLabel(context, 'Staff & access'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        if (canInviteStaff)
                          _linkTile(
                            context,
                            icon: Icons.person_add_alt_1_rounded,
                            title: 'Create staff account',
                            subtitle: canOwnerCreateStaffAccounts
                                ? 'Invite team members to this venue'
                                : 'Only the company owner can create sign-in accounts',
                            onTap: () {
                              if (canOwnerCreateStaffAccounts) {
                                Navigator.of(context).push(
                                  AppMaterialPageRoute<void>(
                                    builder: (_) => const CreateStaffScreen(),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Only the company owner can create staff sign-in accounts.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        if (canInviteStaff && canManageRoles) _divider(theme),
                        if (canManageRoles)
                          _linkTile(
                            context,
                            icon: Icons.admin_panel_settings_outlined,
                            title: 'Roles & permissions',
                            subtitle: 'Who can see modules and perform actions',
                            onTap: () => Navigator.of(context).push(
                              AppMaterialPageRoute<void>(
                                builder: (_) => const CompanyRolesListScreen(),
                              ),
                            ),
                          ),
                        if (canInviteStaff || canManageRoles) _divider(theme),
                        if (canInviteStaff || canManageRoles)
                          _linkTile(
                            context,
                            icon: Icons.groups_outlined,
                            title: 'Staff directory',
                            subtitle:
                                'View all team members, change roles, activate or deactivate',
                            onTap: () => Navigator.of(context).push(
                              AppMaterialPageRoute<void>(
                                builder: (_) =>
                                    const StaffManagementScreen(),
                              ),
                            ),
                          ),
                        _divider(theme),
                        _linkTile(
                          context,
                          icon: Icons.history_outlined,
                          title: 'Audit log',
                          subtitle: 'Track all significant workspace actions',
                          onTap: () => Navigator.of(context).push(
                            AppMaterialPageRoute<void>(
                              builder: (_) => const AuditLogScreen(),
                            ),
                          ),
                        ),
                        _divider(theme),
                        _linkTile(
                          context,
                          icon: Icons.schedule_outlined,
                          title: 'Shift management',
                          subtitle:
                              'Schedule shifts, track clock-in/out, hours worked',
                          onTap: () => Navigator.of(context).push(
                            AppMaterialPageRoute<void>(
                              builder: (_) =>
                                  const ShiftManagementScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.kSpacingLarge),
                ],
                _sectionLabel(context, 'Data'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _linkTile(
                    context,
                    icon: Icons.file_download_outlined,
                    title: 'Export data',
                    subtitle: 'Export customers, sessions, inventory, and expenses as CSV',
                    onTap: () => Navigator.of(context).push(
                      AppMaterialPageRoute<void>(
                        builder: (_) => const ExportScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.kSpacingLarge),
                _sectionLabel(context, 'Support'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _linkTile(
                    context,
                    icon: Icons.help_outline,
                    title: 'Help center',
                    subtitle: 'FAQs, guides, and support tickets',
                    onTap: () => Navigator.of(context).push(
                      AppMaterialPageRoute<void>(
                        builder: (_) => const HelpCenterScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.kSpacingLarge),
                _sectionLabel(context, 'My display'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.kSpacingMedium,
                          AppTheme.kSpacingMedium,
                          AppTheme.kSpacingMedium,
                          AppTheme.kSpacingSmall,
                        ),
                        child: Text(
                          'Appearance',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.kSpacingMedium,
                        ),
                        child: SegmentedButton<UiThemePreference>(
                          segments: const [
                            ButtonSegment<UiThemePreference>(
                              value: UiThemePreference.system,
                              label: Text('System'),
                              icon: Icon(Icons.brightness_auto, size: 18),
                            ),
                            ButtonSegment<UiThemePreference>(
                              value: UiThemePreference.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode_outlined, size: 18),
                            ),
                            ButtonSegment<UiThemePreference>(
                              value: UiThemePreference.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode_outlined, size: 18),
                            ),
                          ],
                          selected: {prefs.themePreference},
                          onSelectionChanged: (s) {
                            if (s.isEmpty) return;
                            ref
                                .read(userUiPrefsProvider.notifier)
                                .setThemePreference(s.first);
                          },
                        ),
                      ),
                      const SizedBox(height: AppTheme.kSpacingSmall),
                      _divider(theme),
                      SwitchListTile(
                        secondary: Icon(
                          Icons.density_small_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        title: const Text('Compact lists'),
                        subtitle: Text(_compactListsSubtitle(venueKind)),
                        value: prefs.compactListDensity,
                        onChanged: (v) => ref
                            .read(userUiPrefsProvider.notifier)
                            .setCompactListDensity(v),
                      ),
                    ],
                  ),
                ),
                if (kDebugMode || showDiagnosticsEntry) ...[
                  const SizedBox(height: AppTheme.kSpacingLarge),
                  _sectionLabel(
                    context,
                    kDebugMode ? 'Developer' : 'Support',
                  ),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        if (kDebugMode) ...[
                          _linkTile(
                            context,
                            icon: Icons.widgets_outlined,
                            title: 'Widget catalog',
                            subtitle:
                                'Preview shared components in light and dark',
                            onTap: () => Navigator.of(context).push(
                              AppMaterialPageRoute<void>(
                                builder: (_) => const WidgetCatalogScreen(),
                              ),
                            ),
                          ),
                          if (showDiagnosticsEntry) _divider(theme),
                        ],
                        if (showDiagnosticsEntry)
                          _linkTile(
                            context,
                            icon: Icons.bug_report_outlined,
                            title: 'Diagnostics',
                            subtitle:
                                'Copy recent app errors for support (this device only)',
                            onTap: () => Navigator.of(context).push(
                              AppMaterialPageRoute<void>(
                                builder: (_) => const DiagnosticsScreen(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showVenueKindPicker(
    BuildContext context,
    WidgetRef ref,
    VenueKind currentKind,
  ) async {
    final theme = Theme.of(context);
    final picked = await showDialog<VenueKind>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change venue type'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              'This changes the venue template. Module presets will be re-applied.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final k in VenueKind.values)
            RadioListTile<VenueKind>(
              value: k,
              groupValue: currentKind,
              title: Text(k.label),
              subtitle:
                  Text(k.shortDescription, style: theme.textTheme.bodySmall),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (picked == null || picked == currentKind || !context.mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm change'),
        content: Text(
          'Switch from "${currentKind.label}" to "${picked.label}"? '
          'Module defaults will be re-applied for the new template.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    try {
      await CompanyService(tenant).changeVenueKind(
        picked,
        reapplyModulePreset: true,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Venue changed to ${picked.label}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change venue: $e')),
        );
      }
    }
  }

  static Widget _sectionHint(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        right: 4,
        bottom: AppTheme.kSpacingSmall,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
    );
  }

  static String _publicDiscoverySectionHint(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return 'Guest-facing listing: events, menu, live floor, and optional table holds.';
      case VenueKind.diningCafe:
        return 'Guest-facing listing: menu, live seating, and table requests — no esports tabs.';
      case VenueKind.restaurantCafe:
        return 'Guest-facing listing: food & drink menu, floor, and seating requests.';
    }
  }

  static String _publicLandingListingSubtitle(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return 'Discover card, live floor mirror, venue tabs (About, Menu, Events, Live floor), '
            'and guest table booking requests.';
      case VenueKind.diningCafe:
        return 'Discover card, Menu and Live floor tabs, and guest seating requests.';
      case VenueKind.restaurantCafe:
        return 'Discover card, Menu and Live floor tabs, and guest table requests.';
    }
  }

  static String _floorBookingRequestsSubtitle(VenueKind kind) {
    const base =
        'Approve or decline holds; guests only see Reserved times, not contact details.';
    switch (kind) {
      case VenueKind.gamingCafe:
        return 'From the public Live floor tab. $base';
      case VenueKind.diningCafe:
        return 'From the public Live seating tab. $base';
      case VenueKind.restaurantCafe:
        return 'From the public Live floor tab. $base';
    }
  }

  static String _venueModulesSectionHint(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return 'Turn workspace tabs on or off. Leaderboard and tournaments are gaming-focused; '
            'loyalty is optional and can also be used in dining or restaurant venues.';
      case VenueKind.diningCafe:
        return 'Tabs are ordered for dining: kitchen and seating near the top. Gaming-only modules are not used.';
      case VenueKind.restaurantCafe:
        return 'Tabs are ordered for restaurant operations. Gaming competition modules stay hidden for this category.';
    }
  }

  static String _featureSettingsSectionHint(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return 'Fine-tune leaderboard, loyalty, tables, and membership for a gaming venue.';
      case VenueKind.diningCafe:
        return 'Seating, table types, kitchen flow, membership, and optional loyalty. Leaderboard and tournaments are for gaming cafés only.';
      case VenueKind.restaurantCafe:
        return 'Tables, service, kitchen, membership, and optional loyalty. Leaderboard and tournaments stay off for this venue type.';
    }
  }

  static String _tablesFeatureTitle(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return 'Tables & billing';
      case VenueKind.diningCafe:
      case VenueKind.restaurantCafe:
        return 'Tables & seating';
    }
  }

  static String _tablesFeatureSubtitle(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return 'Table grid, hourly rates, sessions, and billing defaults.';
      case VenueKind.diningCafe:
        return 'Seating list, dining sessions, and table defaults.';
      case VenueKind.restaurantCafe:
        return 'Floor tables, dining sessions, and service defaults.';
    }
  }

  static String _compactListsSubtitle(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return 'Tighter rows on customers, cafe orders, and similar lists.';
      case VenueKind.diningCafe:
      case VenueKind.restaurantCafe:
        return 'Tighter rows on customers, kitchen orders, and similar lists.';
    }
  }

  static List<Widget> _gamingModuleTiles(
    BuildContext context,
    ThemeData theme,
    CompanyModuleVisibility m,
    Future<void> Function(CompanyModuleVisibility) persistModules,
  ) {
    return [
      _moduleSwitch(
        context,
        label: 'Dashboard',
        subtitle: 'Overview, sales snapshot, and tournament widgets when enabled',
        value: m.dashboard,
        onChanged: (v) => persistModules(m.copyWith(dashboard: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Sales',
        subtitle: 'Register, history, and refunds',
        value: m.sales,
        onChanged: (v) => persistModules(m.copyWith(sales: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Inventory',
        subtitle: 'Stock, receipts, and catalog',
        value: m.inventory,
        onChanged: (v) => persistModules(m.copyWith(inventory: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Leaderboard',
        subtitle: 'Points, standings, and game stats',
        value: m.leaderboard,
        onChanged: (v) => persistModules(m.copyWith(leaderboard: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Loyalty',
        subtitle: 'Rewards and point conversion',
        value: m.loyalty,
        onChanged: (v) => persistModules(m.copyWith(loyalty: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Tournaments',
        subtitle: 'Brackets, registrations, and events',
        value: m.tournaments,
        onChanged: (v) => persistModules(m.copyWith(tournaments: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Merchandise',
        subtitle: 'Retail orders and catalog',
        value: m.merchandise,
        onChanged: (v) => persistModules(m.copyWith(merchandise: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Cafe',
        subtitle: 'Kitchen queue and cafe orders',
        value: m.cafe,
        onChanged: (v) => persistModules(m.copyWith(cafe: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Customers',
        subtitle: 'Directory, credits, and memberships',
        value: m.customers,
        onChanged: (v) => persistModules(m.copyWith(customers: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Tables',
        subtitle: 'Grid, hourly billing, and PTL sessions',
        value: m.tables,
        onChanged: (v) => persistModules(m.copyWith(tables: v)),
      ),
    ];
  }

  static List<Widget> _diningStyleModuleTiles(
    BuildContext context,
    ThemeData theme,
    VenueKind venueKind,
    CompanyModuleVisibility m,
    Future<void> Function(CompanyModuleVisibility) persistModules,
  ) {
    final cafeSub = venueKind == VenueKind.restaurantCafe
        ? 'Kitchen, bar, and floor orders'
        : 'Kitchen queue, courses, and dine-in orders';
    final tablesSub = venueKind == VenueKind.restaurantCafe
        ? 'Tables, seating, and dining sessions'
        : 'Seating map and dining sessions';

    return [
      _moduleSwitch(
        context,
        label: 'Dashboard',
        subtitle: 'Sales and kitchen snapshot',
        value: m.dashboard,
        onChanged: (v) => persistModules(m.copyWith(dashboard: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Sales',
        subtitle: 'Register, history, and refunds',
        value: m.sales,
        onChanged: (v) => persistModules(m.copyWith(sales: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Cafe',
        subtitle: cafeSub,
        value: m.cafe,
        onChanged: (v) => persistModules(m.copyWith(cafe: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Tables',
        subtitle: tablesSub,
        value: m.tables,
        onChanged: (v) => persistModules(m.copyWith(tables: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Customers',
        subtitle: 'Guests, credits, and membership cards',
        value: m.customers,
        onChanged: (v) => persistModules(m.copyWith(customers: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Merchandise',
        subtitle: 'Retail and add-on sales',
        value: m.merchandise,
        onChanged: (v) => persistModules(m.copyWith(merchandise: v)),
      ),
      _divider(theme),
      _moduleSwitch(
        context,
        label: 'Inventory',
        subtitle: 'Stock and purchasing',
        value: m.inventory,
        onChanged: (v) => persistModules(m.copyWith(inventory: v)),
      ),
    ];
  }

  static String _publicMenuEditorSubtitle(VenueKind? kind) {
    const noCounts =
        'Guests see names, descriptions, and prices only — never inventory counts.';
    switch (kind) {
      case VenueKind.gamingCafe:
        return '$noCounts Ideal for snacks and drinks alongside your events tab.';
      case VenueKind.diningCafe:
        return '$noCounts Shown on the Menu tab for dining cafés.';
      case VenueKind.restaurantCafe:
        return '$noCounts Shown on the Menu tab for restaurant-style venues.';
      case null:
        return noCounts;
    }
  }

  static Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppTheme.kSpacingSmall),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  static Widget _divider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 1,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
    );
  }

  static Widget _moduleSwitch(
    BuildContext context, {
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return SwitchListTile(
      secondary: Icon(Icons.widgets_outlined, color: theme.colorScheme.primary),
      title: Text(label),
      subtitle: Text(
        subtitle ?? 'Shown in navigation for your team',
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  static Widget _linkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.kSpacingMedium,
        vertical: AppTheme.kSpacingSmall,
      ),
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
