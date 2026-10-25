import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firestore/tenant_firestore.dart';
import '../models/customer.dart';
import '../models/game_match.dart';
import '../models/game_category_catalog.dart';
import '../models/leaderboard_settings.dart';
import '../models/table_type_definition.dart';
import '../services/leaderboard_service.dart';
import '../utils/firestore_utils.dart';
import 'table_type_provider.dart';
import 'tenant_provider.dart';

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  final tenant = ref.watch(tenantRefProvider)!;
  return LeaderboardService(tenant);
});

final leaderboardSettingsProvider = StreamProvider<LeaderboardSettings>((ref) {
  const settingsId = 'default';
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(LeaderboardSettings.defaults());
  }
  return tenant.leaderboardSettings().doc(settingsId).snapshots().map((
    snapshot,
  ) {
    if (!snapshot.exists) {
      // Return defaults if not found
      return LeaderboardSettings.defaults();
    }
    return LeaderboardSettings.fromFirestore(snapshot);
  });
});

class LeaderboardEntry {
  final Customer customer;
  final int rank;
  final double points; // points used for ranking in current context
  final int wins;
  final int losses;
  final int draws;
  final String?
  gameCategory; // Category this entry belongs to (snooker, pool, etc.)

  LeaderboardEntry({
    required this.customer,
    required this.rank,
    required this.points,
    required this.wins,
    required this.losses,
    required this.draws,
    this.gameCategory,
  });
}

/// Tab keys: [GameCategoryCatalog.allKey] plus tenant [gameCategoryKey] values in use.
final visibleLeaderboardCategoryKeysProvider = Provider<List<String>>((ref) {
  final async = ref.watch(activeTableTypeDefinitionsProvider);
  return async.when(
    data: (defs) {
      final inUse =
          defs
              .map(
                (d) => TableTypeDefinition.normalizeGameCategoryKey(
                  d.gameCategoryKey,
                ),
              )
              .toSet()
              .toList()
            ..sort(
              (a, b) => GameCategoryCatalog.sortIndex(
                a,
              ).compareTo(GameCategoryCatalog.sortIndex(b)),
            );
      return [GameCategoryCatalog.allKey, ...inUse];
    },
    loading: () => [GameCategoryCatalog.allKey],
    error: (_, _) => [GameCategoryCatalog.allKey],
  );
});

final leaderboardProvider = StreamProvider.autoDispose<List<LeaderboardEntry>>((
  ref,
) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(const []);

  return tenant
      .customers()
      .orderBy('gameStats.currentLeaderboardPoints', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) {
        final entries = <LeaderboardEntry>[];
        int rank = 1;

        for (final doc in snapshot.docs) {
          final customer = Customer.fromFirestore(doc);
          // Only include customers who have played at least one game
          final stats = (doc.data())['gameStats'] as Map<String, dynamic>?;
          final totalGames =
              parseFirestoreInt(stats?['gamesWon']) +
              parseFirestoreInt(stats?['gamesLost']) +
              parseFirestoreInt(stats?['gamesDrawn']);

          if (totalGames > 0) {
            final double points = parseFirestoreDouble(
              stats?['currentLeaderboardPoints'],
            );
            entries.add(
              LeaderboardEntry(
                customer: customer,
                rank: rank++,
                points: points,
                wins: parseFirestoreInt(stats?['gamesWon']),
                losses: parseFirestoreInt(stats?['gamesLost']),
                draws: parseFirestoreInt(stats?['gamesDrawn']),
              ),
            );
          }
        }

        return entries;
      });
});

