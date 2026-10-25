/// Canonical workspace tab titles. Must match [MainScreen] `_allScreens` exactly.
abstract final class ShellRouteTitles {
  static const tables = 'Tables';
  static const cafe = 'Cafe';
  static const customers = 'Customers';
  static const tournaments = 'Tournaments';
  static const dashboard = 'Dashboard';
  static const sales = 'Sales';
  static const merchandise = 'Merchandise';
  static const inventory = 'Inventory';
  static const leaderboard = 'Leaderboard';
  static const loyalty = 'Loyalty';
  static const settings = 'Settings';
  static const profile = 'Profile';

  /// Same order as shell navigation definitions in [MainScreen] (`workspace_main_screen.dart`).
  static const List<String> kNavOrder = [
    tables,
    cafe,
    customers,
    tournaments,
    dashboard,
    sales,
    merchandise,
    inventory,
    leaderboard,
    loyalty,
    settings,
    profile,
  ];
}
