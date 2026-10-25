import '../auth/effective_permissions.dart';
import '../models/app_user.dart';
import '../models/company_module_visibility.dart';
import '../models/venue_kind.dart';
import 'shell_route_titles.dart';
import 'shell_venue_order.dart';
import 'shell_visibility.dart';

/// Mirrors [_MainScreenState._visibleScreens] in `workspace_main_screen.dart` so other
/// features can jump to a tab by title.
List<String> visibleShellRouteTitles({
  required UserRole? role,
  required CompanyModuleVisibility modules,
  EffectivePermissions? permissions,
  VenueKind venueKind = VenueKind.gamingCafe,
}) {
  final filtered = ShellRouteTitles.kNavOrder
      .where(
        (title) => isShellTitleVisible(
          title: title,
          modules: modules,
          permissions: permissions,
          legacyRole: role,
        ),
      )
      .toList();

  orderDashboardFirst<String>(
    items: filtered,
    isDashboard: (t) => t == ShellRouteTitles.dashboard,
    shouldPrioritizeDashboard: shouldPrioritizeDashboard(
      permissions: permissions,
      legacyRole: role,
    ),
  );

  orderVisibleShellRoutesForVenue(filtered, venueKind);

  return filtered;
}

int? shellRouteIndexForTitle({
  required UserRole? role,
  required CompanyModuleVisibility modules,
  required String title,
  EffectivePermissions? permissions,
  VenueKind venueKind = VenueKind.gamingCafe,
}) {
  final titles = visibleShellRouteTitles(
    role: role,
    modules: modules,
    permissions: permissions,
    venueKind: venueKind,
  );
  final i = titles.indexOf(title);
  return i >= 0 ? i : null;
}
