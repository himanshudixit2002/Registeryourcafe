import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';
import '../models/tournament_registration.dart';
import '../models/customer.dart';
import '../models/app_user.dart';
import '../models/game_match.dart';
import '../utils/app_logger.dart';
import '../firestore/tenant_firestore.dart';

class TournamentService {
  final TenantRef _tenant;

  TournamentService(this._tenant);

  FirebaseFirestore get _db => _tenant.db;

  // ============================================================
  // Tournament CRUD Operations
  // ============================================================

  /// Creates a new tournament
  Future<Tournament> createTournament({
    required String name,
    String? description,
    required TournamentFormat format,
    required TournamentGameType gameType,
    required DateTime startDate,
    DateTime? endDate,
    int maxParticipants = 0,
    int minParticipants = 2,
    bool hasNoMaxLimit = false,
    double entryFee = 0.0,
    double prizePool = 0.0,
    double pointsForWinner = 100.0,
    double pointsForRunnerUp = 50.0,
    double pointsPerWin = 10.0,
    required AppUser createdBy,
    String? preferredTableId,
    String? preferredTableName,
    Map<String, dynamic>? rules,
    bool isSeeded = false,
    bool showOnPublicLanding = false,
  }) async {
    final tournamentRef = _tenant.tournaments().doc();
    final now = DateTime.now();

    // For flexible participant counts, we don't pre-calculate rounds
    // They'll be calculated when tournament starts based on actual participants
    final totalRounds = 0;

    final tournament = Tournament(
      id: tournamentRef.id,
      name: name,
      description: description,
      format: format,
      status: TournamentStatus.draft,
      gameType: gameType,
      startDate: startDate,
      endDate: endDate,
      maxParticipants: maxParticipants,
      minParticipants: minParticipants,
      hasNoMaxLimit: hasNoMaxLimit || maxParticipants == 0,
      entryFee: entryFee,
      prizePool: prizePool,
      totalRounds: totalRounds,
      pointsForWinner: pointsForWinner,
      pointsForRunnerUp: pointsForRunnerUp,
      pointsPerWin: pointsPerWin,
      createdById: createdBy.uid,
      createdByName: createdBy.name,
      createdAt: now,
      updatedAt: now,
      preferredTableId: preferredTableId,
      preferredTableName: preferredTableName,
      rules: rules,
      isSeeded: isSeeded,
      showOnPublicLanding: showOnPublicLanding,
    );

    await tournamentRef.set(tournament.toFirestore());

    AppLogger.info(
      'Tournament created: ${tournament.name} (${tournament.id})',
      tag: 'TournamentService',
    );

    return tournament;
  }

