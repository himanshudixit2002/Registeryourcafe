import 'package:flutter/material.dart';

/// Persisted on `companies/{id}` as field `venueKind` (string storage name).
enum VenueKind {
  gamingCafe,
  diningCafe,
  restaurantCafe;

  /// Firestore / API value.
  String get storageName => name;

  static VenueKind parse(Object? raw) {
    if (raw == null) return VenueKind.gamingCafe;
    final s = raw.toString();
    final short = s.contains('.') ? s.split('.').last : s;
    switch (short) {
      case 'diningCafe':
        return VenueKind.diningCafe;
      case 'restaurantCafe':
        return VenueKind.restaurantCafe;
      case 'gamingCafe':
      default:
        return VenueKind.gamingCafe;
    }
  }

  String get label {
    switch (this) {
      case VenueKind.gamingCafe:
        return 'Gaming cafe';
      case VenueKind.diningCafe:
        return 'Dining cafe';
      case VenueKind.restaurantCafe:
        return 'Restaurant cafe';
    }
  }

  String get shortDescription {
    switch (this) {
      case VenueKind.gamingCafe:
        return 'Tables, tournaments, leaderboard, and retail.';
      case VenueKind.diningCafe:
        return 'Seating, dining sessions, and kitchen — without esports modules.';
      case VenueKind.restaurantCafe:
        return 'Kitchen and orders first; merchandise tab off by default '
            '(enable in Settings). Tables for seating when you need them.';
    }
  }

  /// Shown on [RegisterCompanyScreen] — tailored to each registration path.
  String get registrationHeadline {
    switch (this) {
      case VenueKind.gamingCafe:
        return 'Create your gaming café';
      case VenueKind.diningCafe:
        return 'Create your dining café';
      case VenueKind.restaurantCafe:
        return 'Create your restaurant workspace';
    }
  }

  /// One-line expectation for owners picking this template.
  String get registrationFocusNote {
    switch (this) {
      case VenueKind.gamingCafe:
        return 'Full workspace: tables, tournaments, leaderboard, loyalty, and retail.';
      case VenueKind.diningCafe:
        return 'Dining-first template: leaderboard and tournaments stay off (toggle later in Settings if you need them).';
      case VenueKind.restaurantCafe:
        return 'Kitchen- and order-first template; merchandise tab off by default (enable in Settings). Tables stay on for seated service.';
    }
  }

  /// Hint for the venue / company name field.
  String get companyNameFieldHint {
    switch (this) {
      case VenueKind.gamingCafe:
        return 'e.g. Downtown Snooker & Esports Lounge';
      case VenueKind.diningCafe:
        return 'e.g. Maple Street Coffee House';
      case VenueKind.restaurantCafe:
        return 'e.g. The Garden Bistro';
    }
  }

  /// Primary `table_type_definitions` id (first entry of `defaultSeedForVenueKind` for this kind).
  /// Keep aligned with `lib/models/table_type_definition.dart` seeds.
  String get defaultTableTypeId {
    switch (this) {
      case VenueKind.gamingCafe:
        return 'snooker';
      case VenueKind.diningCafe:
        return 'cafe_table';
      case VenueKind.restaurantCafe:
        return 'dining_room';
    }
  }

  /// Material icon per venue type -- used across SA, landing, and workspace screens.
  IconData get icon {
    switch (this) {
      case VenueKind.gamingCafe:
        return Icons.sports_esports;
      case VenueKind.diningCafe:
        return Icons.restaurant;
      case VenueKind.restaurantCafe:
        return Icons.storefront;
    }
  }

  IconData get outlinedIcon {
    switch (this) {
      case VenueKind.gamingCafe:
        return Icons.sports_esports_outlined;
      case VenueKind.diningCafe:
        return Icons.restaurant_outlined;
      case VenueKind.restaurantCafe:
        return Icons.storefront_outlined;
    }
  }
}
