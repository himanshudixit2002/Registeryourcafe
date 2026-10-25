import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

class LeaderboardSettings {
  final String id;
  final Map<String, double> defaultPointsByTableType;
  final DateTime createdAt;
  final DateTime updatedAt;

  LeaderboardSettings({
    required this.id,
    required this.defaultPointsByTableType,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get default points for a specific table type
  double getDefaultPoints(String tableType) {
    return defaultPointsByTableType[tableType.toLowerCase()] ?? 10.0;
  }

  /// Factory constructor with default values
  factory LeaderboardSettings.defaults() {
    return LeaderboardSettings(
      id: 'default',
      defaultPointsByTableType: {
        'snooker': 15.0,
        'pool': 10.0,
        'carrom': 8.0,
        'darts': 5.0,
        'ps5': 10.0,
        'other': 10.0,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory LeaderboardSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return LeaderboardSettings.defaults();
    }

    final pointsData =
        data['defaultPointsByTableType'] as Map<String, dynamic>?;
    final Map<String, double> pointsMap = {};

    if (pointsData != null) {
      pointsData.forEach((key, value) {
        pointsMap[key] = parseFirestoreDouble(value);
      });
    }

    return LeaderboardSettings(
      id: doc.id,
      defaultPointsByTableType: pointsMap.isNotEmpty
          ? pointsMap
          : LeaderboardSettings.defaults().defaultPointsByTableType,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'defaultPointsByTableType': defaultPointsByTableType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  LeaderboardSettings copyWith({
    String? id,
    Map<String, double>? defaultPointsByTableType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaderboardSettings(
      id: id ?? this.id,
      defaultPointsByTableType:
          defaultPointsByTableType ?? Map.from(this.defaultPointsByTableType),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