  /// Updates an existing tournament
  Future<void> updateTournament(Tournament tournament) async {
    if (!tournament.isEditable) {
      throw Exception('Cannot edit tournament that has already started');
    }

    await _tenant.tournaments().doc(tournament.id).update({
      ...tournament.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a tournament and all related data
  Future<void> deleteTournament(String tournamentId) async {
    final batch = _db.batch();

    // Delete all participants
    final participantsSnapshot = await _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    for (final doc in participantsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete all matches
    final matchesSnapshot = await _tenant
        .tournamentMatches()
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    for (final doc in matchesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete tournament
    batch.delete(_tenant.tournaments().doc(tournamentId));

    await batch.commit();

    AppLogger.info(
      'Tournament deleted: $tournamentId',
      tag: 'TournamentService',
    );
  }

  /// Opens tournament for registration
  Future<void> openRegistration(String tournamentId) async {
    await _tenant.tournaments().doc(tournamentId).update({
      'status': TournamentStatus.registration.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Closes registration
  Future<void> closeRegistration(String tournamentId) async {
    final tournamentDoc = await _tenant.tournaments().doc(tournamentId).get();
    if (!tournamentDoc.exists) {
      throw Exception('Tournament not found');
    }
    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (tournament.currentParticipantCount < 2) {
      throw Exception('Need at least 2 participants to close registration');
    }

    await _tenant.tournaments().doc(tournamentId).update({
      'status': TournamentStatus.draft.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // Participant Management
  // ============================================================

  /// Adds a customer as a tournament participant
  Future<TournamentParticipant> addParticipant({
    required String tournamentId,
    required Customer customer,
    int? seed,
  }) async {
    // Check tournament exists and can accept participants
    final tournamentDoc = await _tenant.tournaments().doc(tournamentId).get();
    if (!tournamentDoc.exists) {
      throw Exception('Tournament not found');
    }
    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (!tournament.canAddParticipants) {
      if (tournament.hasStarted) {
        throw Exception('Tournament has already started');
      }
      throw Exception('Tournament is full');
    }

    // Check if customer is already registered
    final existingParticipant = await _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('customerId', isEqualTo: customer.id)
        .limit(1)
        .get();

    if (existingParticipant.docs.isNotEmpty) {
      throw Exception('Customer is already registered for this tournament');
    }

    final batch = _db.batch();
    final participantRef = _tenant.tournamentParticipants().doc();

    final participant = TournamentParticipant(
      id: participantRef.id,
      tournamentId: tournamentId,
      customerId: customer.id,
      customerName: customer.name,
      customerPhoneNumber: customer.phoneNumber,
      seed: seed ?? tournament.currentParticipantCount + 1,
      registeredAt: DateTime.now(),
    );

    batch.set(participantRef, participant.toFirestore());

    // Update tournament participant count
    batch.update(_tenant.tournaments().doc(tournamentId), {
      'currentParticipantCount': FieldValue.increment(1),
      'participantIds': FieldValue.arrayUnion([customer.id]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    AppLogger.info(
      'Participant added: ${customer.name} to tournament $tournamentId',
      tag: 'TournamentService',
    );

    return participant;
  }

  /// Adds a customer as a tournament participant with payment recording
  /// This creates a registration record and records the transaction
  Future<TournamentParticipant> addParticipantWithPayment({
    required String tournamentId,
    required Customer customer,
    required double amountPaid,
    required PaymentMethod paymentMethod,
    required AppUser approvedBy,
    String? note,
    int? seed,
  }) async {
    // Check tournament exists and can accept participants
    final tournamentDoc = await _tenant.tournaments().doc(tournamentId).get();
    if (!tournamentDoc.exists) {
      throw Exception('Tournament not found');
    }
    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (!tournament.canAddParticipants) {
      if (tournament.hasStarted) {
        throw Exception('Tournament has already started');
      }
      throw Exception('Tournament is full');
    }

    // Check if customer is already registered
    final existingParticipant = await _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('customerId', isEqualTo: customer.id)
        .limit(1)
        .get();

    if (existingParticipant.docs.isNotEmpty) {
      throw Exception('Customer is already registered for this tournament');
    }

    final batch = _db.batch();
    final now = DateTime.now();

    // 1. Create registration record (approved immediately)
    final registrationRef = _tenant.tournamentRegistrations().doc();
    batch.set(registrationRef, {
      'id': registrationRef.id,
      'tournamentId': tournamentId,
      'tournamentName': tournament.name,
      'customerId': customer.id,
      'customerName': customer.name,
      'customerPhone': customer.phoneNumber,
      'status': RegistrationStatus.approved.firestoreValue,
      'requestedAt': Timestamp.fromDate(now),
      'requestNote': note,
      'approvedAt': Timestamp.fromDate(now),
      'approvedById': approvedBy.uid,
      'approvedByName': approvedBy.name,
      'paymentMethod': paymentMethod.storageValue,
      'amountPaid': amountPaid,
      'entryFee': tournament.entryFee,
      'isPublicRegistration': false,
      'isRefunded': false,
    });

    // 2. Create transaction record
    final transactionRef = _tenant.transactions().doc();
    batch.set(transactionRef, {
      'id': transactionRef.id,
      'type': 'tournament_registration',
      'tournamentId': tournamentId,
      'tournamentName': tournament.name,
      'registrationId': registrationRef.id,
      'customerId': customer.id,
      'customerName': customer.name,
      'amount': amountPaid,
      'paymentMethod': paymentMethod.storageValue,
      'description': 'Tournament Entry Fee - ${tournament.name}',
      'createdAt': Timestamp.fromDate(now),
      'createdById': approvedBy.uid,
      'createdByName': approvedBy.name,
    });

    // Update registration with transaction ID
    batch.update(registrationRef, {'transactionId': transactionRef.id});

    // 3. Create participant
    final participantRef = _tenant.tournamentParticipants().doc();
    batch.set(participantRef, {
      'id': participantRef.id,
      'tournamentId': tournamentId,
      'customerId': customer.id,
      'customerName': customer.name,
      'customerPhoneNumber': customer.phoneNumber,
      'seed': seed ?? tournament.currentParticipantCount + 1,
      'status': ParticipantStatus.registered.firestoreValue,
      'matchesPlayed': 0,
      'matchesWon': 0,
      'matchesLost': 0,
      'pointsEarned': 0.0,
      'registeredAt': Timestamp.fromDate(now),
      'hasBye': false,
      'registrationId': registrationRef.id,
      'paymentMethod': paymentMethod.storageValue,
      'entryFeePaid': amountPaid,
    });

    // 4. Update tournament participant count
    batch.update(_tenant.tournaments().doc(tournamentId), {
      'currentParticipantCount': FieldValue.increment(1),
      'participantIds': FieldValue.arrayUnion([customer.id]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    AppLogger.info(
      'Participant added with payment: ${customer.name} to ${tournament.name}, Payment: ₹$amountPaid via ${paymentMethod.displayName}',
      tag: 'TournamentService',
    );

    return TournamentParticipant(
      id: participantRef.id,
      tournamentId: tournamentId,
      customerId: customer.id,
      customerName: customer.name,
      customerPhoneNumber: customer.phoneNumber,
      seed: seed ?? tournament.currentParticipantCount + 1,
      registeredAt: now,
    );
  }

  /// Removes a participant from tournament
  Future<void> removeParticipant({
    required String tournamentId,
    required String participantId,
    required String customerId,
  }) async {
    final tournamentDoc = await _tenant.tournaments().doc(tournamentId).get();
    if (!tournamentDoc.exists) {
      throw Exception('Tournament not found');
    }
    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (tournament.hasStarted) {
      throw Exception('Cannot remove participant from started tournament');
    }

    final batch = _db.batch();

    batch.delete(_tenant.tournamentParticipants().doc(participantId));

    batch.update(_tenant.tournaments().doc(tournamentId), {
      'currentParticipantCount': FieldValue.increment(-1),
      'participantIds': FieldValue.arrayRemove([customerId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Updates participant seed
  Future<void> updateParticipantSeed({
    required String participantId,
    required int newSeed,
  }) async {
    await _tenant.tournamentParticipants().doc(participantId).update({
      'seed': newSeed,
    });
  }

  /// Reseeds all participants (shuffles or sorts)
  Future<void> reseedParticipants({
    required String tournamentId,
    bool shuffle = false,
  }) async {
    final participantsSnapshot = await _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: tournamentId)
        .get();

    final participants = participantsSnapshot.docs
        .map((doc) => TournamentParticipant.fromFirestore(doc))
        .toList();

    if (shuffle) {
      participants.shuffle();
    }

    final batch = _db.batch();
    for (int i = 0; i < participants.length; i++) {
      batch.update(_tenant.tournamentParticipants().doc(participants[i].id), {
        'seed': i + 1,
      });
    }
    await batch.commit();
  }

  // ============================================================
  // Tournament Start & Bracket Generation
  // ============================================================

  /// Starts the tournament and generates the bracket
  Future<void> startTournament({
    required String tournamentId,
    required AppUser startedBy,
  }) async {
    final tournamentDoc = await _tenant.tournaments().doc(tournamentId).get();
    if (!tournamentDoc.exists) {
      throw Exception('Tournament not found');
    }
    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (tournament.status == TournamentStatus.inProgress) {
      throw Exception('Tournament has already started');
    }

    if (!tournament.canStart) {
      throw Exception(
        'Need at least ${tournament.minParticipants} participants to start (currently ${tournament.currentParticipantCount})',
      );
    }

    // Get all participants sorted by seed
    final participantsSnapshot = await _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: tournamentId)
        .orderBy('seed')
        .get();

    final participants = participantsSnapshot.docs
        .map((doc) => TournamentParticipant.fromFirestore(doc))
        .toList();

    // Calculate rounds based on actual participant count
    final totalRounds = Tournament.calculateTotalRounds(participants.length);
    final bracketSize = Tournament.getNextPowerOfTwo(participants.length);
    final byesNeeded = bracketSize - participants.length;

    // Generate first round matches
    final matches = await _generateFirstRoundMatches(
      tournamentId: tournamentId,
      participants: participants,
      bracketSize: bracketSize,
      byesNeeded: byesNeeded,
      totalRounds: totalRounds,
    );

    final batch = _db.batch();

    // Update tournament status
    batch.update(_tenant.tournaments().doc(tournamentId), {
      'status': TournamentStatus.inProgress.firestoreValue,
      'currentRound': 1,
      'totalRounds': totalRounds,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update all participants to active
    for (final participant in participants) {
      batch.update(_tenant.tournamentParticipants().doc(participant.id), {
        'status': ParticipantStatus.active.firestoreValue,
      });
    }

    // Create matches
    for (final match in matches) {
      final matchRef = _tenant.tournamentMatches().doc(match.id);
      batch.set(matchRef, match.toFirestore());
    }

    await batch.commit();

    // Auto-advance byes
    await _processFirstRoundByes(tournamentId);

    AppLogger.info(
      'Tournament started: ${tournament.name} with ${participants.length} participants',
      tag: 'TournamentService',
    );
  }

  /// Generates first round matches with seeding
  Future<List<TournamentMatch>> _generateFirstRoundMatches({
    required String tournamentId,
    required List<TournamentParticipant> participants,
    required int bracketSize,
    required int byesNeeded,
    required int totalRounds,
  }) async {
    final matches = <TournamentMatch>[];
    final firstRoundMatchCount = bracketSize ~/ 2;

    // Create seeded bracket positions
    final positions = _generateSeededPositions(bracketSize);

    // Place participants in positions (byes get null)
    final bracketSlots = List<TournamentParticipant?>.filled(bracketSize, null);
    for (int i = 0; i < participants.length; i++) {
      bracketSlots[positions[i]] = participants[i];
    }

    // Create matches
    for (int i = 0; i < firstRoundMatchCount; i++) {
      final p1Index = i * 2;
      final p2Index = i * 2 + 1;
      final p1 = bracketSlots[p1Index];
      final p2 = bracketSlots[p2Index];

      final matchRef = _tenant.tournamentMatches().doc();
      final isBye = p1 == null || p2 == null;
      final byeWinner = isBye ? (p1 ?? p2) : null;

      matches.add(
        TournamentMatch(
          id: matchRef.id,
          tournamentId: tournamentId,
          round: 1,
          matchNumber: i + 1,
          participant1Id: p1?.customerId,
          participant1Name: p1?.customerName,
          participant2Id: p2?.customerId,
          participant2Name: p2?.customerName,
          winnerId: byeWinner?.customerId,
          winnerName: byeWinner?.customerName,
          status: isBye ? MatchStatus.walkover : MatchStatus.pending,
          isBye: isBye,
        ),
      );
    }

    return matches;
  }

  /// Generates seeded bracket positions (1v8, 4v5, 3v6, 2v7 pattern)
  List<int> _generateSeededPositions(int bracketSize) {
    if (bracketSize <= 1) return [0];
    if (bracketSize == 2) return [0, 1];

    final positions = <int>[];
    _fillSeededPositions(positions, 0, bracketSize - 1, 1);
    return positions;
  }

  void _fillSeededPositions(List<int> positions, int start, int end, int seed) {
    if (start > end) return;
    if (start == end) {
      positions.add(start);
      return;
    }

    final mid = (start + end) ~/ 2;
    _fillSeededPositions(positions, start, mid, seed * 2 - 1);
    _fillSeededPositions(positions, mid + 1, end, seed * 2);
  }

  /// Process bye matches in first round
  Future<void> _processFirstRoundByes(String tournamentId) async {
    final byeMatches = await _tenant
        .tournamentMatches()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('round', isEqualTo: 1)
        .where('isBye', isEqualTo: true)
        .get();

    for (final doc in byeMatches.docs) {
      final match = TournamentMatch.fromFirestore(doc);
      if (match.winnerId != null) {
        await _advanceWinnerToNextRound(match);
      }
    }
  }

  // ============================================================
  // Match Management
  // ============================================================

  /// Records match result and advances winner
  Future<void> recordMatchResult({
    required String matchId,
    required String winnerId,
    required String winnerName,
    int? participant1Score,
    int? participant2Score,
    required AppUser completedBy,
    String? notes,
  }) async {
    final matchDoc = await _tenant.tournamentMatches().doc(matchId).get();
    if (!matchDoc.exists) {
      throw Exception('Match not found');
    }
    final match = TournamentMatch.fromFirestore(matchDoc);

    if (match.status == MatchStatus.completed) {
      throw Exception('Match is already completed');
    }

    if (winnerId != match.participant1Id && winnerId != match.participant2Id) {
      throw Exception('Winner must be one of the match participants');
    }

    final loserId = winnerId == match.participant1Id
        ? match.participant2Id
        : match.participant1Id;
    final loserName = winnerId == match.participant1Id
        ? match.participant2Name
        : match.participant1Name;

    final now = DateTime.now();
    final batch = _db.batch();

    // Update match
    batch.update(_tenant.tournamentMatches().doc(matchId), {
      'winnerId': winnerId,
      'winnerName': winnerName,
      'participant1Score': participant1Score,
      'participant2Score': participant2Score,
      'status': MatchStatus.completed.firestoreValue,
      'completedAt': Timestamp.fromDate(now),
      'completedById': completedBy.uid,
      'completedByName': completedBy.name,
      'notes': notes,
    });

    // Update winner's participant stats
    final winnerParticipantSnapshot = await _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: match.tournamentId)
        .where('customerId', isEqualTo: winnerId)
        .limit(1)
        .get();

    if (winnerParticipantSnapshot.docs.isNotEmpty) {
      batch.update(winnerParticipantSnapshot.docs.first.reference, {
        'matchesPlayed': FieldValue.increment(1),
        'matchesWon': FieldValue.increment(1),
      });
    }

    // Update loser's participant stats and mark as eliminated
    if (loserId != null) {
      final loserParticipantSnapshot = await _tenant
          .tournamentParticipants()
          .where('tournamentId', isEqualTo: match.tournamentId)
          .where('customerId', isEqualTo: loserId)
          .limit(1)
          .get();

      if (loserParticipantSnapshot.docs.isNotEmpty) {
        final loserDoc = loserParticipantSnapshot.docs.first;
        batch.update(loserDoc.reference, {
          'matchesPlayed': FieldValue.increment(1),
          'matchesLost': FieldValue.increment(1),
          'status': ParticipantStatus.eliminated.firestoreValue,
          'eliminatedAt': Timestamp.fromDate(now),
          'eliminatedInRound': match.round,
          'eliminatedByParticipantId': winnerParticipantSnapshot.docs.isNotEmpty
              ? winnerParticipantSnapshot.docs.first.id
              : null,
        });
      }
    }

    await batch.commit();

    // Get tournament to get point values
    final tournamentDoc = await _tenant
        .tournaments()
        .doc(match.tournamentId)
        .get();
    final tournament = Tournament.fromFirestore(tournamentDoc);

    // Create game match for leaderboard integration
    // Use leaderboardCategoryValue to ensure proper category mapping (e.g., 'mixed' -> 'other')
    await _createLeaderboardMatch(
      tournamentId: match.tournamentId,
      winnerId: winnerId,
      winnerName: winnerName,
      loserId: loserId,
      loserName: loserName,
      points: tournament.pointsPerWin,
      gameType: tournament.gameType.leaderboardCategoryValue,
      matchId: matchId,
      round: match.round,
      completedBy: completedBy,
    );

    // Advance winner to next round
    await _advanceWinnerToNextRound(
      match.copyWith(winnerId: winnerId, winnerName: winnerName),
    );

    AppLogger.info(
      'Match result recorded: $matchId, Winner: $winnerName',
      tag: 'TournamentService',
    );
  }

  /// Advances winner to the next round match
  Future<void> _advanceWinnerToNextRound(TournamentMatch match) async {
    // Get tournament details
    final tournamentDoc = await _tenant
        .tournaments()
        .doc(match.tournamentId)
        .get();
    final tournament = Tournament.fromFirestore(tournamentDoc);

    // Check if this was the final match
    if (match.round >= tournament.totalRounds) {
      await _completeTournament(
        tournament: tournament,
        winnerId: match.winnerId!,
        winnerName: match.winnerName!,
      );
      return;
    }

    // Calculate next round match number
    final nextRound = match.round + 1;
    final nextMatchNumber = (match.matchNumber + 1) ~/ 2;
    final slot = match.matchNumber % 2 == 1 ? 1 : 2; // 1 for top, 2 for bottom

    // Find or create next round match
    final nextMatchQuery = await _tenant
        .tournamentMatches()
        .where('tournamentId', isEqualTo: match.tournamentId)
        .where('round', isEqualTo: nextRound)
        .where('matchNumber', isEqualTo: nextMatchNumber)
        .limit(1)
        .get();

    if (nextMatchQuery.docs.isEmpty) {
      // Create next round match
      final nextMatchRef = _tenant.tournamentMatches().doc();
      final nextMatch = TournamentMatch(
        id: nextMatchRef.id,
        tournamentId: match.tournamentId,
        round: nextRound,
        matchNumber: nextMatchNumber,
        participant1Id: slot == 1 ? match.winnerId : null,
        participant1Name: slot == 1 ? match.winnerName : null,
        participant2Id: slot == 2 ? match.winnerId : null,
        participant2Name: slot == 2 ? match.winnerName : null,
      );

      await nextMatchRef.set(nextMatch.toFirestore());

      // Update current match with next match reference
      await _tenant.tournamentMatches().doc(match.id).update({
        'nextMatchId': nextMatchRef.id,
        'nextMatchSlot': slot,
      });
    } else {
      // Update existing next round match
      final nextMatchDoc = nextMatchQuery.docs.first;
      final updateData = <String, dynamic>{};

      if (slot == 1) {
        updateData['participant1Id'] = match.winnerId;
        updateData['participant1Name'] = match.winnerName;
      } else {
        updateData['participant2Id'] = match.winnerId;
        updateData['participant2Name'] = match.winnerName;
      }

      await nextMatchDoc.reference.update(updateData);

      // Update current match with next match reference
      await _tenant.tournamentMatches().doc(match.id).update({
        'nextMatchId': nextMatchDoc.id,
        'nextMatchSlot': slot,
      });
    }

    // Check and update current round if all matches in current round are complete
    await _checkAndAdvanceRound(match.tournamentId, match.round);
  }

  /// Checks if all matches in round are complete and updates tournament round
  Future<void> _checkAndAdvanceRound(String tournamentId, int round) async {
    final roundMatches = await _tenant
        .tournamentMatches()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('round', isEqualTo: round)
        .get();

    final allComplete = roundMatches.docs.every((doc) {
      final status = doc.data()['status'] as String?;
      return status == MatchStatus.completed.firestoreValue ||
          status == MatchStatus.walkover.firestoreValue;
    });

    if (allComplete) {
      await _tenant.tournaments().doc(tournamentId).update({
        'currentRound': round + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Completes the tournament
  Future<void> _completeTournament({
    required Tournament tournament,
    required String winnerId,
    required String winnerName,
  }) async {
    final batch = _db.batch();

    // Find runner-up (lost in final)
    final finalMatch = await _tenant
        .tournamentMatches()
        .where('tournamentId', isEqualTo: tournament.id)
        .where('round', isEqualTo: tournament.totalRounds)
        .limit(1)
        .get();

    String? runnerUpId;
    String? runnerUpName;
    if (finalMatch.docs.isNotEmpty) {
      final match = TournamentMatch.fromFirestore(finalMatch.docs.first);
      runnerUpId = match.participant1Id == winnerId
          ? match.participant2Id
          : match.participant1Id;
      runnerUpName = match.participant1Id == winnerId
          ? match.participant2Name
          : match.participant1Name;
    }

    // Update tournament
    batch.update(_tenant.tournaments().doc(tournament.id), {
      'status': TournamentStatus.completed.firestoreValue,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'runnerUpId': runnerUpId,
      'runnerUpName': runnerUpName,
      'endDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update winner participant
    final winnerParticipantSnapshot = await _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: tournament.id)
        .where('customerId', isEqualTo: winnerId)
        .limit(1)
        .get();

    if (winnerParticipantSnapshot.docs.isNotEmpty) {
      batch.update(winnerParticipantSnapshot.docs.first.reference, {
        'status': ParticipantStatus.winner.firestoreValue,
        'pointsEarned': FieldValue.increment(tournament.pointsForWinner),
      });
    }

    // Update runner-up points if exists
    if (runnerUpId != null) {
      final runnerUpParticipantSnapshot = await _tenant
          .tournamentParticipants()
          .where('tournamentId', isEqualTo: tournament.id)
          .where('customerId', isEqualTo: runnerUpId)
          .limit(1)
          .get();

      if (runnerUpParticipantSnapshot.docs.isNotEmpty) {
        batch.update(runnerUpParticipantSnapshot.docs.first.reference, {
          'pointsEarned': FieldValue.increment(tournament.pointsForRunnerUp),
        });
      }
    }

    await batch.commit();

    // Award final leaderboard points
    await _awardFinalPoints(
      tournament: tournament,
      winnerId: winnerId,
      winnerName: winnerName,
      runnerUpId: runnerUpId,
      runnerUpName: runnerUpName,
    );

    AppLogger.info(
      'Tournament completed: ${tournament.name}, Winner: $winnerName',
      tag: 'TournamentService',
    );
  }

  /// Creates a leaderboard match entry for tournament match
  Future<void> _createLeaderboardMatch({
    required String tournamentId,
    required String winnerId,
    required String winnerName,
    String? loserId,
    String? loserName,
    required double points,
    required String gameType,
    required String matchId,
    required int round,
    required AppUser completedBy,
  }) async {
    final now = DateTime.now();
    final matchRef = _tenant.gameMatches().doc();

    final gameMatch = GameMatch(
      id: matchRef.id,
      winnerId: winnerId,
      winnerName: winnerName,
      loserId: loserId,
      loserName: loserName,
      pointsAwarded: points,
      gameType: gameType,
      timestamp: now,
      matchDate: now,
      awardedBy: completedBy.uid,
      awardedByName: completedBy.name,
      notes: 'Tournament match (Round $round)',
      createdAt: now,
      updatedAt: now,
      isPTLMatch: false,
      isManualEntry: false,
    );

    final batch = _db.batch();

    batch.set(matchRef, gameMatch.toFirestore());

    // Update winner's leaderboard stats
    batch.update(_tenant.customers().doc(winnerId), {
      'gameStats.gamesWon': FieldValue.increment(1),
      'gameStats.totalPointsEarned': FieldValue.increment(points),
      'gameStats.currentLeaderboardPoints': FieldValue.increment(points),
      'gameStats.lastGameDate': now.toIso8601String(),
      'gameStats.lastGameResult': 'win',
      'gameStats.pointsByCategory.$gameType': FieldValue.increment(points),
      'gameStats.winsByCategory.$gameType': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update loser's stats if exists
    if (loserId != null) {
      batch.update(_tenant.customers().doc(loserId), {
        'gameStats.gamesLost': FieldValue.increment(1),
        'gameStats.lastGameDate': now.toIso8601String(),
        'gameStats.lastGameResult': 'loss',
        'gameStats.lossesByCategory.$gameType': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Awards final tournament points to winner and runner-up
  Future<void> _awardFinalPoints({
    required Tournament tournament,
    required String winnerId,
    required String winnerName,
    String? runnerUpId,
    String? runnerUpName,
  }) async {
    final batch = _db.batch();

    // Use leaderboardCategoryValue for proper category mapping (e.g., 'mixed' -> 'other')
    final leaderboardCategory = tournament.gameType.leaderboardCategoryValue;

    // Award winner bonus points (on top of per-win points already awarded)
    final winnerBonusPoints =
        tournament.pointsForWinner - tournament.pointsPerWin;
    if (winnerBonusPoints > 0) {
      batch.update(_tenant.customers().doc(winnerId), {
        'gameStats.totalPointsEarned': FieldValue.increment(winnerBonusPoints),
        'gameStats.currentLeaderboardPoints': FieldValue.increment(
          winnerBonusPoints,
        ),
        'gameStats.pointsByCategory.$leaderboardCategory': FieldValue.increment(
          winnerBonusPoints,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Award runner-up bonus points
    if (runnerUpId != null && tournament.pointsForRunnerUp > 0) {
      batch.update(_tenant.customers().doc(runnerUpId), {
        'gameStats.totalPointsEarned': FieldValue.increment(
          tournament.pointsForRunnerUp,
        ),
        'gameStats.currentLeaderboardPoints': FieldValue.increment(
          tournament.pointsForRunnerUp,
        ),
        'gameStats.pointsByCategory.$leaderboardCategory': FieldValue.increment(
          tournament.pointsForRunnerUp,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ============================================================
  // Match Scheduling
  // ============================================================

  /// Schedules a match to a specific table and time
  Future<void> scheduleMatch({
    required String matchId,
    required String tableId,
    required String tableName,
    DateTime? scheduledTime,
  }) async {
    await _tenant.tournamentMatches().doc(matchId).update({
      'tableId': tableId,
      'tableName': tableName,
      'scheduledTime': scheduledTime != null
          ? Timestamp.fromDate(scheduledTime)
          : null,
      'status': MatchStatus.scheduled.firestoreValue,
    });
  }

  /// Starts a match (marks as in progress)
  Future<void> startMatch({
    required String matchId,
    String? tableId,
    String? tableName,
  }) async {
    final updateData = <String, dynamic>{
      'status': MatchStatus.inProgress.firestoreValue,
      'startedAt': FieldValue.serverTimestamp(),
    };

    if (tableId != null) {
      updateData['tableId'] = tableId;
      updateData['tableName'] = tableName;
    }

    await _tenant.tournamentMatches().doc(matchId).update(updateData);
  }

  // ============================================================
  // Query Methods
  // ============================================================

  /// Get tournament by ID
  Future<Tournament?> getTournament(String tournamentId) async {
    final doc = await _tenant.tournaments().doc(tournamentId).get();
    if (!doc.exists) return null;
    return Tournament.fromFirestore(doc);
  }

  /// Stream of tournaments
  Stream<List<Tournament>> getTournaments({TournamentStatus? status}) {
    Query<Map<String, dynamic>> query = _tenant.tournaments().orderBy(
      'startDate',
      descending: true,
    );

    if (status != null) {
      query = query.where('status', isEqualTo: status.firestoreValue);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList(),
    );
  }

  /// Stream of tournament participants
  Stream<List<TournamentParticipant>> getTournamentParticipants(
    String tournamentId,
  ) {
    return _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: tournamentId)
        .orderBy('seed')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TournamentParticipant.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream of tournament matches
  Stream<List<TournamentMatch>> getTournamentMatches(String tournamentId) {
    return _tenant
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
  }

  /// Stream of matches for a specific round
  Stream<List<TournamentMatch>> getRoundMatches(
    String tournamentId,
    int round,
  ) {
    return _tenant
        .tournamentMatches()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('round', isEqualTo: round)
        .orderBy('matchNumber')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TournamentMatch.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get active tournaments count
  Stream<int> getActiveTournamentsCount() {
    return _tenant
        .tournaments()
        .where('status', isEqualTo: TournamentStatus.inProgress.firestoreValue)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Cancel tournament
  Future<void> cancelTournament({
    required String tournamentId,
    required AppUser cancelledBy,
    String? reason,
  }) async {
    await _tenant.tournaments().doc(tournamentId).update({
      'status': TournamentStatus.cancelled.firestoreValue,
      'cancelledById': cancelledBy.uid,
      'cancelledByName': cancelledBy.name,
      'cancelledReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.info(
      'Tournament cancelled: $tournamentId by ${cancelledBy.name}',
      tag: 'TournamentService',
    );
  }

  // ============================================================
  // Registration Request Management
  // ============================================================

  /// Creates a registration request for a tournament
  /// Anyone can request to register for a tournament
  Future<TournamentRegistration> createRegistrationRequest({
    required String tournamentId,
    required Customer customer,
    String? note,
  }) async {
    // Check tournament exists and can accept registrations
    final tournamentDoc = await _tenant.tournaments().doc(tournamentId).get();
    if (!tournamentDoc.exists) {
      throw Exception('Tournament not found');
    }
    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (tournament.status != TournamentStatus.draft &&
        tournament.status != TournamentStatus.registration) {
      throw Exception('Tournament is not accepting registrations');
    }

    if (!tournament.canAddParticipants) {
      throw Exception('Tournament is full');
    }

    // Check if customer already has a pending/approved request
    final existingRequest = await _tenant
        .tournamentRegistrations()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('customerId', isEqualTo: customer.id)
        .where(
          'status',
          whereIn: [
            RegistrationStatus.pending.firestoreValue,
            RegistrationStatus.approved.firestoreValue,
          ],
        )
        .limit(1)
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception(
        'You already have a registration request for this tournament',
      );
    }

    // Check if already a participant
    final existingParticipant = await _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('customerId', isEqualTo: customer.id)
        .limit(1)
        .get();

    if (existingParticipant.docs.isNotEmpty) {
      throw Exception('You are already registered for this tournament');
    }

    final registrationRef = _tenant.tournamentRegistrations().doc();
    final now = DateTime.now();

    final registration = TournamentRegistration(
      id: registrationRef.id,
      tournamentId: tournamentId,
      tournamentName: tournament.name,
      customerId: customer.id,
      customerName: customer.name,
      customerPhone: customer.phoneNumber,
      entryFee: tournament.entryFee,
      status: RegistrationStatus.pending,
      requestedAt: now,
      requestNote: note,
    );

    await registrationRef.set(registration.toFirestore());

    // Update tournament with pending registration count
    await _tenant.tournaments().doc(tournamentId).update({
      'pendingRegistrationCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.info(
      'Registration request created: ${customer.name} for tournament ${tournament.name}',
      tag: 'TournamentService',
    );

    return registration;
  }

  /// Approves a registration request and adds the customer as a participant
  /// Records the payment transaction
  Future<void> approveRegistrationRequest({
    required String registrationId,
    required AppUser approvedBy,
    required PaymentMethod paymentMethod,
    required double amountPaid,
    String? paymentNote,
  }) async {
    final registrationDoc = await _tenant
        .tournamentRegistrations()
        .doc(registrationId)
        .get();
    if (!registrationDoc.exists) {
      throw Exception('Registration request not found');
    }
    final registration = TournamentRegistration.fromFirestore(registrationDoc);

    if (!registration.canApprove) {
      throw Exception('Registration cannot be approved');
    }

    // Get tournament
    final tournamentDoc = await _tenant
        .tournaments()
        .doc(registration.tournamentId)
        .get();
    if (!tournamentDoc.exists) {
      throw Exception('Tournament not found');
    }
    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (!tournament.canAddParticipants) {
      throw Exception('Tournament cannot accept more participants');
    }

    // Get customer for adding as participant
    final customerDoc = await _tenant
        .customers()
        .doc(registration.customerId)
        .get();
    if (!customerDoc.exists) {
      throw Exception('Customer not found');
    }
    final customer = Customer.fromFirestore(customerDoc);

    final now = DateTime.now();
    final batch = _db.batch();

    // Create transaction for payment logging
    String? transactionId;
    if (amountPaid > 0) {
      final transactionRef = _tenant.transactions().doc();
      transactionId = transactionRef.id;

      batch.set(transactionRef, {
        'type': 'tournamentRegistration',
        'date': Timestamp.fromDate(now),
        'total': amountPaid,
        'paidTotal': amountPaid,
        'paymentMethod': paymentMethod.storageValue,
        'description': 'Tournament Registration: ${tournament.name}',
        'customerId': customer.id,
        'customerName': customer.name,
        'items': [
          {
            'name': 'Tournament Entry Fee - ${tournament.name}',
            'quantity': 1,
            'price': amountPaid,
          },
        ],
        'metadata': {
          'tournamentId': tournament.id,
          'tournamentName': tournament.name,
          'registrationId': registrationId,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': approvedBy.uid,
        'createdByName': approvedBy.name,
      });

      // If payment is via credits, deduct from customer
      if (paymentMethod == PaymentMethod.credits) {
        batch.update(_tenant.customers().doc(customer.id), {
          'creditBalance': FieldValue.increment(-amountPaid),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Add credit transaction
        final creditTxRef = _tenant.creditTransactions(customer.id).doc();
        batch.set(creditTxRef, {
          'date': Timestamp.fromDate(now),
          'amount': -amountPaid,
          'method': 'credits',
          'type': 'debit',
          'note': 'Tournament Registration: ${tournament.name}',
          'performedById': approvedBy.uid,
          'performedByName': approvedBy.name,
          'reference': {
            'type': 'tournamentRegistration',
            'tournamentId': tournament.id,
            'registrationId': registrationId,
          },
        });
      }
    }

    // Update registration status
    batch.update(registrationDoc.reference, {
      'status': RegistrationStatus.approved.firestoreValue,
      'approvedAt': Timestamp.fromDate(now),
      'approvedById': approvedBy.uid,
      'approvedByName': approvedBy.name,
      'paymentMethod': paymentMethod.storageValue,
      'amountPaid': amountPaid,
      'transactionId': transactionId,
      'paymentNote': paymentNote,
    });

    // Create participant entry
    final participantRef = _tenant.tournamentParticipants().doc();
    batch.set(participantRef, {
      'tournamentId': tournament.id,
      'customerId': customer.id,
      'customerName': customer.name,
      'customerPhoneNumber': customer.phoneNumber,
      'seed': tournament.currentParticipantCount + 1,
      'status': ParticipantStatus.registered.firestoreValue,
      'matchesPlayed': 0,
      'matchesWon': 0,
      'matchesLost': 0,
      'pointsEarned': 0.0,
      'registeredAt': Timestamp.fromDate(now),
      'hasBye': false,
      'registrationId': registrationId,
      'paymentMethod': paymentMethod.storageValue,
      'entryFeePaid': amountPaid,
    });

    // Update tournament participant count
    batch.update(_tenant.tournaments().doc(tournament.id), {
      'currentParticipantCount': FieldValue.increment(1),
      'participantIds': FieldValue.arrayUnion([customer.id]),
      'pendingRegistrationCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    AppLogger.info(
      'Registration approved: ${customer.name} for ${tournament.name}, Payment: ₹$amountPaid via ${paymentMethod.displayName}',
      tag: 'TournamentService',
    );
  }

  /// Rejects a registration request
  Future<void> rejectRegistrationRequest({
    required String registrationId,
    required AppUser rejectedBy,
    String? reason,
  }) async {
    final registrationDoc = await _tenant
        .tournamentRegistrations()
        .doc(registrationId)
        .get();
    if (!registrationDoc.exists) {
      throw Exception('Registration request not found');
    }
    final registration = TournamentRegistration.fromFirestore(registrationDoc);

    if (!registration.canReject) {
      throw Exception('Registration cannot be rejected');
    }

    final now = DateTime.now();
    final batch = _db.batch();

    // Update registration status
    batch.update(registrationDoc.reference, {
      'status': RegistrationStatus.rejected.firestoreValue,
      'rejectedAt': Timestamp.fromDate(now),
      'rejectedById': rejectedBy.uid,
      'rejectedByName': rejectedBy.name,
      'rejectionReason': reason,
    });

    // Update tournament pending count
    batch.update(_tenant.tournaments().doc(registration.tournamentId), {
      'pendingRegistrationCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    AppLogger.info(
      'Registration rejected: ${registration.customerName} for tournament ${registration.tournamentId}',
      tag: 'TournamentService',
    );
  }

  /// Cancels a pending registration request (by the customer)
  Future<void> cancelRegistrationRequest({
    required String registrationId,
  }) async {
    final registrationDoc = await _tenant
        .tournamentRegistrations()
        .doc(registrationId)
        .get();
    if (!registrationDoc.exists) {
      throw Exception('Registration request not found');
    }
    final registration = TournamentRegistration.fromFirestore(registrationDoc);

    if (registration.status != RegistrationStatus.pending) {
      throw Exception('Only pending registrations can be cancelled');
    }

    final batch = _db.batch();

    batch.update(registrationDoc.reference, {
      'status': RegistrationStatus.cancelled.firestoreValue,
    });

    batch.update(_tenant.tournaments().doc(registration.tournamentId), {
      'pendingRegistrationCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    AppLogger.info(
      'Registration cancelled: ${registration.customerName}',
      tag: 'TournamentService',
    );
  }

  /// Stream of pending registration requests for a tournament
  Stream<List<TournamentRegistration>> getPendingRegistrations(
    String tournamentId,
  ) {
    return _tenant
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
  }

  /// Stream of all registration requests for a tournament
  Stream<List<TournamentRegistration>> getAllRegistrations(
    String tournamentId,
  ) {
    return _tenant
        .tournamentRegistrations()
        .where('tournamentId', isEqualTo: tournamentId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TournamentRegistration.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get pending registration count for a tournament
  Stream<int> getPendingRegistrationCount(String tournamentId) {
    return _tenant
        .tournamentRegistrations()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('status', isEqualTo: RegistrationStatus.pending.firestoreValue)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Check if a customer has a pending/approved registration for a tournament
  Future<TournamentRegistration?> getCustomerRegistration({
    required String tournamentId,
    required String customerId,
  }) async {
    final snapshot = await _tenant
        .tournamentRegistrations()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('customerId', isEqualTo: customerId)
        .orderBy('requestedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return TournamentRegistration.fromFirestore(snapshot.docs.first);
  }

  // ============================================================
  // Public Registration Methods (for landing page - no login required)
  // ============================================================

  /// Creates a public registration request for a tournament
  /// Used from landing page where users only provide name and phone
  Future<TournamentRegistration> createPublicRegistrationRequest({
    required String tournamentId,
    required String tournamentName,
    required String customerName,
    required String customerPhoneNumber,
    required double entryFee,
    String? note,
  }) async {
    // Check tournament exists and can accept registrations
    final tournamentDoc = await _tenant.tournaments().doc(tournamentId).get();
    if (!tournamentDoc.exists) {
      throw Exception('Tournament not found');
    }
    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (tournament.status != TournamentStatus.draft &&
        tournament.status != TournamentStatus.registration) {
      throw Exception('Tournament is not accepting registrations');
    }

    if (!tournament.canAddParticipants) {
      throw Exception('Tournament is full');
    }

    // Check if phone number already has a pending/approved request
    final existingRequest = await _tenant
        .tournamentRegistrations()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('customerPhone', isEqualTo: customerPhoneNumber)
        .where(
          'status',
          whereIn: [
            RegistrationStatus.pending.firestoreValue,
            RegistrationStatus.approved.firestoreValue,
          ],
        )
        .limit(1)
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception(
        'This phone number already has a registration for this tournament',
      );
    }

    // Check if phone number is already registered as a participant
    final existingParticipant = await _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('customerPhoneNumber', isEqualTo: customerPhoneNumber)
        .limit(1)
        .get();

    if (existingParticipant.docs.isNotEmpty) {
      throw Exception(
        'This phone number is already registered for this tournament',
      );
    }

    final registrationRef = _tenant.tournamentRegistrations().doc();
    final now = DateTime.now();

    // For public registration, we don't have a customerId yet
    // Staff will link to customer during approval
    final registration = TournamentRegistration(
      id: registrationRef.id,
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      customerId: '', // Will be set during approval when linked to customer
      customerName: customerName,
      customerPhone: customerPhoneNumber,
      entryFee: entryFee,
      status: RegistrationStatus.pending,
      requestedAt: now,
      requestNote: note,
      isPublicRegistration: true, // Flag to indicate this is from landing page
    );

    await registrationRef.set(registration.toFirestore());

    // Update tournament with pending registration count
    await _tenant.tournaments().doc(tournamentId).update({
      'pendingRegistrationCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.info(
      'Public registration request created: $customerName ($customerPhoneNumber) for tournament $tournamentName',
      tag: 'TournamentService',
    );

    return registration;
  }

  /// Check if a phone number already has a registration for a tournament
  Future<TournamentRegistration?> getRegistrationByPhone({
    required String tournamentId,
    required String phoneNumber,
  }) async {
    final snapshot = await _tenant
        .tournamentRegistrations()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('customerPhone', isEqualTo: phoneNumber)
        .where(
          'status',
          whereIn: [
            RegistrationStatus.pending.firestoreValue,
            RegistrationStatus.approved.firestoreValue,
          ],
        )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return TournamentRegistration.fromFirestore(snapshot.docs.first);
  }

  /// Check if a phone number is already registered as a participant
  Future<bool> isPhoneRegisteredAsParticipant({
    required String tournamentId,
    required String phoneNumber,
  }) async {
    final snapshot = await _tenant
        .tournamentParticipants()
        .where('tournamentId', isEqualTo: tournamentId)
        .where('customerPhoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Approves a public registration request
  /// This method links the registration to an existing customer or creates a new one
  Future<void> approvePublicRegistrationRequest({
    required String registrationId,
    required AppUser approvedBy,
    required PaymentMethod paymentMethod,
    required double amountPaid,
    Customer? existingCustomer, // If linking to existing customer
    String? paymentNote,
  }) async {
    final registrationDoc = await _tenant
        .tournamentRegistrations()
        .doc(registrationId)
        .get();
    if (!registrationDoc.exists) {
      throw Exception('Registration request not found');
    }
    final registration = TournamentRegistration.fromFirestore(registrationDoc);

    if (!registration.canApprove) {
      throw Exception('Registration cannot be approved');
    }

    // Get tournament
    final tournamentDoc = await _tenant
        .tournaments()
        .doc(registration.tournamentId)
        .get();
    if (!tournamentDoc.exists) {
      throw Exception('Tournament not found');
    }
    final tournament = Tournament.fromFirestore(tournamentDoc);

    if (!tournament.canAddParticipants) {
      throw Exception('Tournament cannot accept more participants');
    }

    final now = DateTime.now();
    final batch = _db.batch();

    // Determine customer info for creating participant
    // For public registrations, customer should always be provided by the UI
    // (either existing customer found by phone, or newly created via AddCustomerScreen)
    String customerId;
    String customerName;
    String customerPhone;

    if (existingCustomer != null) {
      // Customer provided by approval dialog (found by phone or created via AddCustomerScreen)
      customerId = existingCustomer.id;
      customerName = existingCustomer.name;
      customerPhone = existingCustomer.phoneNumber;
    } else if (!registration.isPublicRegistration &&
        registration.customerId.isNotEmpty) {
      // Non-public registration with customer ID - fetch customer
      final customerDoc = await _tenant
          .customers()
          .doc(registration.customerId)
          .get();
      if (!customerDoc.exists) {
        throw Exception('Customer not found');
      }
      final customer = Customer.fromFirestore(customerDoc);
      customerId = customer.id;
      customerName = customer.name;
      customerPhone = customer.phoneNumber;
    } else {
      throw Exception(
        'Customer must be provided for public registration approval',
      );
    }

    // Create transaction for payment logging
    String? transactionId;
    if (amountPaid > 0) {
      final transactionRef = _tenant.transactions().doc();
      transactionId = transactionRef.id;

      batch.set(transactionRef, {
        'type': 'tournamentRegistration',
        'date': Timestamp.fromDate(now),
        'total': amountPaid,
        'paidTotal': amountPaid,
        'paymentMethod': paymentMethod.storageValue,
        'description': 'Tournament Registration: ${tournament.name}',
        'customerId': customerId,
        'customerName': customerName,
        'items': [
          {
            'name': 'Tournament Entry Fee - ${tournament.name}',
            'quantity': 1,
            'price': amountPaid,
          },
        ],
        'metadata': {
          'tournamentId': tournament.id,
          'tournamentName': tournament.name,
          'registrationId': registrationId,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': approvedBy.uid,
        'createdByName': approvedBy.name,
      });

      // If payment is via credits, deduct from customer
      if (paymentMethod == PaymentMethod.credits) {
        batch.update(_tenant.customers().doc(customerId), {
          'creditBalance': FieldValue.increment(-amountPaid),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Add credit transaction
        final creditTxRef = _tenant.creditTransactions(customerId).doc();
        batch.set(creditTxRef, {
          'date': Timestamp.fromDate(now),
          'amount': -amountPaid,
          'method': 'credits',
          'type': 'debit',
          'note': 'Tournament Registration: ${tournament.name}',
          'performedById': approvedBy.uid,
          'performedByName': approvedBy.name,
          'reference': {
            'type': 'tournamentRegistration',
            'tournamentId': tournament.id,
            'registrationId': registrationId,
          },
        });
      }
    }

    // Update registration status with linked customer info
    batch.update(registrationDoc.reference, {
      'status': RegistrationStatus.approved.firestoreValue,
      'customerId': customerId, // Link to the customer
      'customerName': customerName,
      'approvedAt': Timestamp.fromDate(now),
      'approvedById': approvedBy.uid,
      'approvedByName': approvedBy.name,
      'paymentMethod': paymentMethod.storageValue,
      'amountPaid': amountPaid,
      'transactionId': transactionId,
      'paymentNote': paymentNote,
    });

    // Create participant entry
    final participantRef = _tenant.tournamentParticipants().doc();
    batch.set(participantRef, {
      'tournamentId': tournament.id,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhoneNumber': customerPhone,
      'seed': tournament.currentParticipantCount + 1,
      'status': ParticipantStatus.registered.firestoreValue,
      'matchesPlayed': 0,
      'matchesWon': 0,
      'matchesLost': 0,
      'pointsEarned': 0.0,
      'registeredAt': Timestamp.fromDate(now),
      'hasBye': false,
      'registrationId': registrationId,
      'paymentMethod': paymentMethod.storageValue,
      'entryFeePaid': amountPaid,
    });

    // Update tournament participant count
    batch.update(_tenant.tournaments().doc(tournament.id), {
      'currentParticipantCount': FieldValue.increment(1),
      'participantIds': FieldValue.arrayUnion([customerId]),
      'pendingRegistrationCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    AppLogger.info(
      'Public registration approved: $customerName for ${tournament.name}, Payment: ₹$amountPaid via ${paymentMethod.displayName}',
      tag: 'TournamentService',
    );
  }

  Future<void> refundTournamentRegistration({
    required String registrationId,
    required double refundAmount,
    bool refundToCredits = false,
    PaymentMethod? refundPaymentMethod,
    required AppUser refundedBy,
    String? note,
  }) async {
    // Fetch registration
    final registrationDoc = await _tenant
        .tournamentRegistrations()
        .doc(registrationId)
        .get();
    if (!registrationDoc.exists) {
      throw Exception('Registration not found');
    }
    final registration = TournamentRegistration.fromFirestore(registrationDoc);

    if (registration.isRefunded) {
      throw Exception('Registration already refunded');
    }

    // Fetch tournament
    final tournamentDoc = await _tenant
        .tournaments()
        .doc(registration.tournamentId)
        .get();
    if (!tournamentDoc.exists) {
      throw Exception('Tournament not found');
    }
    final tournament = Tournament.fromFirestore(tournamentDoc);

    // Disallow refunds after tournament has started/completed
    if (tournament.status == TournamentStatus.inProgress ||
        tournament.status == TournamentStatus.completed) {
      throw Exception(
        'Cannot refund registration after tournament has started or completed',
      );
    }

    final paid = registration.amountPaid ?? 0.0;
    if (refundAmount > paid) {
      throw Exception('Refund amount cannot exceed amount paid (₹$paid)');
    }

    final now = DateTime.now();
    final batch = _db.batch();

    // Determine credits to refund
    double creditsRefunded = 0.0;
    final bool originalWasCredits =
        (registration.paymentMethod?.storageValue.toLowerCase() == 'credits');
    if (originalWasCredits) {
      creditsRefunded = refundAmount;
    } else if (refundToCredits) {
      creditsRefunded = refundAmount;
    }

    // Update registration
    batch.update(registrationDoc.reference, {
      'status': RegistrationStatus.cancelled.firestoreValue,
      'isRefunded': true,
      'refundAmount': refundAmount,
      'creditsRefunded': creditsRefunded,
      'refundedAt': Timestamp.fromDate(now),
      'refundedById': refundedBy.uid,
      'refundedByName': refundedBy.name,
      'refundNote': note,
      'refundPaymentMethod': refundToCredits
          ? 'credits'
          : (refundPaymentMethod?.storageValue ?? 'cash'),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Remove participant if already added
    if (registration.status == RegistrationStatus.approved) {
      final participantsQuery = await _tenant
          .tournamentParticipants()
          .where('tournamentId', isEqualTo: registration.tournamentId)
          .where('customerId', isEqualTo: registration.customerId)
          .limit(1)
          .get();

      if (participantsQuery.docs.isNotEmpty) {
        batch.delete(participantsQuery.docs.first.reference);

        batch.update(_tenant.tournaments().doc(registration.tournamentId), {
          'currentParticipantCount': FieldValue.increment(-1),
          'participantIds': FieldValue.arrayRemove([registration.customerId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
      // Pending registrations: decrement pending count
      batch.update(_tenant.tournaments().doc(registration.tournamentId), {
        'pendingRegistrationCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Update transaction if exists
    if (registration.transactionId != null) {
      batch.update(_tenant.transactions().doc(registration.transactionId), {
        'isRefunded': true,
        'refundAmount': refundAmount,
        'creditsRefunded': creditsRefunded,
        'refundedAt': Timestamp.fromDate(now),
        'refundedById': refundedBy.uid,
        'refundedByName': refundedBy.name,
        'refundNote': note,
        'refundPaymentMethod': refundToCredits
            ? 'credits'
            : (refundPaymentMethod?.storageValue ?? 'cash'),
      });
    }

    // Refund credits to customer if needed
    if (creditsRefunded > 0 && registration.customerId.isNotEmpty) {
      batch.update(_tenant.customers().doc(registration.customerId), {
        'creditBalance': FieldValue.increment(creditsRefunded),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final creditTxRef = _tenant
          .creditTransactions(registration.customerId)
          .doc();
      batch.set(creditTxRef, {
        'type': 'refund',
        'amount': creditsRefunded,
        'balance': 0, // client can recompute
        'description': 'Tournament Registration Refund: ${tournament.name}',
        'method': 'credits',
        'date': Timestamp.fromDate(now),
        'createdById': refundedBy.uid,
        'createdByName': refundedBy.name,
        'metadata': {
          'tournamentId': tournament.id,
          'tournamentName': tournament.name,
          'registrationId': registrationId,
        },
      });
    }

    await batch.commit();

    AppLogger.info(
      'Tournament registration refunded: ${registration.customerName} from ${tournament.name}, Amount: ₹$refundAmount',
      tag: 'TournamentService',
    );
  }
}
