import 'package:flutter/material.dart';

import 'venue_kind.dart';

/// Centralized UI copy and feature flags per [VenueKind].
/// Consumed by navigation shell, table screens, cafe, customers, and dashboard
/// so venue-type branching lives in one place instead of scattered switches.
extension VenueUiConfig on VenueKind {
  // ── Navigation tab labels ──────────────────────────────────────────

  String get tableTabLabel => switch (this) {
    VenueKind.gamingCafe => 'Tables',
    VenueKind.diningCafe => 'Floor',
    VenueKind.restaurantCafe => 'Floor',
  };

  String get cafeTabLabel => switch (this) {
    VenueKind.gamingCafe => 'Cafe',
    VenueKind.diningCafe => 'Kitchen',
    VenueKind.restaurantCafe => 'Kitchen & Orders',
  };

  String get customerTabLabel => switch (this) {
    VenueKind.gamingCafe => 'Customers',
    VenueKind.diningCafe => 'Guests',
    VenueKind.restaurantCafe => 'Guests',
  };

  // ── Person terminology ─────────────────────────────────────────────

  String get customerSingular => switch (this) {
    VenueKind.gamingCafe => 'customer',
    VenueKind.diningCafe => 'guest',
    VenueKind.restaurantCafe => 'guest',
  };

  String get customerPlural => switch (this) {
    VenueKind.gamingCafe => 'customers',
    VenueKind.diningCafe => 'guests',
    VenueKind.restaurantCafe => 'guests',
  };

  String get customerSingularCapitalized => switch (this) {
    VenueKind.gamingCafe => 'Customer',
    VenueKind.diningCafe => 'Guest',
    VenueKind.restaurantCafe => 'Guest',
  };

  // ── Floor / table labels ───────────────────────────────────────────

  String get floorTitle => switch (this) {
    VenueKind.gamingCafe => 'Gaming Floor',
    VenueKind.diningCafe => 'Dining Floor',
    VenueKind.restaurantCafe => 'Restaurant Floor',
  };

  String get sessionStartCta => switch (this) {
    VenueKind.gamingCafe => 'Start Game',
    VenueKind.diningCafe => 'Seat Guest',
    VenueKind.restaurantCafe => 'Seat Party',
  };

  String get sessionStartCtaMobile => switch (this) {
    VenueKind.gamingCafe => 'Start Game',
    VenueKind.diningCafe => 'Seat',
    VenueKind.restaurantCafe => 'Seat',
  };

  String get emptyFloorMessage => switch (this) {
    VenueKind.gamingCafe => 'No gaming tables configured yet. Add tables in Settings.',
    VenueKind.diningCafe => 'No dining tables set up yet. Add tables in Settings.',
    VenueKind.restaurantCafe => 'No restaurant tables configured yet. Add tables in Settings.',
  };

  String get availableSubtitle => switch (this) {
    VenueKind.gamingCafe => 'Tap to start',
    VenueKind.diningCafe => 'Available',
    VenueKind.restaurantCafe => 'Available',
  };

  // ── Session history labels ─────────────────────────────────────────

  String get sessionHistoryTitle => switch (this) {
    VenueKind.gamingCafe => 'Session History',
    VenueKind.diningCafe => 'Seating History',
    VenueKind.restaurantCafe => 'Service History',
  };

  // ── Table types / settings labels ──────────────────────────────────

  String get tableTypesTitle => switch (this) {
    VenueKind.gamingCafe => 'Table Types',
    VenueKind.diningCafe => 'Seating Types',
    VenueKind.restaurantCafe => 'Table Zones',
  };

  // ── Feature flags ──────────────────────────────────────────────────

  bool get showHourlyRate => this == VenueKind.gamingCafe;

  bool get showGameMode => this == VenueKind.gamingCafe;

  bool get showPurposeFilter => this == VenueKind.gamingCafe;

  bool get showCourseTracking => this == VenueKind.restaurantCafe;

  bool get showReservations => this == VenueKind.restaurantCafe;

  bool get showTournaments => this == VenueKind.gamingCafe;

  bool get showLeaderboard => this == VenueKind.gamingCafe;

  bool get showMerchandise => this != VenueKind.restaurantCafe;

  bool get isGaming => this == VenueKind.gamingCafe;

  bool get isDiningOrRestaurant => this != VenueKind.gamingCafe;

  // ── Tab icons (for navigation shell) ───────────────────────────────

  IconData get tableTabIcon => switch (this) {
    VenueKind.gamingCafe => Icons.table_bar_outlined,
    VenueKind.diningCafe => Icons.table_restaurant_outlined,
    VenueKind.restaurantCafe => Icons.table_restaurant_outlined,
  };

  IconData get tableTabActiveIcon => switch (this) {
    VenueKind.gamingCafe => Icons.table_bar,
    VenueKind.diningCafe => Icons.table_restaurant,
    VenueKind.restaurantCafe => Icons.table_restaurant,
  };

  IconData get cafeTabIcon => switch (this) {
    VenueKind.gamingCafe => Icons.restaurant_menu_outlined,
    VenueKind.diningCafe => Icons.soup_kitchen_outlined,
    VenueKind.restaurantCafe => Icons.soup_kitchen_outlined,
  };

