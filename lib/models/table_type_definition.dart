import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'table.dart' show kDefaultTableTypeId;
import 'tournament.dart';
import 'venue_kind.dart';
import '../utils/firestore_utils.dart';

/// Tenant-configurable table category (replaces hardcoded [TableType] enum).
///
/// Stored under `companies/{companyId}/table_type_definitions/{id}`.
class TableTypeDefinition {
  final String id;
  final String name;
  final String iconKey;
  final int colorArgb;
  final int sortOrder;
  final bool isArchived;

  /// Groups this type for tournaments and default leaderboard buckets:
  /// `snooker`, `pool`, `carrom`, `darts`, `ps5`, `other`.
  final String gameCategoryKey;

  const TableTypeDefinition({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorArgb,
    required this.sortOrder,
    this.isArchived = false,
    required this.gameCategoryKey,
  });

  Color get color => Color(colorArgb);

  /// PTL backend expects: snooker, pool, carrom, darts, or other.
  String get ptlGameType {
    switch (gameCategoryKey) {
      case 'snooker':
        return 'snooker';
      case 'pool':
        return 'pool';
      case 'carrom':
        return 'carrom';
      case 'darts':
        return 'darts';
      default:
        return 'other';
    }
  }

  static const Set<String> allowedGameCategoryKeys = {
    'snooker',
    'pool',
    'carrom',
    'darts',
    'ps5',
    'other',
  };

  /// Stable order for category pickers (tournament / PTL linkage).
  static const List<String> orderedGameCategoryKeys = [
    'snooker',
    'pool',
    'carrom',
    'darts',
    'ps5',
    'other',
  ];

  static String gameCategoryDisplayLabel(String key) {
    switch (normalizeGameCategoryKey(key)) {
      case 'snooker':
        return 'Snooker';
      case 'pool':
        return 'Pool';
      case 'carrom':
        return 'Carrom';
      case 'darts':
        return 'Darts';
      case 'ps5':
        return 'Console / PS5';
      case 'other':
      default:
        return 'Other';
    }
  }

  static String normalizeGameCategoryKey(String? raw) {
    if (raw == null || raw.isEmpty) return 'other';
    final k = raw.toLowerCase().trim();
    return allowedGameCategoryKeys.contains(k) ? k : 'other';
  }

  /// Gaming venues: cue sports and console types with real [gameCategoryKey] values.
  static List<TableTypeDefinition> gamingDefaultSeed() => [
    TableTypeDefinition(
      id: 'snooker',
      name: 'Snooker',
      iconKey: 'sports_kabaddi',
      colorArgb: 0xFF4CAF50,
      sortOrder: 0,
      gameCategoryKey: 'snooker',
    ),
    TableTypeDefinition(
      id: 'pool',
      name: 'Pool',
      iconKey: 'pool',
      colorArgb: 0xFF2196F3,
      sortOrder: 1,
      gameCategoryKey: 'pool',
    ),
    TableTypeDefinition(
      id: 'carrom',
      name: 'Carrom',
      iconKey: 'sports_handball',
      colorArgb: 0xFF795548,
      sortOrder: 2,
      gameCategoryKey: 'carrom',
    ),
    TableTypeDefinition(
      id: 'darts',
      name: 'Darts',
      iconKey: 'sports_bar',
      colorArgb: 0xFFF44336,
      sortOrder: 3,
      gameCategoryKey: 'darts',
    ),
    TableTypeDefinition(
      id: 'ps5',
      name: 'PS5',
      iconKey: 'sports_esports',
      colorArgb: 0xFF9C27B0,
      sortOrder: 4,
      gameCategoryKey: 'ps5',
    ),
  ];

  /// Dining-café seating labels (display only; [gameCategoryKey] stays `other`).
  static List<TableTypeDefinition> diningCafeDefaultSeed() => [
    TableTypeDefinition(
      id: 'cafe_table',
      name: 'Café table',
      iconKey: 'table_restaurant',
      colorArgb: 0xFF009688,
      sortOrder: 0,
      gameCategoryKey: 'other',
    ),
    TableTypeDefinition(
      id: 'high_top',
      name: 'High top',
      iconKey: 'chair',
      colorArgb: 0xFF2196F3,
      sortOrder: 1,
      gameCategoryKey: 'other',
    ),
    TableTypeDefinition(
      id: 'counter',
      name: 'Counter',
      iconKey: 'coffee',
      colorArgb: 0xFF795548,
      sortOrder: 2,
      gameCategoryKey: 'other',
    ),
    TableTypeDefinition(
      id: 'outdoor',
      name: 'Outdoor seating',
      iconKey: 'deck',
      colorArgb: 0xFF4CAF50,
      sortOrder: 3,
      gameCategoryKey: 'other',
    ),
  ];