final topPerformersProvider =
    StreamProvider.autoDispose<List<LeaderboardEntry>>((ref) {
      ref.keepAlive();

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value(const []);

      return tenant
          .customers()
          .orderBy('gameStats.currentLeaderboardPoints', descending: true)
          .limit(5)
          .snapshots()
          .map((snapshot) {
            final entries = <LeaderboardEntry>[];
            int rank = 1;

            for (final doc in snapshot.docs) {
              final customer = Customer.fromFirestore(doc);
              final stats = (doc.data())['gameStats'] as Map<String, dynamic>?;
              final totalGames =
                  parseFirestoreInt(stats?['gamesWon']) +
                  parseFirestoreInt(stats?['gamesLost']) +
                  parseFirestoreInt(stats?['gamesDrawn']);

              if (totalGames > 0) {
                entries.add(
                  LeaderboardEntry(
                    customer: customer,
                    rank: rank++,
                    points: parseFirestoreDouble(
                      stats?['currentLeaderboardPoints'],
                    ),
                    wins: parseFirestoreInt(stats?['gamesWon']),
                    losses: parseFirestoreInt(stats?['gamesLost']),
                    draws: parseFirestoreInt(stats?['gamesDrawn']),
                  ),
                );
              }
            }

            return entries;
          });
    });

final recentMatchesProvider = StreamProvider.autoDispose<List<GameMatch>>((
  ref,
) {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getRecentMatches(limit: 10);
});

final customerMatchHistoryProvider = StreamProvider.autoDispose
    .family<List<GameMatch>, String>((ref, customerId) {
      final service = ref.watch(leaderboardServiceProvider);
      return service.getAllCustomerMatches(customerId);
    });

final activePlayersCountProvider = StreamProvider.autoDispose<int>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(0);

  return tenant.customers().snapshots().map((snapshot) {
    int count = 0;
    for (final doc in snapshot.docs) {
      final stats = (doc.data())['gameStats'] as Map<String, dynamic>?;
      final totalGames =
          parseFirestoreInt(stats?['gamesWon']) +
          parseFirestoreInt(stats?['gamesLost']) +
          parseFirestoreInt(stats?['gamesDrawn']);
      if (totalGames > 0) {
        count++;
      }
    }
    return count;
  });
});

class LeaderboardStats {
  final int totalPlayers;
  final int totalMatches;
  final int totalPTLMatches;
  final int totalManualMatches;
  final int totalTournamentMatches;
  final double totalPointsAwarded;
  final double ptlPointsAwarded;
  final double manualPointsAwarded;
  final double tournamentPointsAwarded;

  LeaderboardStats({
    required this.totalPlayers,
    required this.totalMatches,
    required this.totalPTLMatches,
    required this.totalManualMatches,
    required this.totalTournamentMatches,
    required this.totalPointsAwarded,
    required this.ptlPointsAwarded,
    required this.manualPointsAwarded,
    required this.tournamentPointsAwarded,
  });
}

final leaderboardStatsProvider = StreamProvider.autoDispose<LeaderboardStats>((
  ref,
) {
  ref.keepAlive();

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(
      LeaderboardStats(
        totalPlayers: 0,
        totalMatches: 0,
        totalPTLMatches: 0,
        totalManualMatches: 0,
        totalTournamentMatches: 0,
        totalPointsAwarded: 0,
        ptlPointsAwarded: 0,
        manualPointsAwarded: 0,
        tournamentPointsAwarded: 0,
      ),
    );
  }

  final customersStream = tenant.customers().snapshots();
  final matchesStream = tenant.gameMatches().limit(500).snapshots();

  return customersStream.asyncMap((customerSnapshot) async {
    final matchSnapshot = await matchesStream.first;

    int totalPlayers = 0;
    double totalPoints = 0.0;

    for (final doc in customerSnapshot.docs) {
      final stats = (doc.data())['gameStats'] as Map<String, dynamic>?;
      final totalGames =
          parseFirestoreInt(stats?['gamesWon']) +
          parseFirestoreInt(stats?['gamesLost']) +
          parseFirestoreInt(stats?['gamesDrawn']);
      if (totalGames > 0) {
        totalPlayers++;
        totalPoints += parseFirestoreDouble(stats?['totalPointsEarned']);
      }
    }

    // Separate PTL, manual, and tournament matches
    int ptlMatches = 0;
    int manualMatches = 0;
    int tournamentMatches = 0;
    double ptlPoints = 0.0;
    double manualPoints = 0.0;
    double tournamentPoints = 0.0;

    for (final doc in matchSnapshot.docs) {
      final match = doc.data();
      final isPTL =
          match['isPTLMatch'] == true ||
          (match['isManualEntry'] == false && match['sessionId'] != null);
      final isManual = match['isManualEntry'] == true;
      final notes = match['notes'] as String? ?? '';
      final isTournament = notes.toLowerCase().contains('tournament');
      final points = parseFirestoreDouble(match['pointsAwarded']);

      if (isTournament) {
        tournamentMatches++;
        tournamentPoints += points;
      } else if (isPTL) {
        ptlMatches++;
        ptlPoints += points;
      } else if (isManual) {
        manualMatches++;
        manualPoints += points;
      } else {
        // Default to manual if unclear
        manualMatches++;
        manualPoints += points;
      }
    }

    return LeaderboardStats(
      totalPlayers: totalPlayers,
      totalMatches: matchSnapshot.size,
      totalPTLMatches: ptlMatches,
      totalManualMatches: manualMatches,
      totalTournamentMatches: tournamentMatches,
      totalPointsAwarded: totalPoints,
      ptlPointsAwarded: ptlPoints,
      manualPointsAwarded: manualPoints,
      tournamentPointsAwarded: tournamentPoints,
    );
  });
});