  IconData get cafeTabActiveIcon => switch (this) {
    VenueKind.gamingCafe => Icons.restaurant_menu,
    VenueKind.diningCafe => Icons.soup_kitchen,
    VenueKind.restaurantCafe => Icons.soup_kitchen,
  };

  IconData get customerTabIcon => switch (this) {
    VenueKind.gamingCafe => Icons.people_outline,
    VenueKind.diningCafe => Icons.person_search_outlined,
    VenueKind.restaurantCafe => Icons.person_search_outlined,
  };

  IconData get customerTabActiveIcon => switch (this) {
    VenueKind.gamingCafe => Icons.people,
    VenueKind.diningCafe => Icons.person_search,
    VenueKind.restaurantCafe => Icons.person_search,
  };

  // ── Dashboard KPI labels ───────────────────────────────────────────

  String get revenueKpiLabel => switch (this) {
    VenueKind.gamingCafe => 'Hourly Revenue',
    VenueKind.diningCafe => 'Avg Check Size',
    VenueKind.restaurantCafe => 'Avg Check Size',
  };

  String get activeSessionsLabel => switch (this) {
    VenueKind.gamingCafe => 'Active Sessions',
    VenueKind.diningCafe => 'Seated Tables',
    VenueKind.restaurantCafe => 'Seated Tables',
  };

  // ── Kitchen display labels ─────────────────────────────────────────

  String get kitchenTitle => switch (this) {
    VenueKind.gamingCafe => 'Kitchen Display',
    VenueKind.diningCafe => 'Kitchen Display',
    VenueKind.restaurantCafe => 'Kitchen & Orders',
  };

  // ── Guest order labels ─────────────────────────────────────────────

  String get guestOrdersTitle => switch (this) {
    VenueKind.gamingCafe => 'Public menu orders',
    VenueKind.diningCafe => 'Walk-in guest orders',
    VenueKind.restaurantCafe => 'Online guest orders',
  };

  String get guestOrdersEmpty => switch (this) {
    VenueKind.gamingCafe => 'No pending guest orders. Guests submit from the public Menu tab when discovery is on.',
    VenueKind.diningCafe => 'No pending walk-in orders. Guests can order from the public menu when discovery is enabled.',
    VenueKind.restaurantCafe => 'No pending online orders. Guests can place orders from your public menu page.',
  };

  // ── Checkout ───────────────────────────────────────────────────────

  bool get showTipPrompt => this == VenueKind.restaurantCafe;

  String get checkoutTitle => switch (this) {
    VenueKind.gamingCafe => 'End Session',
    VenueKind.diningCafe => 'Close Table',
    VenueKind.restaurantCafe => 'Close Table',
  };

  // ── Search / filter hint labels ─────────────────────────────────

  String get tableSearchHint => switch (this) {
    VenueKind.gamingCafe => 'Search tables...',
    VenueKind.diningCafe => 'Search floor...',
    VenueKind.restaurantCafe => 'Search floor...',
  };

  String get sessionSearchHint => switch (this) {
    VenueKind.gamingCafe => 'Search sessions...',
    VenueKind.diningCafe => 'Search seatings...',
    VenueKind.restaurantCafe => 'Search services...',
  };

  // ── Floor stats labels ──────────────────────────────────────────

  String get occupiedStatsLabel => switch (this) {
    VenueKind.gamingCafe => 'Active',
    VenueKind.diningCafe => 'Seated',
    VenueKind.restaurantCafe => 'Seated',
  };

  // ── Sales labels ────────────────────────────────────────────────

  String get salesRevenueLabel => switch (this) {
    VenueKind.gamingCafe => 'Table Revenue',
    VenueKind.diningCafe => 'Dining Revenue',
    VenueKind.restaurantCafe => 'Service Revenue',
  };

  String get salesEmptyMessage => switch (this) {
    VenueKind.gamingCafe => 'No gaming session revenue recorded yet.',
    VenueKind.diningCafe => 'No dining revenue recorded yet.',
    VenueKind.restaurantCafe => 'No restaurant revenue recorded yet.',
  };

  // ── Dashboard greetings ─────────────────────────────────────────

  String get dashboardSubtitle => switch (this) {
    VenueKind.gamingCafe => 'Your gaming floor at a glance',
    VenueKind.diningCafe => 'Your dining floor at a glance',
    VenueKind.restaurantCafe => 'Your restaurant at a glance',
  };
}

/// Maps a [ShellRouteTitles] constant to a venue-aware display label.
String shellTitleDisplayLabel(String title, VenueKind kind) {
  switch (title) {
    case 'Tables':
      return kind.tableTabLabel;
    case 'Cafe':
      return kind.cafeTabLabel;
    case 'Customers':
      return kind.customerTabLabel;
    default:
      return title;
  }
}

/// Maps a [ShellRouteTitles] constant to venue-aware icons.
(IconData, IconData) shellTitleIcons(String title, VenueKind kind) {
  switch (title) {
    case 'Tables':
      return (kind.tableTabIcon, kind.tableTabActiveIcon);
    case 'Cafe':
      return (kind.cafeTabIcon, kind.cafeTabActiveIcon);
    case 'Customers':
      return (kind.customerTabIcon, kind.customerTabActiveIcon);
    default:
      return (Icons.circle_outlined, Icons.circle);
  }
}