  /// Full-service restaurant seating labels (display only).
  static List<TableTypeDefinition> restaurantCafeDefaultSeed() => [
    TableTypeDefinition(
      id: 'dining_room',
      name: 'Dining room',
      iconKey: 'restaurant',
      colorArgb: 0xFF009688,
      sortOrder: 0,
      gameCategoryKey: 'other',
    ),
    TableTypeDefinition(
      id: 'booth',
      name: 'Booth',
      iconKey: 'chair',
      colorArgb: 0xFF3F51B5,
      sortOrder: 1,
      gameCategoryKey: 'other',
    ),
    TableTypeDefinition(
      id: 'bar_seat',
      name: 'Bar seating',
      iconKey: 'local_bar',
      colorArgb: 0xFF795548,
      sortOrder: 2,
      gameCategoryKey: 'other',
    ),
    TableTypeDefinition(
      id: 'patio',
      name: 'Patio',
      iconKey: 'deck',
      colorArgb: 0xFF4CAF50,
      sortOrder: 3,
      gameCategoryKey: 'other',
    ),
  ];

  static List<TableTypeDefinition> defaultSeedForVenueKind(VenueKind kind) {
    switch (kind) {
      case VenueKind.gamingCafe:
        return gamingDefaultSeed();
      case VenueKind.diningCafe:
        return diningCafeDefaultSeed();
      case VenueKind.restaurantCafe:
        return restaurantCafeDefaultSeed();
    }
  }

  /// Document ids from [gamingDefaultSeed] (snooker, pool, carrom, darts, ps5).
  /// If a tenant’s table types are only these and [VenueKind] becomes
  /// dining/restaurant, [TableTypeService] can migrate to the new defaults.
  static Set<String> get gamingTableTypeSeedIdSet =>
      Set<String>.from(gamingDefaultSeed().map((e) => e.id));

  /// Legacy alias — same as [gamingDefaultSeed].
  static List<TableTypeDefinition> defaultSeed() => gamingDefaultSeed();

  factory TableTypeDefinition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return TableTypeDefinition(
        id: doc.id,
        name: doc.id,
        iconKey: 'table_restaurant',
        colorArgb: 0xFF009688,
        sortOrder: 99,
        gameCategoryKey: 'other',
      );
    }
    return TableTypeDefinition(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      iconKey: data['iconKey'] as String? ?? 'table_restaurant',
      colorArgb: parseFirestoreInt(data['colorArgb'], fallback: 0xFF009688),
      sortOrder: parseFirestoreInt(data['sortOrder'], fallback: 99),
      isArchived: data['isArchived'] as bool? ?? false,
      gameCategoryKey: normalizeGameCategoryKey(
        data['gameCategoryKey'] as String?,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'iconKey': iconKey,
      'colorArgb': colorArgb,
      'sortOrder': sortOrder,
      'isArchived': isArchived,
      'gameCategoryKey': gameCategoryKey,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreForCreate() {
    return {...toFirestore(), 'createdAt': FieldValue.serverTimestamp()};
  }

  TableTypeDefinition copyWith({
    String? id,
    String? name,
    String? iconKey,
    int? colorArgb,
    int? sortOrder,
    bool? isArchived,
    String? gameCategoryKey,
  }) {
    return TableTypeDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorArgb: colorArgb ?? this.colorArgb,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      gameCategoryKey: gameCategoryKey != null
          ? normalizeGameCategoryKey(gameCategoryKey)
          : this.gameCategoryKey,
    );
  }
}

TableTypeDefinition? lookupTableType(
  List<TableTypeDefinition> definitions,
  String typeId,
) {
  for (final d in definitions) {
    if (d.id == typeId) return d;
  }
  return null;
}

bool _useFirstActiveTableTypeFallback(String typeId, VenueKind? venueKind) {
  if (typeId.trim().isEmpty || typeId == kDefaultTableTypeId) return true;
  if (venueKind != null &&
      venueKind != VenueKind.gamingCafe &&
      TableTypeDefinition.gamingTableTypeSeedIdSet.contains(typeId)) {
    return true;
  }
  return false;
}

