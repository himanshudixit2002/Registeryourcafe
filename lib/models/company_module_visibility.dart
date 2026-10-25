import '../auth/permission_id.dart';
import '../navigation/shell_route_titles.dart';
import 'venue_kind.dart';

/// Feature flags stored on `companies/{companyId}` as field `moduleVisibility`.
/// Missing keys default to enabled for backward compatibility.
class CompanyModuleVisibility {
  const CompanyModuleVisibility({
    required this.dashboard,
    required this.sales,
    required this.inventory,
    required this.leaderboard,
    required this.loyalty,
    required this.tournaments,
    required this.merchandise,
    required this.cafe,
    required this.customers,
    required this.tables,
  });

  final bool dashboard;
  final bool sales;
  final bool inventory;
  final bool leaderboard;
  final bool loyalty;
  final bool tournaments;
  final bool merchandise;
  final bool cafe;
  final bool customers;
  final bool tables;

  static const CompanyModuleVisibility defaults = CompanyModuleVisibility(
    dashboard: true,
    sales: true,
    inventory: true,
    leaderboard: true,
    loyalty: true,
    tournaments: true,
    merchandise: true,
    cafe: true,
    customers: true,
    tables: true,
  );

  /// Recommended modules when creating a company of [kind].
  static CompanyModuleVisibility presetFor(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return defaults;
      case VenueKind.diningCafe:
        return const CompanyModuleVisibility(
          dashboard: true,
          sales: true,
          inventory: true,
          leaderboard: false,
          loyalty: true,
          tournaments: false,
          merchandise: true,
          cafe: true,
          customers: true,
          tables: true,
        );
      case VenueKind.restaurantCafe:
        return const CompanyModuleVisibility(
          dashboard: true,
          sales: true,
          inventory: true,
          leaderboard: false,
          loyalty: true,
          tournaments: false,
          merchandise: false,
          cafe: true,
          customers: true,
          tables: true,
        );
    }
  }

  /// User-facing bullets for [RegisterCompanyScreen] (matches [presetFor]).
  static List<String> registrationModuleBullets(VenueKind kind) {
    final m = presetFor(kind);
    final lines = <String>[];
    if (m.dashboard) lines.add('Dashboard & key metrics');
    if (m.tables) lines.add('Live floor & table sessions');
    if (m.cafe) lines.add('Café orders & kitchen');
    if (m.sales) lines.add('Sales & reporting');
    if (m.inventory) lines.add('Inventory, vendors & receipts');
    if (m.customers) lines.add('Customers & membership');
    if (m.loyalty) lines.add('Loyalty & points');
    if (m.merchandise) lines.add('Merchandise & retail');
    if (m.leaderboard) lines.add('Leaderboard & rankings');
    if (m.tournaments) lines.add('Tournaments & events');
    return lines;
  }

  static CompanyModuleVisibility fromFirestoreData(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    final raw = data['moduleVisibility'];
    if (raw is! Map) return defaults;
    final m = Map<String, dynamic>.from(raw);
    bool read(String key) {
      final v = m[key];
      if (v is bool) return v;
      return true;
    }

    return CompanyModuleVisibility(
      dashboard: read('dashboard'),
      sales: read('sales'),
      inventory: read('inventory'),
      leaderboard: read('leaderboard'),
      loyalty: read('loyalty'),
      tournaments: read('tournaments'),
      merchandise: read('merchandise'),
      cafe: read('cafe'),
      customers: read('customers'),
      tables: read('tables'),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'dashboard': dashboard,
      'sales': sales,
      'inventory': inventory,
      'leaderboard': leaderboard,
      'loyalty': loyalty,
      'tournaments': tournaments,
      'merchandise': merchandise,
      'cafe': cafe,
      'customers': customers,
      'tables': tables,
    };
  }

  /// Removes ids for modules that are off (nav + related ops). Settings grants are kept.
  static Set<String> filterPermissionIdsForModules(
    Set<String> permissionIds,
    CompanyModuleVisibility modules,
  ) {
    bool keep(String id) {
      switch (id) {
        case PermissionIds.navDashboard:
          return modules.dashboard;
        case PermissionIds.navSales:
          return modules.sales;
        case PermissionIds.navInventory:
          return modules.inventory;
        case PermissionIds.navLeaderboard:
          return modules.leaderboard;
        case PermissionIds.navLoyalty:
          return modules.loyalty;
        case PermissionIds.navTournaments:
          return modules.tournaments;
        case PermissionIds.navMerchandise:
          return modules.merchandise;
        case PermissionIds.navCafe:
          return modules.cafe;
        case PermissionIds.navCustomers:
          return modules.customers;
        case PermissionIds.navTables:
          return modules.tables;
        case PermissionIds.opsRefund:
          return modules.sales;
        case PermissionIds.opsTableConfigure:
        case PermissionIds.opsTableTypesConfigure:
        case PermissionIds.opsSessionAdmin:
          return modules.tables;
        case PermissionIds.opsSessionsHistory:
          return modules.sales || modules.tables;
        case PermissionIds.opsCustomersAdmin:
        case PermissionIds.opsMembershipTypesConfigure:
          return modules.customers;
        case PermissionIds.opsCafeAdmin:
          return modules.cafe;
        case PermissionIds.opsMerchandiseManage:
          return modules.merchandise;
        case PermissionIds.opsLoyaltyConfigure:
        case PermissionIds.opsLoyaltyConvert:
          return modules.loyalty;
        case PermissionIds.opsLeaderboardManage:
          return modules.leaderboard;
        case PermissionIds.opsTournamentManage:
          return modules.tournaments;
        case PermissionIds.settingsModules:
        case PermissionIds.settingsRoles:
        case PermissionIds.staffInvite:
          return true;
        default:
          return true;
      }
    }

    return permissionIds.where(keep).toSet();
  }

  CompanyModuleVisibility copyWith({
    bool? dashboard,
    bool? sales,
    bool? inventory,
    bool? leaderboard,
    bool? loyalty,
    bool? tournaments,
    bool? merchandise,
    bool? cafe,
    bool? customers,
    bool? tables,
  }) {
    return CompanyModuleVisibility(
      dashboard: dashboard ?? this.dashboard,
      sales: sales ?? this.sales,
      inventory: inventory ?? this.inventory,
      leaderboard: leaderboard ?? this.leaderboard,
      loyalty: loyalty ?? this.loyalty,
      tournaments: tournaments ?? this.tournaments,
      merchandise: merchandise ?? this.merchandise,
      cafe: cafe ?? this.cafe,
      customers: customers ?? this.customers,
      tables: tables ?? this.tables,
    );
  }

  /// Leaderboard and tournaments are **gaming café** features.
  /// Dining and restaurant companies always treat these as off in the app
  /// (navigation, permissions cap, dashboard), regardless of legacy Firestore
  /// toggles. **Loyalty** follows the stored toggle (preset keeps it on for
  /// dining/restaurant) so rewards can still be used outside gaming venues.
  /// Use when resolving workspace visibility; Settings still stores raw toggles
  /// but [forVenueKind] is applied on save.
  CompanyModuleVisibility forVenueKind(VenueKind venueKind) {
    if (venueKind == VenueKind.gamingCafe) return this;
    return copyWith(
      leaderboard: false,
      tournaments: false,
    );
  }

  bool isEnabledForNavTitle(String title) {
    switch (title) {
      case ShellRouteTitles.dashboard:
        return dashboard;
      case ShellRouteTitles.sales:
        return sales;
      case ShellRouteTitles.inventory:
        return inventory;
      case ShellRouteTitles.leaderboard:
        return leaderboard;
      case ShellRouteTitles.loyalty:
        return loyalty;
      case ShellRouteTitles.tournaments:
        return tournaments;
      case ShellRouteTitles.merchandise:
        return merchandise;
      case ShellRouteTitles.cafe:
        return cafe;
      case ShellRouteTitles.customers:
        return customers;
      case ShellRouteTitles.tables:
        return tables;
      case ShellRouteTitles.profile:
      case ShellRouteTitles.settings:
        return true;
      default:
        return true;
    }
  }
}
