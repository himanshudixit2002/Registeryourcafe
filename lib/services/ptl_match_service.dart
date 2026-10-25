import 'package:cloud_firestore/cloud_firestore.dart';
import '../firestore/tenant_firestore.dart';
import '../models/game_match.dart';
import '../models/session.dart';
import '../models/app_user.dart';
import '../models/leaderboard_settings.dart';

class PTLMatchService {
  final TenantRef _tenant;

  PTLMatchService(this._tenant);

  /// Get leaderboard settings from Firestore
  Future<LeaderboardSettings> _getSettings() async {
    try {
      final doc = await _tenant.leaderboardSettings().doc('default').get();

      if (!doc.exists) {
        // Create default settings if they don't exist
        final defaults = LeaderboardSettings.defaults();
        await _tenant
            .leaderboardSettings()
            .doc('default')
            .set(defaults.toFirestore());
        return defaults;
      }

      return LeaderboardSettings.fromFirestore(doc);
    } catch (e) {
      // Return defaults on error
      return LeaderboardSettings.defaults();
    }
  }

  /// Creates match records for PTL sessions when they complete
  Future<void> createPTLMatchRecords({
    required TableSession session,
    required int loserPlayerIndex,
    required AppUser completedBy,
    String gameType = 'snooker',
  }) async {
    if (!session.isPTL ||
        session.playerIds.isEmpty ||
        session.playerNames.isEmpty) {
      throw Exception('Invalid PTL session data');
    }

    if (loserPlayerIndex < 1 || loserPlayerIndex > session.playerIds.length) {
      throw Exception('Invalid loser player index: $loserPlayerIndex');
    }

    final batch = _tenant.db.batch();
    final now = DateTime.now();

    // Get the loser and winners
    final loserIndex = loserPlayerIndex - 1; // Convert 1-based to 0-based
    final loserId = session.playerIds[loserIndex];
    final loserName = session.playerNames[loserIndex];

    // Get configured default points based on game type
    final settings = await _getSettings();
    final defaultPoints = settings.getDefaultPoints(gameType);

    // Calculate points per player (split among winners)
    final winnersCount = session.playerCount! - 1; // Exclude the loser
    final pointsPerPlayer = winnersCount > 0
        ? defaultPoints / winnersCount
        : defaultPoints;

    // Create match records for each winner
    for (int i = 0; i < session.playerIds.length; i++) {
      if (i != loserIndex) {
        // This is a winner
        final winnerId = session.playerIds[i];
        final winnerName = session.playerNames[i];

        // Create match record (attach table context when available)
        final matchRef = _tenant.gameMatches().doc();
        final match = GameMatch(
          id: matchRef.id,
          winnerId: winnerId,
          winnerName: winnerName,
          loserId: loserId,
          loserName: loserName,
          pointsAwarded: pointsPerPlayer,
          sessionId: session.id,
          gameType: gameType,
          tableId: session.tableId,
          tableName: session.tableName,
          timestamp: now,
          matchDate: now,
          awardedBy: completedBy.uid,
          awardedByName: completedBy.name,
          notes: 'PTL Session - Player $loserPlayerIndex lost and paid',
          createdAt: now,
          updatedAt: now,
          isPTLMatch: true, // This is from PTL session
          isManualEntry: false, // This is automatic from session
        );

        batch.set(matchRef, match.toFirestore());

        // Update winner's statistics - both overall and category-specific
        final winnerRef = _tenant.customers().doc(winnerId);
        batch.update(winnerRef, {
          'gameStats.gamesWon': FieldValue.increment(1),
          'gameStats.totalPointsEarned': FieldValue.increment(pointsPerPlayer),
          'gameStats.currentLeaderboardPoints': FieldValue.increment(
            pointsPerPlayer,
          ),
          'gameStats.lastGameDate': now.toIso8601String(),
          'gameStats.lastGameResult': 'win',
          // Category-specific points
          'gameStats.pointsByCategory.$gameType': FieldValue.increment(
            pointsPerPlayer,
          ),
          'gameStats.winsByCategory.$gameType': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Update loser's statistics
    final loserRef = _tenant.customers().doc(loserId);
    batch.update(loserRef, {
      'gameStats.gamesLost': FieldValue.increment(1),
      'gameStats.lastGameDate': now.toIso8601String(),
      'gameStats.lastGameResult': 'loss',
      // Category-specific losses
      'gameStats.lossesByCategory.$gameType': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Get PTL match records for a session
  Future<List<GameMatch>> getPTLMatchesForSession(String sessionId) async {
    final snapshot = await _tenant
        .gameMatches()
        .where('sessionId', isEqualTo: sessionId)
        .where('isManualEntry', isEqualTo: false)
        .orderBy('matchDate', descending: true)
        .get();

    return snapshot.docs.map((doc) => GameMatch.fromFirestore(doc)).toList();
  }

  /// Get PTL statistics for a customer
  Future<Map<String, dynamic>> getPTLStatsForCustomer(String customerId) async {
    final snapshot = await _tenant
        .gameMatches()
        .where('isManualEntry', isEqualTo: false)
        .get();
    final matchDocs = snapshot.docs
        .where((d) => d.data()['sessionId'] != null)
        .toList();

    int ptlWins = 0;
    int ptlLosses = 0;
    double ptlPointsEarned = 0.0;
    final ptlSessions = <String>{};

    for (final doc in matchDocs) {
      final match = GameMatch.fromFirestore(doc);
      if (match.sessionId != null) {
        if (match.winnerId == customerId) {
          ptlWins++;
          ptlPointsEarned += match.pointsAwarded;
        } else if (match.loserId == customerId) {
          ptlLosses++;
        }
        ptlSessions.add(match.sessionId!);
      }
    }

    return {
      'ptlWins': ptlWins,
      'ptlLosses': ptlLosses,
      'ptlPointsEarned': ptlPointsEarned,
      'ptlSessionsPlayed': ptlSessions.length,
      'ptlWinRate': ptlWins + ptlLosses > 0
          ? (ptlWins / (ptlWins + ptlLosses)) * 100
          : 0.0,
    };
  }

  /// Validate PTL session data before creating matches
  bool validatePTLSession(TableSession session, int loserPlayerIndex) {
    if (!session.isPTL) {
      return false;
    }

    if (session.playerIds.isEmpty || session.playerNames.isEmpty) {
      return false;
    }

    if (loserPlayerIndex < 1 || loserPlayerIndex > session.playerIds.length) {
      return false;
    }

    // Check if player count matches
    final expectedPlayerCount = session.playerCount ?? 0;
    if (session.playerIds.length != expectedPlayerCount) {
      return false;
    }

    return true;
  }

  /// Get all PTL sessions for reporting
  Future<List<Map<String, dynamic>>> getPTLSessions({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> query = _tenant
        .gameMatches()
        .where('isManualEntry', isEqualTo: false);

    if (startDate != null) {
      query = query.where(
        'matchDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'matchDate',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final allDocs = await query.orderBy('matchDate', descending: true).get();
    final snapshot = allDocs.docs.where((d) => d.data()['sessionId'] != null).toList();

    final sessionGroups = <String, Map<String, dynamic>>{};

    for (final doc in snapshot) {
      final match = GameMatch.fromFirestore(doc);
      final sessionId = match.sessionId!;

      if (!sessionGroups.containsKey(sessionId)) {
        sessionGroups[sessionId] = {
          'sessionId': sessionId,
          'matchDate': match.matchDate,
          'winners': <Map<String, dynamic>>[],
          'loser': {'id': match.loserId, 'name': match.loserName},
          'totalPointsAwarded': 0.0,
          'playerCount': 0,
        };
      }

      sessionGroups[sessionId]!['winners'].add({
        'id': match.winnerId,
        'name': match.winnerName,
        'points': match.pointsAwarded,
      });

      sessionGroups[sessionId]!['totalPointsAwarded'] += match.pointsAwarded;
      sessionGroups[sessionId]!['playerCount'] =
          (sessionGroups[sessionId]!['winners'] as List).length + 1;
    }

    return sessionGroups.values.toList();
  }
}
