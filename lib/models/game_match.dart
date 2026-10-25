import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

class GameMatch {
  final String id;
  final String winnerId;
  final String winnerName;
  final String? loserId;
  final String? loserName;
  final double pointsAwarded;
  final String gameType; // snooker, pool, carrom, other
  final String? tableId; // Optional: table where game happened (manual awards)
  final String? tableName;
  final DateTime timestamp;
  final DateTime matchDate; // Alias for timestamp for compatibility
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sessionId; // Reference to table session if from PTL
  final bool isPTLMatch; // True if from PTL session, false if manual award
  final bool isManualEntry; // Alias for !isPTLMatch for compatibility
  final String awardedBy; // User ID who awarded/completed the match
  final String awardedByName; // Name of user who awarded the match
  final String? notes;

  GameMatch({
    required this.id,
    required this.winnerId,
    required this.winnerName,
    this.loserId,
    this.loserName,
    required this.pointsAwarded,
    required this.gameType,
    this.tableId,
    this.tableName,
    required this.timestamp,
    DateTime? matchDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.sessionId,
    required this.isPTLMatch,
    bool? isManualEntry,
    required this.awardedBy,
    required this.awardedByName,
    this.notes,
  }) : matchDate = matchDate ?? timestamp,
       createdAt = createdAt ?? timestamp,
       updatedAt = updatedAt ?? timestamp,
       isManualEntry = isManualEntry ?? !isPTLMatch;

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'winnerId': winnerId,
      'winnerName': winnerName,
      'loserId': loserId,
      'loserName': loserName,
      'pointsAwarded': pointsAwarded,
      'gameType': gameType,
      'tableId': tableId,
      'tableName': tableName,
      'timestamp': Timestamp.fromDate(timestamp),
      'matchDate': Timestamp.fromDate(matchDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'sessionId': sessionId,
      'isPTLMatch': isPTLMatch,
      'isManualEntry': isManualEntry,
      'awardedBy': awardedBy,
      'awardedByName': awardedByName,
      'notes': notes,
    };
  }

  /// Create from Firestore document
  factory GameMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isPTLMatch = data['isPTLMatch'] as bool? ?? false;

    return GameMatch(
      id: doc.id,
      winnerId: data['winnerId'] as String,
      winnerName: data['winnerName'] as String? ?? 'Unknown',
      loserId: data['loserId'] as String?,
      loserName: data['loserName'] as String?,
      pointsAwarded: parseFirestoreDouble(data['pointsAwarded']),
      gameType: data['gameType'] as String? ?? 'snooker',
      tableId: data['tableId'] as String?,
      tableName: data['tableName'] as String?,
      timestamp: timestamp,
      matchDate: (data['matchDate'] as Timestamp?)?.toDate() ?? timestamp,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? timestamp,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? timestamp,
      sessionId: data['sessionId'] as String?,
      isPTLMatch: isPTLMatch,
      isManualEntry: data['isManualEntry'] as bool? ?? !isPTLMatch,
      awardedBy: data['awardedBy'] as String,
      awardedByName: data['awardedByName'] as String? ?? 'System',
      notes: data['notes'] as String?,
    );
  }

  /// Create a copy with updated fields
  GameMatch copyWith({
    String? id,
    String? winnerId,
    String? winnerName,
    String? loserId,
    String? loserName,
    double? pointsAwarded,
    String? gameType,
    DateTime? timestamp,
    DateTime? matchDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sessionId,
    bool? isPTLMatch,
    bool? isManualEntry,
    String? awardedBy,
    String? awardedByName,
    String? notes,
  }) {
    return GameMatch(
      id: id ?? this.id,
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
      loserId: loserId ?? this.loserId,
      loserName: loserName ?? this.loserName,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      gameType: gameType ?? this.gameType,
      timestamp: timestamp ?? this.timestamp,
      matchDate: matchDate ?? this.matchDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sessionId: sessionId ?? this.sessionId,
      isPTLMatch: isPTLMatch ?? this.isPTLMatch,
      isManualEntry: isManualEntry ?? this.isManualEntry,
      awardedBy: awardedBy ?? this.awardedBy,
      awardedByName: awardedByName ?? this.awardedByName,
      notes: notes ?? this.notes,
    );
  }
}
