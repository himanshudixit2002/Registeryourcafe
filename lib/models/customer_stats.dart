import '../utils/firestore_utils.dart';

class CustomerStats {
  final int gamesWon;
  final int gamesLost;
  final int gamesDrawn;
  final double totalPointsEarned;
  final double currentLeaderboardPoints;
  final DateTime? lastGameDate;
  final String? lastGameResult; // 'win', 'loss', or 'draw'

  CustomerStats({
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.gamesDrawn = 0,
    this.totalPointsEarned = 0.0,
    this.currentLeaderboardPoints = 0.0,
    this.lastGameDate,
    this.lastGameResult,
  });

  int get totalGames => gamesWon + gamesLost + gamesDrawn;

  double get winRate {
    if (totalGames == 0) return 0.0;
    return (gamesWon / totalGames) * 100;
  }

  factory CustomerStats.fromMap(Map<String, dynamic>? data) {
    if (data == null) return CustomerStats();
    return CustomerStats(
      gamesWon: parseFirestoreInt(data['gamesWon']),
      gamesLost: parseFirestoreInt(data['gamesLost']),
      gamesDrawn: parseFirestoreInt(data['gamesDrawn']),
      totalPointsEarned: parseFirestoreDouble(data['totalPointsEarned']),
      currentLeaderboardPoints: parseFirestoreDouble(
        data['currentLeaderboardPoints'],
      ),
      lastGameDate: data['lastGameDate'] != null
          ? DateTime.parse(data['lastGameDate'] as String)
          : null,
      lastGameResult: data['lastGameResult'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gamesWon': gamesWon,
      'gamesLost': gamesLost,
      'gamesDrawn': gamesDrawn,
      'totalPointsEarned': totalPointsEarned,
      'currentLeaderboardPoints': currentLeaderboardPoints,
      'lastGameDate': lastGameDate?.toIso8601String(),
      'lastGameResult': lastGameResult,
    };
  }

  CustomerStats copyWith({
    int? gamesWon,
    int? gamesLost,
    int? gamesDrawn,
    double? totalPointsEarned,
    double? currentLeaderboardPoints,
    DateTime? lastGameDate,
    String? lastGameResult,
  }) {
    return CustomerStats(
      gamesWon: gamesWon ?? this.gamesWon,
      gamesLost: gamesLost ?? this.gamesLost,
      gamesDrawn: gamesDrawn ?? this.gamesDrawn,
      totalPointsEarned: totalPointsEarned ?? this.totalPointsEarned,
      currentLeaderboardPoints:
          currentLeaderboardPoints ?? this.currentLeaderboardPoints,
      lastGameDate: lastGameDate ?? this.lastGameDate,
      lastGameResult: lastGameResult ?? this.lastGameResult,
    );
  }
}
