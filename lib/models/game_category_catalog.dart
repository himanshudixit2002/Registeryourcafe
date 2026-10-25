import 'package:flutter/material.dart';

import 'table_type_definition.dart';

/// Presentation + ordering for [TableTypeDefinition.gameCategoryKey] values.
abstract final class GameCategoryCatalog {
  static const String allKey = 'all';

  /// Stable tab / editor ordering (must cover [allowedGameCategoryKeys]).
  static const List<String> orderedKeys = [
    'snooker',
    'pool',
    'carrom',
    'darts',
    'ps5',
    'other',
  ];

  static int sortIndex(String key) {
    final i = orderedKeys.indexOf(key);
    return i >= 0 ? i : orderedKeys.length;
  }

  static String normalize(String? raw) =>
      TableTypeDefinition.normalizeGameCategoryKey(raw);

  static String displayName(String key) {
    switch (key) {
      case allKey:
        return 'All Games';
      case 'snooker':
        return 'Snooker';
      case 'pool':
        return 'Pool';
      case 'carrom':
        return 'Carrom';
      case 'darts':
        return 'Darts';
      case 'ps5':
        return 'PS5';
      case 'other':
        return 'Other';
      default:
        return key;
    }
  }

  /// Short label for narrow category chips (e.g. mobile).
  static String shortLabel(String key) {
    switch (key) {
      case allKey:
        return 'All';
      case 'snooker':
        return 'Snook';
      case 'pool':
        return 'Pool';
      case 'carrom':
        return 'Carrom';
      case 'darts':
        return 'Darts';
      case 'ps5':
        return 'PS5';
      case 'other':
        return 'Other';
      default:
        return key.length > 6 ? '${key.substring(0, 6)}…' : key;
    }
  }

  static IconData iconFor(String key) {
    switch (key) {
      case allKey:
        return Icons.grid_view_rounded;
      case 'snooker':
        return Icons.sports_baseball;
      case 'pool':
        return Icons.pool;
      case 'carrom':
        return Icons.games;
      case 'darts':
        return Icons.adjust;
      case 'ps5':
        return Icons.sports_esports;
      case 'other':
        return Icons.sports;
      default:
        return Icons.sports;
    }
  }

  /// Distinct accent for category chips (works in light and dark).
  static Color categoryAccent(String key, ColorScheme cs) {
    switch (key) {
      case 'snooker':
        return cs.tertiary;
      case 'pool':
        return cs.primary;
      case 'carrom':
        return cs.secondary;
      case 'darts':
        return cs.error;
      case 'ps5':
        return cs.secondary;
      case 'other':
        return cs.onSurfaceVariant;
      case allKey:
        return cs.primary;
      default:
        return cs.primary;
    }
  }
}
