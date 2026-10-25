import 'package:cloud_firestore/cloud_firestore.dart';
import '../firestore/tenant_firestore.dart';
import '../models/game_match.dart';
import '../models/customer.dart';
import '../models/app_user.dart';

class LeaderboardService {
  final TenantRef _tenant;

  LeaderboardService(this._tenant);

  FirebaseFirestore get _db => _tenant.db;

  /// Award points to a winner and record the match
  Future<void> awardPointsToWinner({
    required Customer winner,
    Customer? loser,
    required double points,
    required AppUser awardedBy,
    String? sessionId,
    String gameType = 'snooker',
    String? notes,
    String? tableId,
    String? tableName,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();

    // Create game match record
    final matchRef = _tenant.gameMatches().doc();
    final match = GameMatch(
      id: matchRef.id,
      winnerId: winner.id,
      winnerName: winner.name,
      loserId: loser?.id,
      loserName: loser?.name,
      pointsAwarded: points,
      sessionId: sessionId,
      gameType: gameType,
      tableId: tableId,
      tableName: tableName,
      timestamp: now,
      matchDate: now,
      awardedBy: awardedBy.uid,
      awardedByName: awardedBy.name,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      isPTLMatch: sessionId != null,
      isManualEntry: sessionId == null,
    );
    batch.set(matchRef, match.toFirestore());

    // Update winner's statistics
    final winnerRef = _tenant.customers().doc(winner.id);
    batch.update(winnerRef, {
      'gameStats.gamesWon': FieldValue.increment(1),
      'gameStats.totalPointsEarned': FieldValue.increment(points),
      'gameStats.currentLeaderboardPoints': FieldValue.increment(points),
      'gameStats.lastGameDate': now.toIso8601String(),
      'gameStats.lastGameResult': 'win',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update loser's statistics if provided
    if (loser != null) {
      final loserRef = _tenant.customers().doc(loser.id);
      batch.update(loserRef, {
        'gameStats.gamesLost': FieldValue.increment(1),
        'gameStats.lastGameDate': now.toIso8601String(),
        'gameStats.lastGameResult': 'loss',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Award points to a winner against multiple losers.
  /// If [splitPointsAmongLosers] is true, each loser yields points = points/losers.length (rounded to 2 decimals).
  /// Otherwise, each loser yields the full [points] to the winner (and increments wins per loser).
  Future<void> awardPointsToWinnerMultiLosers({
    required Customer winner,
    required List<Customer> losers,
    required double points,
    required AppUser awardedBy,
    String? sessionId,
    String gameType = 'snooker',
    String? notes,
    bool splitPointsAmongLosers = true,
    String? tableId,
    String? tableName,
  }) async {
    if (losers.isEmpty) {
      // Fallback to single-winner, no-loser case
      return awardPointsToWinner(
        winner: winner,
        points: points,
        awardedBy: awardedBy,
        sessionId: sessionId,
        gameType: gameType,
        notes: notes,
      );
    }

    final batch = _db.batch();
    final now = DateTime.now();

    final double pointsEach = splitPointsAmongLosers && losers.length > 1
        ? double.parse((points / losers.length).toStringAsFixed(2))
        : points;

    double totalPointsAwardedToWinner = 0.0;

    for (final loser in losers) {
      // Create match for each loser
      final matchRef = _tenant.gameMatches().doc();
      final match = GameMatch(
        id: matchRef.id,
        winnerId: winner.id,
        winnerName: winner.name,
        loserId: loser.id,
        loserName: loser.name,
        pointsAwarded: pointsEach,
        sessionId: sessionId,
        gameType: gameType,
        tableId: tableId,
        tableName: tableName,
        timestamp: now,
        matchDate: now,
        awardedBy: awardedBy.uid,
        awardedByName: awardedBy.name,
        notes: notes,
        createdAt: now,
        updatedAt: now,
        isPTLMatch: sessionId != null,
        isManualEntry: sessionId == null,
      );
      batch.set(matchRef, match.toFirestore());

      // Update loser stats
      final loserRef = _tenant.customers().doc(loser.id);
      batch.update(loserRef, {
        'gameStats.gamesLost': FieldValue.increment(1),
        'gameStats.lastGameDate': now.toIso8601String(),
        'gameStats.lastGameResult': 'loss',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      totalPointsAwardedToWinner += pointsEach;
    }

    // Update winner once with aggregated points and wins equal to number of losers
    final winnerRef = _tenant.customers().doc(winner.id);
    batch.update(winnerRef, {
      'gameStats.gamesWon': FieldValue.increment(losers.length),
      'gameStats.totalPointsEarned': FieldValue.increment(
        totalPointsAwardedToWinner,
      ),
      'gameStats.currentLeaderboardPoints': FieldValue.increment(
        totalPointsAwardedToWinner,
      ),
      'gameStats.lastGameDate': now.toIso8601String(),
      'gameStats.lastGameResult': 'win',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Record a draw match
  Future<void> recordDraw({
    required Customer player1,
    required Customer player2,
    required AppUser recordedBy,
    String? sessionId,
    String gameType = 'snooker',
    String? notes,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();

    // Update player1's statistics
    final player1Ref = _tenant.customers().doc(player1.id);
    batch.update(player1Ref, {
      'gameStats.gamesDrawn': FieldValue.increment(1),
      'gameStats.lastGameDate': now.toIso8601String(),
      'gameStats.lastGameResult': 'draw',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update player2's statistics
    final player2Ref = _tenant.customers().doc(player2.id);
    batch.update(player2Ref, {
      'gameStats.gamesDrawn': FieldValue.increment(1),
      'gameStats.lastGameDate': now.toIso8601String(),
      'gameStats.lastGameResult': 'draw',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Manually adjust customer's leaderboard points
  Future<void> adjustCustomerPoints({
    required String customerId,
    required double pointsChange,
    required AppUser adjustedBy,
    String? reason,
  }) async {
    // Create adjustment record
    await _tenant.pointAdjustments().add({
      'customerId': customerId,
      'pointsChange': pointsChange,
      'adjustedBy': adjustedBy.uid,
      'adjustedByName': adjustedBy.name,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update customer points
    await _tenant.customers().doc(customerId).update({
      'gameStats.currentLeaderboardPoints': FieldValue.increment(pointsChange),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get customer's match history
  Stream<List<GameMatch>> getCustomerMatchHistory(String customerId) {
    return _tenant
        .gameMatches()
        .where('winnerId', isEqualTo: customerId)
        .orderBy('matchDate', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => GameMatch.fromFirestore(doc)).toList(),
        );
  }

  /// Get all matches for a customer (wins and losses)
  Stream<List<GameMatch>> getAllCustomerMatches(String customerId) {
    // Note: Firestore doesn't support OR queries directly, so we'll need to
    // merge two queries on the client side or use a different approach
    return _tenant
        .gameMatches()
        .where('winnerId', isEqualTo: customerId)
        .orderBy('matchDate', descending: true)
        .limit(100)
        .snapshots()
        .asyncMap((winSnapshot) async {
          // Get losses
          final lossSnapshot = await _tenant
              .gameMatches()
              .where('loserId', isEqualTo: customerId)
              .orderBy('matchDate', descending: true)
              .limit(100)
              .get();

          final wins = winSnapshot.docs
              .map((doc) => GameMatch.fromFirestore(doc))
              .toList();
          final losses = lossSnapshot.docs
              .map((doc) => GameMatch.fromFirestore(doc))
              .toList();

          final allMatches = [...wins, ...losses];
          allMatches.sort((a, b) => b.matchDate.compareTo(a.matchDate));
          return allMatches;
        });
  }

  /// Get PTL-specific matches for a customer
  Future<List<GameMatch>> getCustomerPTLMatches(String customerId) async {
    final snapshot = await _tenant
        .gameMatches()
        .where('isManualEntry', isEqualTo: false)
        .get();

    return snapshot.docs
        .where((d) => d.data()['sessionId'] != null)
        .map((doc) => GameMatch.fromFirestore(doc))
        .where(
          (match) =>
              match.winnerId == customerId || match.loserId == customerId,
        )
        .toList()
      ..sort((a, b) => b.matchDate.compareTo(a.matchDate));
  }

  /// Get leaderboard stats excluding PTL matches (for manual matches only)
  Future<Map<String, dynamic>> getManualMatchStats() async {
    final manualMatches = await _tenant
        .gameMatches()
        .where('isManualEntry', isEqualTo: true)
        .get();

    final int totalMatches = manualMatches.size;
    double totalPoints = 0.0;
    final customerStats = <String, Map<String, dynamic>>{};

    for (final doc in manualMatches.docs) {
      final match = GameMatch.fromFirestore(doc);
      totalPoints += match.pointsAwarded;

      // Update winner stats
      if (!customerStats.containsKey(match.winnerId)) {
        customerStats[match.winnerId] = {
          'id': match.winnerId,
          'name': match.winnerName,
          'wins': 0,
          'losses': 0,
          'points': 0.0,
        };
      }
      customerStats[match.winnerId]!['wins'] =
          (customerStats[match.winnerId]!['wins'] as int) + 1;
      customerStats[match.winnerId]!['points'] =
          (customerStats[match.winnerId]!['points'] as double) +
          match.pointsAwarded;

      // Update loser stats if exists
      if (match.loserId != null) {
        if (!customerStats.containsKey(match.loserId)) {
          customerStats[match.loserId!] = {
            'id': match.loserId,
            'name': match.loserName,
            'wins': 0,
            'losses': 0,
            'points': 0.0,
          };
        }
        customerStats[match.loserId]!['losses'] =
            (customerStats[match.loserId]!['losses'] as int) + 1;
      }
    }

    return {
      'totalManualMatches': totalMatches,
      'totalManualPoints': totalPoints,
      'customerStats': customerStats.values.toList(),
    };
  }

  /// Reset leaderboard points for all customers (e.g., monthly reset).
  /// Commits in batches of 500 to respect Firestore batch limit.
  Future<void> resetAllLeaderboardPoints({
    required AppUser resetBy,
    String? reason,
  }) async {
    const int maxBatchSize = 500;
    final customersSnapshot = await _tenant.customers().get();
    final docs = customersSnapshot.docs;

    if (docs.isNotEmpty) {
      for (var i = 0; i < docs.length; i += maxBatchSize) {
        final batch = _db.batch();
        final chunk = docs.skip(i).take(maxBatchSize);
        for (final doc in chunk) {
          batch.update(doc.reference, {
            'gameStats.currentLeaderboardPoints': 0.0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    }

    // Record the reset (after all customer updates, or with customerCount: 0 if none)
    await _tenant.leaderboardResets().add({
      'resetBy': resetBy.uid,
      'resetByName': resetBy.name,
      'reason': reason,
      'customerCount': docs.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get recent matches (for dashboard)
  Stream<List<GameMatch>> getRecentMatches({int limit = 10}) {
    return _tenant
        .gameMatches()
        .orderBy('matchDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => GameMatch.fromFirestore(doc)).toList(),
        );
  }

  /// Delete a match (admin only)
  Future<void> deleteMatch({
    required String matchId,
    required GameMatch match,
  }) async {
    final batch = _db.batch();

    // Delete the match
    final matchRef = _tenant.gameMatches().doc(matchId);
    batch.delete(matchRef);

    // Reverse the winner's statistics
    final winnerRef = _tenant.customers().doc(match.winnerId);
    batch.update(winnerRef, {
      'gameStats.gamesWon': FieldValue.increment(-1),
      'gameStats.totalPointsEarned': FieldValue.increment(-match.pointsAwarded),
      'gameStats.currentLeaderboardPoints': FieldValue.increment(
        -match.pointsAwarded,
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Reverse loser's statistics if exists
    if (match.loserId != null) {
      final loserRef = _tenant.customers().doc(match.loserId!);
      batch.update(loserRef, {
        'gameStats.gamesLost': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
