import '../navigation/shell_route_titles.dart';

/// Stable permission keys for company-scoped RBAC (Firestore + client checks).
abstract final class PermissionIds {
  static const navDashboard = 'nav.dashboard';
  static const navSales = 'nav.sales';
  static const navInventory = 'nav.inventory';
  static const navLeaderboard = 'nav.leaderboard';
  static const navLoyalty = 'nav.loyalty';
  static const navTournaments = 'nav.tournaments';
  static const navMerchandise = 'nav.merchandise';
  static const navCafe = 'nav.cafe';
  static const navCustomers = 'nav.customers';
  static const navTables = 'nav.tables';

  static const opsRefund = 'ops.refund';
  static const opsTableConfigure = 'ops.table_configure';
  /// Edit table type definitions (labels/icons) under Settings — narrower than full table configure.
  static const opsTableTypesConfigure = 'ops.table_types_configure';
  static const opsSessionAdmin = 'ops.session_admin';
  static const opsSessionsHistory = 'ops.sessions_history';
  static const opsCustomersAdmin = 'ops.customers_admin';
  /// Edit membership plans under Settings (narrower than full customer admin).
  static const opsMembershipTypesConfigure = 'ops.membership_types_configure';
  static const opsCafeAdmin = 'ops.cafe_admin';
  static const opsMerchandiseManage = 'ops.merchandise_manage';
  static const opsLoyaltyConfigure = 'ops.loyalty_configure';
  /// Redeem loyalty points for customer credits (narrower than configuring rules).
  static const opsLoyaltyConvert = 'ops.loyalty_convert';
  static const opsLeaderboardManage = 'ops.leaderboard_manage';
  static const opsTournamentManage = 'ops.tournament_manage';

  static const settingsModules = 'settings.modules';
  static const settingsRoles = 'settings.roles';
  static const staffInvite = 'staff.invite';

  /// All defined permissions (for owner role and tests).
  static const List<String> all = [
    navDashboard,
    navSales,
    navInventory,
    navLeaderboard,
    navLoyalty,
    navTournaments,
    navMerchandise,
    navCafe,
    navCustomers,
    navTables,
    opsRefund,
    opsTableConfigure,
    opsTableTypesConfigure,
    opsSessionAdmin,
    opsSessionsHistory,
    opsCustomersAdmin,
    opsMembershipTypesConfigure,
    opsCafeAdmin,
    opsMerchandiseManage,
    opsLoyaltyConfigure,
    opsLoyaltyConvert,
    opsLeaderboardManage,
    opsTournamentManage,
    settingsModules,
    settingsRoles,
    staffInvite,
  ];

  static String? navPermissionForShellTitle(String title) {
    switch (title) {
      case ShellRouteTitles.dashboard:
        return navDashboard;
      case ShellRouteTitles.sales:
        return navSales;
      case ShellRouteTitles.inventory:
        return navInventory;
      case ShellRouteTitles.leaderboard:
        return navLeaderboard;
      case ShellRouteTitles.loyalty:
        return navLoyalty;
      case ShellRouteTitles.tournaments:
        return navTournaments;
      case ShellRouteTitles.merchandise:
        return navMerchandise;
      case ShellRouteTitles.cafe:
        return navCafe;
      case ShellRouteTitles.customers:
        return navCustomers;
      case ShellRouteTitles.tables:
        return navTables;
      case ShellRouteTitles.settings:
      case ShellRouteTitles.profile:
        return null;
      default:
        return null;
    }
  }
}
