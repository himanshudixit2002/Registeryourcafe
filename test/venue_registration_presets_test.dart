import 'package:flutter_test/flutter_test.dart';
import 'package:registeryourcafe/models/company_module_visibility.dart';
import 'package:registeryourcafe/models/venue_kind.dart';

void main() {
  test('registrationModuleBullets: gaming includes leaderboard & tournaments', () {
    final bullets = CompanyModuleVisibility.registrationModuleBullets(
      VenueKind.gamingCafe,
    );
    expect(bullets, contains('Leaderboard & rankings'));
    expect(bullets, contains('Tournaments & events'));
  });

  test('registrationModuleBullets: dining omits leaderboard & tournaments', () {
    final bullets = CompanyModuleVisibility.registrationModuleBullets(
      VenueKind.diningCafe,
    );
    expect(bullets, isNot(contains('Leaderboard & rankings')));
    expect(bullets, isNot(contains('Tournaments & events')));
    expect(bullets, contains('Café orders & kitchen'));
  });

  test('registrationModuleBullets: restaurant omits merchandise vs dining', () {
    final dining = CompanyModuleVisibility.registrationModuleBullets(
      VenueKind.diningCafe,
    );
    final restaurant = CompanyModuleVisibility.registrationModuleBullets(
      VenueKind.restaurantCafe,
    );
    expect(dining, contains('Merchandise & retail'));
    expect(restaurant, isNot(contains('Merchandise & retail')));
  });

  test('VenueKind registration copy differs by template', () {
    expect(
      VenueKind.gamingCafe.registrationHeadline,
      contains('gaming'),
    );
    expect(VenueKind.diningCafe.companyNameFieldHint, isNotEmpty);
    expect(VenueKind.restaurantCafe.registrationFocusNote, isNotEmpty);
  });

  test('registrationModuleBullets match presetFor flags for all VenueKind', () {
    for (final kind in VenueKind.values) {
      final m = CompanyModuleVisibility.presetFor(kind);
      final bullets = CompanyModuleVisibility.registrationModuleBullets(kind);
      void expectLine(String needle, bool enabled) {
        final has = bullets.any((b) => b.contains(needle));
        expect(has, enabled, reason: '$kind / $needle');
      }

      expectLine('Dashboard', m.dashboard);
      expectLine('Live floor', m.tables);
      expectLine('Café orders', m.cafe);
      expectLine('Sales', m.sales);
      expectLine('Inventory', m.inventory);
      expectLine('Customers', m.customers);
      expectLine('Loyalty', m.loyalty);
      expectLine('Merchandise', m.merchandise);
      expectLine('Leaderboard', m.leaderboard);
      expectLine('Tournaments', m.tournaments);
    }
  });

  test('landing template ids map to distinct VenueKind storage names', () {
    expect(VenueKind.gamingCafe.storageName, 'gamingCafe');
    expect(VenueKind.diningCafe.storageName, 'diningCafe');
    expect(VenueKind.restaurantCafe.storageName, 'restaurantCafe');
    expect(VenueKind.values.map((k) => k.storageName).toSet().length, 3);
  });
}
