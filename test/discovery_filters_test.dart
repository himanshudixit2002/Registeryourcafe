import 'package:flutter_test/flutter_test.dart';
import 'package:registeryourcafe/models/public_venue_listing.dart';
import 'package:registeryourcafe/models/venue_kind.dart';
import 'package:registeryourcafe/screens/landing/discovery_filters.dart';

PublicVenueListing _v({
  required String id,
  required String name,
  VenueKind kind = VenueKind.gamingCafe,
  String? tagline,
  String? address,
  String? city,
  String? area,
  String? phone,
  String? cover,
  DateTime? updated,
  List<String> tags = const [],
}) {
  return PublicVenueListing(
    companyId: id,
    displayName: name,
    venueKind: kind,
    tagline: tagline,
    showOnDiscovery: true,
    address: address,
    phone: phone,
    coverImageUrl: cover,
    updatedAt: updated,
    city: city,
    area: area,
    discoveryTags: tags,
  );
}

void main() {
  final venues = [
    _v(id: 'a', name: 'Alpha Gaming', kind: VenueKind.gamingCafe, updated: DateTime(2025, 1, 1)),
    _v(
      id: 'b',
      name: 'Beta Bistro',
      kind: VenueKind.restaurantCafe,
      tagline: 'Italian',
      address: 'Main St',
      city: 'Mumbai',
      phone: '123',
      cover: 'https://x',
      updated: DateTime(2025, 6, 1),
      tags: ['italian', 'outdoor'],
    ),
    _v(
      id: 'c',
      name: 'Cafe Gamma',
      kind: VenueKind.diningCafe,
      area: 'Koramangala',
      tags: ['coffee'],
    ),
  ];

  test('empty kinds and query returns all sorted by name A-Z', () {
    const f = DiscoveryFilters();
    final out = applyDiscoveryQuery(venues, '', f);
    expect(out.map((e) => e.companyId).toList(), ['a', 'b', 'c']);
  });

  test('kind filter gaming only', () {
    final f = DiscoveryFilters(kinds: DiscoveryFilters.gamingKinds);
    final out = applyDiscoveryQuery(venues, '', f);
    expect(out.length, 1);
    expect(out.single.companyId, 'a');
  });

  test('food and drink preset kinds', () {
    final f = DiscoveryFilters(kinds: DiscoveryFilters.foodAndDrinkKinds);
    final out = applyDiscoveryQuery(venues, '', f);
    expect(out.map((e) => e.companyId).toList()..sort(), ['b', 'c']);
  });

  test('text search city', () {
    const f = DiscoveryFilters();
    final out = applyDiscoveryQuery(venues, 'mumbai', f);
    expect(out.single.companyId, 'b');
  });

  test('require phone', () {
    const f = DiscoveryFilters(requirePhone: true);
    final out = applyDiscoveryQuery(venues, '', f);
    expect(out.single.companyId, 'b');
  });

  test('selectedTags any match', () {
    final f = DiscoveryFilters(selectedTags: {'italian'});
    final out = applyDiscoveryQuery(venues, '', f);
    expect(out.single.companyId, 'b');
  });

  test('sort recently updated', () {
    const f = DiscoveryFilters(sort: DiscoverySort.recentlyUpdated);
    final out = applyDiscoveryQuery(venues, '', f);
    expect(out.first.companyId, 'b');
    expect(out.last.companyId, 'c');
    expect(out.map((e) => e.companyId).toList(), ['b', 'a', 'c']);
  });

  test('discoveryTagsUnion', () {
    final tags = discoveryTagsUnion(venues);
    expect(tags, ['coffee', 'italian', 'outdoor']);
  });
}