enum LeaderboardPeriod { allTime, days30, days7, today }

/// Timestamp of the most recent leaderboard reset, or null if none.
/// Period-based leaderboards only count matches on or after this time.
final lastLeaderboardResetAtProvider = StreamProvider.autoDispose<DateTime?>((
  ref,
) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(null);

  return tenant
      .leaderboardResets()
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        final data = snapshot.docs.first.data();
        final createdAt = data['createdAt'] as Timestamp?;
        return createdAt?.toDate();
      });
});

final categoryLeaderboardProvider = StreamProvider.autoDispose
    .family<List<LeaderboardEntry>, String>((ref, categoryKey) {
      if (categoryKey == GameCategoryCatalog.allKey) {
        return ref
            .watch(leaderboardProvider.future)
            .asStream()
            .map((entries) => entries);
      }

      final normalized = TableTypeDefinition.normalizeGameCategoryKey(
        categoryKey,
      );
      final categoryField = 'gameStats.pointsByCategory.$normalized';

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value(const <LeaderboardEntry>[]);

      return tenant
          .customers()
          .orderBy(categoryField, descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) {
            final entries = <LeaderboardEntry>[];
            int rank = 1;

            for (final doc in snapshot.docs) {
              final customer = Customer.fromFirestore(doc);
              final data = doc.data();
              final stats = data['gameStats'] as Map<String, dynamic>?;

              // Get category-specific stats
              final pointsByCategory =
                  stats?['pointsByCategory'] as Map<String, dynamic>?;
              final winsByCategory =
                  stats?['winsByCategory'] as Map<String, dynamic>?;
              final lossesByCategory =
                  stats?['lossesByCategory'] as Map<String, dynamic>?;

              final categoryKeyResolved = normalized;
              final points = parseFirestoreDouble(
                pointsByCategory?[categoryKeyResolved],
              );
              final wins = parseFirestoreInt(
                winsByCategory?[categoryKeyResolved],
              );
              final losses = parseFirestoreInt(
                lossesByCategory?[categoryKeyResolved],
              );

              // Only include customers who have played at least one game in this category
              if (points > 0 || wins > 0 || losses > 0) {
                entries.add(
                  LeaderboardEntry(
                    customer: customer,
                    rank: rank++,
                    points: points,
                    wins: wins,
                    losses: losses,
                    draws: 0, // Draws are not tracked per category currently
                    gameCategory: categoryKeyResolved,
                  ),
                );
              }
            }

            return entries;
          });
    });

