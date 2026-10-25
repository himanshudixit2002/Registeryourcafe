import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

class LoyaltySettings {
  final int pointsPerConversion;
  final double creditsPerConversion;
  final double valuePerPoint;
  final int minimumPointsToConvert;
  final bool isEnabled;

  const LoyaltySettings({
    this.pointsPerConversion = 100,
    this.creditsPerConversion = 50,
    this.valuePerPoint = 0.5,
    this.minimumPointsToConvert = 100,
    this.isEnabled = true,
  });

  static const LoyaltySettings defaultSettings = LoyaltySettings();

  Map<String, dynamic> toFirestore() {
    return {
      'pointsPerConversion': pointsPerConversion,
      'creditsPerConversion': creditsPerConversion,
      'valuePerPoint': valuePerPoint,
      'minimumPointsToConvert': minimumPointsToConvert,
      'isEnabled': isEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory LoyaltySettings.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) return const LoyaltySettings();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LoyaltySettings(
      pointsPerConversion: parseFirestoreInt(
        data['pointsPerConversion'],
        fallback: 100,
      ),
      creditsPerConversion: parseFirestoreDouble(
        data['creditsPerConversion'],
        fallback: 50,
      ),
      valuePerPoint: parseFirestoreDouble(data['valuePerPoint'], fallback: 0.5),
      minimumPointsToConvert: parseFirestoreInt(
        data['minimumPointsToConvert'],
        fallback: 100,
      ),
      isEnabled: data['isEnabled'] as bool? ?? true,
    );
  }

  LoyaltySettings copyWith({
    int? pointsPerConversion,
    double? creditsPerConversion,
    double? valuePerPoint,
    int? minimumPointsToConvert,
    bool? isEnabled,
  }) {
    return LoyaltySettings(
      pointsPerConversion: pointsPerConversion ?? this.pointsPerConversion,
      creditsPerConversion: creditsPerConversion ?? this.creditsPerConversion,
      valuePerPoint: valuePerPoint ?? this.valuePerPoint,
      minimumPointsToConvert:
          minimumPointsToConvert ?? this.minimumPointsToConvert,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