/// Label for UI when [typeId] may be the legacy default ([kDefaultTableTypeId])
/// or a gaming seed id on a non-gaming venue before migration.
String resolveTableTypeDisplayLabel(
  List<TableTypeDefinition> definitions,
  String typeId, {
  VenueKind? venueKind,
}) {
  final found = lookupTableType(definitions, typeId);
  if (found != null) return found.name;
  final active = definitions.where((d) => !d.isArchived).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  if (active.isNotEmpty && _useFirstActiveTableTypeFallback(typeId, venueKind)) {
    return active.first.name;
  }
  return typeId;
}

/// Full definition for icons when [typeId] is only the legacy default.
TableTypeDefinition? resolveTableTypeForDisplay(
  List<TableTypeDefinition> definitions,
  String typeId, {
  VenueKind? venueKind,
}) {
  final hit = lookupTableType(definitions, typeId);
  if (hit != null) return hit;
  final active = definitions.where((d) => !d.isArchived).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  if (active.isNotEmpty && _useFirstActiveTableTypeFallback(typeId, venueKind)) {
    return active.first;
  }
  return null;
}

/// Whether a table's [typeId] can be used for a tournament of [tournamentType].
bool tableTypeMatchesTournament({
  required String typeId,
  required List<TableTypeDefinition> definitions,
  required TournamentGameType tournamentType,
}) {
  if (tournamentType == TournamentGameType.mixed) return true;
  final cat = lookupTableType(definitions, typeId)?.gameCategoryKey ?? 'other';
  switch (tournamentType) {
    case TournamentGameType.snooker:
      return cat == 'snooker';
    case TournamentGameType.pool:
      return cat == 'pool';
    case TournamentGameType.carrom:
      return cat == 'carrom';
    case TournamentGameType.darts:
      return cat == 'darts';
    case TournamentGameType.ps5:
      return cat == 'ps5';
    case TournamentGameType.mixed:
      return true;
  }
}

IconData tableTypeIconFromKey(String? iconKey) {
  switch (iconKey) {
    case 'sports_kabaddi':
      return Icons.sports_kabaddi_outlined;
    case 'pool':
      return Icons.pool_outlined;
    case 'sports_handball':
      return Icons.sports_handball;
    case 'sports_bar':
      return Icons.sports_bar;
    case 'sports_esports':
      return Icons.sports_esports_outlined;
    case 'casino':
      return Icons.casino_outlined;
    case 'emoji_events':
      return Icons.emoji_events_outlined;
    case 'sports_tennis':
      return Icons.sports_tennis_outlined;
    case 'sports_soccer':
      return Icons.sports_soccer_outlined;
    case 'sports_cricket':
      return Icons.sports_cricket_outlined;
    case 'sports_martial_arts':
      return Icons.sports_martial_arts_outlined;
    case 'restaurant':
      return Icons.restaurant_outlined;
    case 'local_bar':
      return Icons.local_bar_outlined;
    case 'coffee':
      return Icons.coffee_outlined;
    case 'deck':
      return Icons.deck_outlined;
    case 'chair':
      return Icons.chair_outlined;
    case 'table_restaurant':
    default:
      return Icons.table_restaurant_outlined;
  }
}

/// Preset icons for the "Manage table types" UI.
const List<(String key, IconData icon, String label)> kTableTypeIconChoices = [
  ('table_restaurant', Icons.table_restaurant_outlined, 'Table'),
  ('sports_kabaddi', Icons.sports_kabaddi_outlined, 'Cue / snooker'),
  ('pool', Icons.pool_outlined, 'Pool'),
  ('sports_handball', Icons.sports_handball, 'Carrom-like'),
  ('sports_bar', Icons.sports_bar, 'Darts / bar'),
  ('sports_esports', Icons.sports_esports_outlined, 'Console / esports'),
  ('casino', Icons.casino_outlined, 'Cards / games'),
  ('emoji_events', Icons.emoji_events_outlined, 'Trophy'),
  ('sports_tennis', Icons.sports_tennis_outlined, 'Racquet'),
  ('sports_soccer', Icons.sports_soccer_outlined, 'Ball'),
  ('sports_cricket', Icons.sports_cricket_outlined, 'Cricket'),
  ('sports_martial_arts', Icons.sports_martial_arts_outlined, 'Combat'),
  ('restaurant', Icons.restaurant_outlined, 'Dining'),
  ('local_bar', Icons.local_bar_outlined, 'Drinks'),
  ('coffee', Icons.coffee_outlined, 'Café'),
  ('deck', Icons.deck_outlined, 'Outdoor'),
  ('chair', Icons.chair_outlined, 'Seating'),
];
