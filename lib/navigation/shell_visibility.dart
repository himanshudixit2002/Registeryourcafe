import '../auth/effective_permissions.dart';
import '../auth/permission_id.dart';
import '../models/app_user.dart';
import '../models/company_module_visibility.dart';
import 'shell_route_titles.dart';

/// Whether a shell item should appear for the user (module toggle + nav permission / legacy role).
bool isShellTitleVisible({
  required String title,
  required CompanyModuleVisibility modules,
  EffectivePermissions? permissions,
  UserRole? legacyRole,
}) {
  if (!modules.isEnabledForNavTitle(title)) return false;
  if (permissions != null) {
    final nav = PermissionIds.navPermissionForShellTitle(title);
    if (nav == null) return true;
    return permissions.can(nav);
  }
  final isAdmin = legacyRole == UserRole.admin;
  final isStaff = legacyRole == UserRole.staff;
  switch (title) {
    case ShellRouteTitles.dashboard:
    case ShellRouteTitles.sales:
    case ShellRouteTitles.inventory:
      return isAdmin;
    case ShellRouteTitles.leaderboard:
    case ShellRouteTitles.tournaments:
    case ShellRouteTitles.loyalty:
    case ShellRouteTitles.settings:
      return isAdmin || isStaff;
    default:
      return true;
  }
}

/// Move Dashboard first when the user has analytics access (legacy: admin).
void orderDashboardFirst<E>({
  required List<E> items,
  required bool Function(E) isDashboard,
  required bool shouldPrioritizeDashboard,
}) {
  if (!shouldPrioritizeDashboard) return;
  final dashIdx = items.indexWhere(isDashboard);
  if (dashIdx > 0) {
    final dash = items.removeAt(dashIdx);
    items.insert(0, dash);
  }
}

bool shouldPrioritizeDashboard({
  EffectivePermissions? permissions,
  UserRole? legacyRole,
}) {
  if (permissions != null) {
    return permissions.can(PermissionIds.navDashboard);
  }
  return legacyRole == UserRole.admin;
}
