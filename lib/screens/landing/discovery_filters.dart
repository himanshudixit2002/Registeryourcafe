import '../../models/public_venue_listing.dart';
import '../../models/venue_kind.dart';

/// How sorted results are ordered on the discover screen.
enum DiscoverySort {
  nameAsc,
  nameDesc,
  recentlyUpdated,
}

extension DiscoverySortLabel on DiscoverySort {
  String get menuLabel => switch (this) {
        DiscoverySort.nameAsc => 'Name (A–Z)',
        DiscoverySort.nameDesc => 'Name (Z–A)',
        DiscoverySort.recentlyUpdated => 'Recently updated',
      };
}

/// Client-side filters for [publicVenuesProvider] results.
///
/// - [kinds]: empty = all venue kinds; non-empty = must match one of the set.
class DiscoveryFilters {
  const DiscoveryFilters({
    this.kinds = const {},
    this.sort = DiscoverySort.nameAsc,
    this.requireCoverPhoto = false,
    this.requireAddress = false,
    this.requirePhone = false,
    this.selectedTags = const {},
  });

  final Set<VenueKind> kinds;
  final DiscoverySort sort;
  final bool requireCoverPhoto;
  final bool requireAddress;
  final bool requirePhone;

  /// Normalized lowercase tag strings; empty = no tag filter.
  /// A venue matches if it has **any** selected tag.
  final Set<String> selectedTags;

  bool get hasNonDefaultSort => sort != DiscoverySort.nameAsc;

  bool get hasActiveConstraints =>
      kinds.isNotEmpty ||
      requireCoverPhoto ||
      requireAddress ||
      requirePhone ||
      selectedTags.isNotEmpty ||
      hasNonDefaultSort;

  DiscoveryFilters copyWith({
    Set<VenueKind>? kinds,
    DiscoverySort? sort,
    bool? requireCoverPhoto,
    bool? requireAddress,
    bool? requirePhone,
    Set<String>? selectedTags,
  }) {
    return DiscoveryFilters(
      kinds: kinds ?? this.kinds,
      sort: sort ?? this.sort,
      requireCoverPhoto: requireCoverPhoto ?? this.requireCoverPhoto,
      requireAddress: requireAddress ?? this.requireAddress,
      requirePhone: requirePhone ?? this.requirePhone,
      selectedTags: selectedTags ?? this.selectedTags,
    );
  }

  /// Clears kinds, attribute flags, tags, and sort (back to defaults).
  DiscoveryFilters clearAll() => const DiscoveryFilters();

  static const foodAndDrinkKinds = {
    VenueKind.diningCafe,
    VenueKind.restaurantCafe,
  };

  static const gamingKinds = {VenueKind.gamingCafe};
}

/// Filter, then sort. [queryText] matches name, tagline, address, city, area, tags.
List<PublicVenueListing> applyDiscoveryQuery(
  List<PublicVenueListing> all,
  String queryText,
  DiscoveryFilters filters,
) {
  final q = queryText.trim().toLowerCase();

  bool textMatches(PublicVenueListing v) {
    if (q.isEmpty) return true;
    if (v.displayName.toLowerCase().contains(q)) return true;
    if ((v.tagline ?? '').toLowerCase().contains(q)) return true;
    if ((v.address ?? '').toLowerCase().contains(q)) return true;
    if ((v.city ?? '').toLowerCase().contains(q)) return true;
    if ((v.area ?? '').toLowerCase().contains(q)) return true;
    for (final t in v.discoveryTags) {
      if (t.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  bool tagMatches(PublicVenueListing v) {
    if (filters.selectedTags.isEmpty) return true;
    final venueTags = v.discoveryTags.map((t) => t.toLowerCase()).toSet();
    return filters.selectedTags.any(venueTags.contains);
  }

  final list = all.where((v) {
    if (filters.kinds.isNotEmpty && !filters.kinds.contains(v.venueKind)) {
      return false;
    }
    if (filters.requireCoverPhoto &&
        (v.coverImageUrl == null || v.coverImageUrl!.trim().isEmpty)) {
      return false;
    }
    if (filters.requireAddress &&
        (v.address == null || v.address!.trim().isEmpty)) {
      return false;
    }
    if (filters.requirePhone && (v.phone == null || v.phone!.trim().isEmpty)) {
      return false;
    }
    if (!tagMatches(v)) return false;
    if (!textMatches(v)) return false;
    return true;
  }).toList(growable: true);

  switch (filters.sort) {
    case DiscoverySort.nameAsc:
      list.sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
      );
      break;
    case DiscoverySort.nameDesc:
      list.sort(
        (a, b) => b.displayName.toLowerCase().compareTo(
              a.displayName.toLowerCase(),
            ),
      );
      break;
    case DiscoverySort.recentlyUpdated:
      list.sort((a, b) {
        final au = a.updatedAt;
        final bu = b.updatedAt;
        if (au == null && bu == null) {
          return a.displayName.toLowerCase().compareTo(
                b.displayName.toLowerCase(),
              );
        }
        if (au == null) return 1;
        if (bu == null) return -1;
        final c = bu.compareTo(au);
        if (c != 0) return c;
        return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
      });
      break;
  }

  return list;
}

/// Unique normalized tags from listings, sorted alphabetically.
List<String> discoveryTagsUnion(List<PublicVenueListing> venues) {
  final set = <String>{};
  for (final v in venues) {
    for (final t in v.discoveryTags) {
      final n = t.trim().toLowerCase();
      if (n.isNotEmpty) set.add(n);
    }
  }
  final out = set.toList()..sort();
  return out;
}
