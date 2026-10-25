import 'table.dart';
import 'venue_kind.dart';

/// Table list filter and create-table defaults derived from [VenueKind].
extension VenueKindTableDefaults on VenueKind {
  /// Non-gaming venues only use dining tables in the product UX.
  bool get restrictsTablePurposesToDining {
    switch (this) {
      case VenueKind.gamingCafe:
        return false;
      case VenueKind.diningCafe:
      case VenueKind.restaurantCafe:
        return true;
    }
  }

  /// `null` = show gaming and dining tables; dining venues default to dining-only.
  TablePurpose? get defaultTablePurposeFilter {
    switch (this) {
      case VenueKind.gamingCafe:
        return null;
      case VenueKind.diningCafe:
      case VenueKind.restaurantCafe:
        return TablePurpose.dining;
    }
  }

  TablePurpose get defaultPurposeForNewTable {
    switch (this) {
      case VenueKind.gamingCafe:
        return TablePurpose.gaming;
      case VenueKind.diningCafe:
      case VenueKind.restaurantCafe:
        return TablePurpose.dining;
    }
  }
}
