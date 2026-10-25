import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tournament.dart';
import '../models/tournament_registration.dart';
import 'tenant_provider.dart';

export 'tournament_service_provider.dart';

final tournamentsProvider = StreamProvider<List<Tournament>>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(<Tournament>[]);
  return tenant
      .tournaments()
      .orderBy('startDate', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList(),
      );
});

final activeTournamentsProvider = StreamProvider<List<Tournament>>((ref) {
  ref.keepAlive();

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(<Tournament>[]);
  return tenant
      .tournaments()
      .where('status', isEqualTo: TournamentStatus.inProgress.firestoreValue)
      .orderBy('startDate', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList(),
      );
});

final upcomingTournamentsProvider = StreamProvider<List<Tournament>>((ref) {
  ref.keepAlive();

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(<Tournament>[]);
  return tenant
      .tournaments()
      .where(
        'status',
        whereIn: [
          TournamentStatus.draft.firestoreValue,
          TournamentStatus.registration.firestoreValue,
        ],
      )
      .orderBy('startDate')
      .limit(20)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList(),
      );
});

final completedTournamentsProvider = StreamProvider<List<Tournament>>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(<Tournament>[]);
  return tenant
      .tournaments()
      .where('status', isEqualTo: TournamentStatus.completed.firestoreValue)
      .orderBy('endDate', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList(),
      );
});

final tournamentProvider = StreamProvider.family<Tournament?, String>((
  ref,
  tournamentId,
) {
  if (tournamentId.isEmpty) return Stream.value(null);

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(null);
  return tenant
      .tournaments()
      .doc(tournamentId)
      .snapshots()
      .map((doc) => doc.exists ? Tournament.fromFirestore(doc) : null);
});

final tournamentParticipantsProvider =
    StreamProvider.family<List<TournamentParticipant>, String>((
      ref,
      tournamentId,
    ) {
      if (tournamentId.isEmpty) return Stream.value([]);

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value([]);
      return tenant
          .tournamentParticipants()
          .where('tournamentId', isEqualTo: tournamentId)
          .orderBy('seed')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => TournamentParticipant.fromFirestore(doc))
                .toList(),
          );
    });

final activeParticipantsProvider =
    StreamProvider.family<List<TournamentParticipant>, String>((
      ref,
      tournamentId,
    ) {
      if (tournamentId.isEmpty) return Stream.value([]);

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value([]);
      return tenant
          .tournamentParticipants()
          .where('tournamentId', isEqualTo: tournamentId)
          .where(
            'status',
            whereIn: [
              ParticipantStatus.registered.firestoreValue,
              ParticipantStatus.active.firestoreValue,
            ],
          )
          .orderBy('seed')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => TournamentParticipant.fromFirestore(doc))
                .toList(),
          );
    });

final isCustomerRegisteredProvider =
    FutureProvider.family<bool, ({String tournamentId, String customerId})>((
      ref,
      params,
    ) async {
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return false;
      final snapshot = await tenant
          .tournamentParticipants()
          .where('tournamentId', isEqualTo: params.tournamentId)
          .where('customerId', isEqualTo: params.customerId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    });

final tournamentMatchesProvider =
    StreamProvider.family<List<TournamentMatch>, String>((ref, tournamentId) {
      if (tournamentId.isEmpty) return Stream.value([]);

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value([]);
      return tenant
          .tournamentMatches()
          .where('tournamentId', isEqualTo: tournamentId)
          .orderBy('round')
          .orderBy('matchNumber')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => TournamentMatch.fromFirestore(doc))
                .toList(),
          );
    });

final roundMatchesProvider =
    StreamProvider.family<
      List<TournamentMatch>,
      ({String tournamentId, int round})
    >((ref, params) {
      if (params.tournamentId.isEmpty) return Stream.value([]);

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value([]);
      return tenant
          .tournamentMatches()
          .where('tournamentId', isEqualTo: params.tournamentId)
          .where('round', isEqualTo: params.round)
          .orderBy('matchNumber')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => TournamentMatch.fromFirestore(doc))
                .toList(),
          );
    });