final categoryPeriodLeaderboardProvider = StreamProvider.autoDispose
    .family<
      List<LeaderboardEntry>,
      ({String categoryKey, LeaderboardPeriod period})
    >((ref, params) {
      final categoryKeyRaw = params.categoryKey;
      final period = params.period;
      final categoryKey = categoryKeyRaw == GameCategoryCatalog.allKey
          ? GameCategoryCatalog.allKey
          : TableTypeDefinition.normalizeGameCategoryKey(categoryKeyRaw);

      // If it's all-time and all categories, use the regular leaderboard
      if (categoryKey == GameCategoryCatalog.allKey &&
          period == LeaderboardPeriod.allTime) {
        return ref
            .watch(leaderboardProvider.future)
            .asStream()
            .map((entries) => entries);
      }

      // If it's all-time but specific category
      if (period == LeaderboardPeriod.allTime) {
        return ref
            .watch(categoryLeaderboardProvider(categoryKeyRaw).future)
            .asStream()
            .map((entries) => entries);
      }

      // For period-based filtering: only count matches on or after last reset
      DateTime? startDate;
      final now = DateTime.now();
      switch (period) {
        case LeaderboardPeriod.today:
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case LeaderboardPeriod.days7:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case LeaderboardPeriod.days30:
          startDate = now.subtract(const Duration(days: 30));
          break;
        case LeaderboardPeriod.allTime:
          startDate = null;
          break;
      }

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value(const <LeaderboardEntry>[]);

      // Drive from leaderboard_resets so effectiveStart updates when a reset happens
      return tenant
          .leaderboardResets()
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .asyncExpand((resetSnap) {
            final lastResetAt = resetSnap.docs.isEmpty
                ? null
                : (resetSnap.docs.first.data()['createdAt'] as Timestamp?)
                      ?.toDate();
            final effectiveStart = startDate != null && lastResetAt != null
                ? (startDate.isAfter(lastResetAt) ? startDate : lastResetAt)
                : startDate;

            Query<Map<String, dynamic>> query = tenant.gameMatches();
            if (categoryKey != GameCategoryCatalog.allKey) {
              query = query.where('gameType', isEqualTo: categoryKey);
            }
            if (effectiveStart != null) {
              query = query
                  .where(
                    'matchDate',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStart),
                  )
                  .orderBy('matchDate', descending: true);
            } else {
              query = query.orderBy('matchDate', descending: true);
            }

            return query.snapshots().asyncMap((snapshot) async {
              final Map<String, double> pointsByCustomer = {};
              final Map<String, int> winsByCustomer = {};
              final Map<String, int> lossesByCustomer = {};
              final Set<String> customerIds = {};

              for (final doc in snapshot.docs) {
                final data = doc.data();
                final winnerId = data['winnerId'] as String?;
                final loserId = data['loserId'] as String?;
                final points = parseFirestoreDouble(data['pointsAwarded']);

                if (winnerId != null && winnerId.isNotEmpty) {
                  pointsByCustomer[winnerId] =
                      (pointsByCustomer[winnerId] ?? 0.0) + points;
                  winsByCustomer[winnerId] =
                      (winsByCustomer[winnerId] ?? 0) + 1;
                  customerIds.add(winnerId);
                }
                if (loserId != null && loserId.isNotEmpty) {
                  lossesByCustomer[loserId] =
                      (lossesByCustomer[loserId] ?? 0) + 1;
                  customerIds.add(loserId);
                }
              }

              final customers = <Customer>[];
              await Future.wait(
                customerIds.map((id) async {
                  final snap = await tenant.customers().doc(id).get();
                  if (snap.exists) customers.add(Customer.fromFirestore(snap));
                }),
              );

              final entriesUnsorted = <LeaderboardEntry>[];
              for (final c in customers) {
                final p = pointsByCustomer[c.id] ?? 0.0;
                final w = winsByCustomer[c.id] ?? 0;
                final l = lossesByCustomer[c.id] ?? 0;
                if (p > 0 || w + l > 0) {
                  entriesUnsorted.add(
                    LeaderboardEntry(
                      customer: c,
                      rank: 0,
                      points: p,
                      wins: w,
                      losses: l,
                      draws: 0,
                      gameCategory: categoryKey != GameCategoryCatalog.allKey
                          ? categoryKey
                          : null,
                    ),
                  );
                }
              }

              entriesUnsorted.sort((a, b) => b.points.compareTo(a.points));
              int rank = 1;
              return entriesUnsorted
                  .map(
                    (e) => LeaderboardEntry(
                      customer: e.customer,
                      rank: rank++,
                      points: e.points,
                      wins: e.wins,
                      losses: e.losses,
                      draws: e.draws,
                      gameCategory: e.gameCategory,
                    ),
                  )
                  .toList();
            });
          });
    });

final periodLeaderboardProvider = StreamProvider.autoDispose
    .family<List<LeaderboardEntry>, LeaderboardPeriod>((ref, period) {
      DateTime? startDate;
      final now = DateTime.now();
      switch (period) {
        case LeaderboardPeriod.today:
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case LeaderboardPeriod.days7:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case LeaderboardPeriod.days30:
          startDate = now.subtract(const Duration(days: 30));
          break;
        case LeaderboardPeriod.allTime:
          startDate = null;
          break;
      }

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value(const <LeaderboardEntry>[]);

      // All-time: no date filter, no reset logic
      if (startDate == null) {
        final query = tenant.gameMatches().orderBy(
          'matchDate',
          descending: true,
        );
        return query.snapshots().asyncMap(
          (snapshot) => _buildPeriodEntries(tenant, snapshot),
        );
      }

      final periodStart = startDate;

      // Period-based: only count matches on or after last reset
      return tenant
          .leaderboardResets()
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .asyncExpand((resetSnap) {
            final lastResetAt = resetSnap.docs.isEmpty
                ? null
                : (resetSnap.docs.first.data()['createdAt'] as Timestamp?)
                      ?.toDate();
            final effectiveStart =
                lastResetAt != null && periodStart.isBefore(lastResetAt)
                ? lastResetAt
                : periodStart;

            final query = tenant
                .gameMatches()
                .where(
                  'matchDate',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStart),
                )
                .orderBy('matchDate', descending: true);

            return query.snapshots().asyncMap(
              (snapshot) => _buildPeriodEntries(tenant, snapshot),
            );
          });
    });

Future<List<LeaderboardEntry>> _buildPeriodEntries(
  TenantRef tenant,
  QuerySnapshot<Map<String, dynamic>> snapshot,
) async {
  final Map<String, double> pointsByCustomer = {};
  final Map<String, int> winsByCustomer = {};
  final Map<String, int> lossesByCustomer = {};
  final Set<String> customerIds = {};

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final winnerId = data['winnerId'] as String?;
    final loserId = data['loserId'] as String?;
    final points = parseFirestoreDouble(data['pointsAwarded']);

    if (winnerId != null && winnerId.isNotEmpty) {
      pointsByCustomer[winnerId] = (pointsByCustomer[winnerId] ?? 0.0) + points;
      winsByCustomer[winnerId] = (winsByCustomer[winnerId] ?? 0) + 1;
      customerIds.add(winnerId);
    }
    if (loserId != null && loserId.isNotEmpty) {
      lossesByCustomer[loserId] = (lossesByCustomer[loserId] ?? 0) + 1;
      customerIds.add(loserId);
    }
  }

  final customers = <Customer>[];
  await Future.wait(
    customerIds.map((id) async {
      final snap = await tenant.customers().doc(id).get();
      if (snap.exists) customers.add(Customer.fromFirestore(snap));
    }),
  );

  const d = 0;
  final entriesUnsorted = <LeaderboardEntry>[];
  for (final c in customers) {
    final p = pointsByCustomer[c.id] ?? 0.0;
    final w = winsByCustomer[c.id] ?? 0;
    final l = lossesByCustomer[c.id] ?? 0;
    if (p > 0 || w + l + d > 0) {
      entriesUnsorted.add(
        LeaderboardEntry(
          customer: c,
          rank: 0,
          points: p,
          wins: w,
          losses: l,
          draws: d,
        ),
      );
    }
  }

  entriesUnsorted.sort((a, b) => b.points.compareTo(a.points));
  int rank = 1;
  return entriesUnsorted
      .map(
        (e) => LeaderboardEntry(
          customer: e.customer,
          rank: rank++,
          points: e.points,
          wins: e.wins,
          losses: e.losses,
          draws: e.draws,
        ),
      )
      .toList();
}