final pendingMatchesProvider =
    StreamProvider.family<List<TournamentMatch>, String>((ref, tournamentId) {
      if (tournamentId.isEmpty) return Stream.value([]);

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value([]);
      return tenant
          .tournamentMatches()
          .where('tournamentId', isEqualTo: tournamentId)
          .where('status', isEqualTo: MatchStatus.pending.firestoreValue)
          .orderBy('round')
          .orderBy('matchNumber')
          .snapshots()
          .map((snapshot) {
            final matches = snapshot.docs
                .map((doc) => TournamentMatch.fromFirestore(doc))
                .toList();
            // Filter to only matches that have both participants
            return matches.where((m) => m.isReady).toList();
          });
    });

final inProgressMatchesProvider =
    StreamProvider.family<List<TournamentMatch>, String>((ref, tournamentId) {
      if (tournamentId.isEmpty) return Stream.value([]);

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value([]);
      return tenant
          .tournamentMatches()
          .where('tournamentId', isEqualTo: tournamentId)
          .where('status', isEqualTo: MatchStatus.inProgress.firestoreValue)
          .orderBy('round')
          .orderBy('matchNumber')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => TournamentMatch.fromFirestore(doc))
                .toList(),
          );
    });

final tournamentMatchProvider = StreamProvider.family<TournamentMatch?, String>(
  (ref, matchId) {
    if (matchId.isEmpty) return Stream.value(null);

    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return Stream.value(null);
    return tenant
        .tournamentMatches()
        .doc(matchId)
        .snapshots()
        .map((doc) => doc.exists ? TournamentMatch.fromFirestore(doc) : null);
  },
);

class BracketData {
  final Tournament tournament;
  final List<TournamentParticipant> participants;
  final List<TournamentMatch> matches;
  final Map<int, List<TournamentMatch>> matchesByRound;

  BracketData({
    required this.tournament,
    required this.participants,
    required this.matches,
  }) : matchesByRound = _groupMatchesByRound(matches);

  static Map<int, List<TournamentMatch>> _groupMatchesByRound(
    List<TournamentMatch> matches,
  ) {
    final map = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      map.putIfAbsent(match.round, () => []).add(match);
    }
    // Sort matches within each round
    for (final list in map.values) {
      list.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
    }
    return map;
  }

  /// Get matches for a specific round
  List<TournamentMatch> getMatchesForRound(int round) {
    return matchesByRound[round] ?? [];
  }

  /// Get the next pending match
  TournamentMatch? get nextPendingMatch {
    for (int round = 1; round <= tournament.totalRounds; round++) {
      final roundMatches = getMatchesForRound(round);
      for (final match in roundMatches) {
        if (match.isReady && match.status == MatchStatus.pending) {
          return match;
        }
      }
    }
    return null;
  }

  /// Get count of completed matches
  int get completedMatchCount => matches
      .where(
        (m) =>
            m.status == MatchStatus.completed ||
            m.status == MatchStatus.walkover,
      )
      .length;

  /// Get total match count (excluding byes)
  int get totalMatchCount => matches.where((m) => !m.isBye).length;

  /// Get progress percentage
  double get progressPercentage {
    if (totalMatchCount == 0) return 0.0;
    return (completedMatchCount / totalMatchCount) * 100;
  }
}

final bracketDataProvider = FutureProvider.family<BracketData?, String>((
  ref,
  tournamentId,
) async {
  if (tournamentId.isEmpty) return null;

  final tournament = await ref.watch(tournamentProvider(tournamentId).future);
  if (tournament == null) return null;

  final participantsAsync = await ref.watch(
    tournamentParticipantsProvider(tournamentId).future,
  );
  final matchesAsync = await ref.watch(
    tournamentMatchesProvider(tournamentId).future,
  );

  return BracketData(
    tournament: tournament,
    participants: participantsAsync,
    matches: matchesAsync,
  );
});

class TournamentStats {
  final int totalTournaments;
  final int activeTournaments;
  final int completedTournaments;
  final int totalParticipants;
  final int totalMatches;

  TournamentStats({
    required this.totalTournaments,
    required this.activeTournaments,
    required this.completedTournaments,
    required this.totalParticipants,
    required this.totalMatches,
  });
}

final tournamentStatsProvider = StreamProvider<TournamentStats>((ref) {
  ref.keepAlive();

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(
      TournamentStats(
        totalTournaments: 0,
        activeTournaments: 0,
        completedTournaments: 0,
        totalParticipants: 0,
        totalMatches: 0,
      ),
    );
  }
  return tenant.tournaments().snapshots().asyncMap((snapshot) async {
    final tournaments = snapshot.docs
        .map((doc) => Tournament.fromFirestore(doc))
        .toList();

    int active = 0;
    int completed = 0;
    int totalParticipants = 0;

    for (final t in tournaments) {
      if (t.status == TournamentStatus.inProgress) active++;
      if (t.status == TournamentStatus.completed) completed++;
      totalParticipants += t.currentParticipantCount.toInt();
    }

    // Get total matches count
    final matchesSnapshot = await tenant.tournamentMatches().count().get();

    return TournamentStats(
      totalTournaments: tournaments.length,
      activeTournaments: active,
      completedTournaments: completed,
      totalParticipants: totalParticipants,
      totalMatches: matchesSnapshot.count?.toInt() ?? 0,
    );
  });
});

final customerTournamentHistoryProvider =
    StreamProvider.family<List<TournamentParticipant>, String>((
      ref,
      customerId,
    ) {
      if (customerId.isEmpty) return Stream.value([]);

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value([]);
      return tenant
          .tournamentParticipants()
          .where('customerId', isEqualTo: customerId)
          .orderBy('registeredAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => TournamentParticipant.fromFirestore(doc))
                .toList(),
          );
    });

final pendingRegistrationsProvider =
    StreamProvider.family<List<TournamentRegistration>, String>((
      ref,
      tournamentId,
    ) {
      if (tournamentId.isEmpty) return Stream.value([]);

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value([]);
      return tenant
          .tournamentRegistrations()
          .where('tournamentId', isEqualTo: tournamentId)
          .where('status', isEqualTo: RegistrationStatus.pending.firestoreValue)
          .orderBy('requestedAt', descending: false)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => TournamentRegistration.fromFirestore(doc))
                .toList(),
          );
    });

final allRegistrationsProvider =
    StreamProvider.family<List<TournamentRegistration>, String>((
      ref,
      tournamentId,
    ) {
      if (tournamentId.isEmpty) return Stream.value([]);

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value([]);
      return tenant
          .tournamentRegistrations()
          .where('tournamentId', isEqualTo: tournamentId)
          .orderBy('requestedAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => TournamentRegistration.fromFirestore(doc))
                .toList(),
          );
    });

final pendingRegistrationCountProvider = StreamProvider.family<int, String>((
  ref,
  tournamentId,
) {
  if (tournamentId.isEmpty) return Stream.value(0);

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(0);
  return tenant
      .tournamentRegistrations()
      .where('tournamentId', isEqualTo: tournamentId)
      .where('status', isEqualTo: RegistrationStatus.pending.firestoreValue)
      .snapshots()
      .map((snapshot) => snapshot.size);
});

final customerRegistrationProvider =
    FutureProvider.family<
      TournamentRegistration?,
      ({String tournamentId, String customerId})
    >((ref, params) async {
      if (params.tournamentId.isEmpty || params.customerId.isEmpty) {
        return null;
      }

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return null;
      final snapshot = await tenant
          .tournamentRegistrations()
          .where('tournamentId', isEqualTo: params.tournamentId)
          .where('customerId', isEqualTo: params.customerId)
          .orderBy('requestedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return TournamentRegistration.fromFirestore(snapshot.docs.first);
    });

class RegistrationStats {
  final int pending;
  final int approved;
  final int rejected;

  RegistrationStats({this.pending = 0, this.approved = 0, this.rejected = 0});

  int get total => pending + approved + rejected;
}

final registrationStatsProvider =
    StreamProvider.family<RegistrationStats, String>((ref, tournamentId) {
      if (tournamentId.isEmpty) {
        return Stream.value(RegistrationStats());
      }

      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value(RegistrationStats());
      return tenant
          .tournamentRegistrations()
          .where('tournamentId', isEqualTo: tournamentId)
          .snapshots()
          .map((snapshot) {
            int pending = 0;
            int approved = 0;
            int rejected = 0;

            for (final doc in snapshot.docs) {
              final raw = doc.data()['status'] as String?;
              if (raw == null) continue;
              switch (RegistrationStatusExtension.fromString(raw)) {
                case RegistrationStatus.pending:
                  pending++;
                case RegistrationStatus.approved:
                  approved++;
                case RegistrationStatus.rejected:
                  rejected++;
                case RegistrationStatus.cancelled:
                  break;
              }
            }

            return RegistrationStats(
              pending: pending,
              approved: approved,
              rejected: rejected,
            );
          });
    });
