import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

enum TournamentFormat { singleElimination, doubleElimination, roundRobin }

extension TournamentFormatExtension on TournamentFormat {
  String get displayName {
    switch (this) {
      case TournamentFormat.singleElimination:
        return 'Single Elimination';
      case TournamentFormat.doubleElimination:
        return 'Double Elimination';
      case TournamentFormat.roundRobin:
        return 'Round Robin';
    }
  }

  String get firestoreValue => name;

  static TournamentFormat fromString(String value) {
    return TournamentFormat.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TournamentFormat.singleElimination,
    );
  }
}

enum TournamentStatus { draft, registration, inProgress, completed, cancelled }

extension TournamentStatusExtension on TournamentStatus {
  String get displayName {
    switch (this) {
      case TournamentStatus.draft:
        return 'Draft';
      case TournamentStatus.registration:
        return 'Registration Open';
      case TournamentStatus.inProgress:
        return 'In Progress';
      case TournamentStatus.completed:
        return 'Completed';
      case TournamentStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get firestoreValue => name;

  static TournamentStatus fromString(String value) {
    return TournamentStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TournamentStatus.draft,
    );
  }
}

enum TournamentGameType { snooker, pool, carrom, darts, ps5, mixed }

extension TournamentGameTypeExtension on TournamentGameType {
  String get displayName {
    switch (this) {
      case TournamentGameType.snooker:
        return 'Snooker';
      case TournamentGameType.pool:
        return 'Pool';
      case TournamentGameType.carrom:
        return 'Carrom';
      case TournamentGameType.darts:
        return 'Darts';
      case TournamentGameType.ps5:
        return 'PS5';
      case TournamentGameType.mixed:
        return 'Mixed';
    }
  }

  String get firestoreValue => name;

  /// Maps to leaderboard game category key (e.g. snooker, pool) for point tracking
  /// 'mixed' maps to 'other' for leaderboard compatibility
  String get leaderboardCategoryValue {
    if (this == TournamentGameType.mixed) return 'other';
    return name;
  }

  static TournamentGameType fromString(String value) {
    return TournamentGameType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TournamentGameType.snooker,
    );
  }
}

class Tournament {
  final String id;
  final String name;
  final String? description;
  final TournamentFormat format;
  final TournamentStatus status;
  final TournamentGameType gameType;
  final DateTime startDate;
  final DateTime? endDate;
  final int maxParticipants;
  final int minParticipants; // Minimum participants to start (default 2)
  final int currentParticipantCount;
  final bool hasNoMaxLimit; // If true, no maximum limit on participants
  final double entryFee;
  final double prizePool;
  final int currentRound;
  final int totalRounds;
  final String? winnerId;
  final String? winnerName;
  final String? runnerUpId;
  final String? runnerUpName;
  final double pointsForWinner;
  final double pointsForRunnerUp;
  final double pointsPerWin;
  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> participantIds;
  final String? preferredTableId;
  final String? preferredTableName;
  final Map<String, dynamic>? rules;
  final bool isSeeded;
  final bool autoGenerateBracket;
  final int pendingRegistrationCount;

  /// When true, tournament may appear on the public landing page (collectionGroup query).
  final bool showOnPublicLanding;

  Tournament({
    required this.id,
    required this.name,
    this.description,
    required this.format,
    required this.status,
    required this.gameType,
    required this.startDate,
    this.endDate,
    this.maxParticipants = 0, // 0 means no limit
    this.minParticipants = 2,
    this.currentParticipantCount = 0,
    this.hasNoMaxLimit = false,
    this.entryFee = 0.0,
    this.prizePool = 0.0,
    this.currentRound = 0,
    this.totalRounds = 0,
    this.winnerId,
    this.winnerName,
    this.runnerUpId,
    this.runnerUpName,
    this.pointsForWinner = 100.0,
    this.pointsForRunnerUp = 50.0,
    this.pointsPerWin = 10.0,
    required this.createdById,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.participantIds = const [],
    this.preferredTableId,
    this.preferredTableName,
    this.rules,
    this.isSeeded = false,
    this.autoGenerateBracket = true,
    this.pendingRegistrationCount = 0,
    this.showOnPublicLanding = false,
  });

  /// Calculate total rounds for single elimination based on participant count
  static int calculateTotalRounds(int participantCount) {
    if (participantCount <= 1) return 0;
    int rounds = 0;
    int n = 1;
    while (n < participantCount) {
      n *= 2;
      rounds++;
    }
    return rounds;
  }

  /// Get the next power of 2 for bracket sizing
  static int getNextPowerOfTwo(int n) {
    if (n <= 1) return 1;
    int power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }

  factory Tournament.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tournament(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      format: TournamentFormatExtension.fromString(
        data['format'] as String? ?? 'singleElimination',
      ),
      status: TournamentStatusExtension.fromString(
        data['status'] as String? ?? 'draft',
      ),
      gameType: TournamentGameTypeExtension.fromString(
        data['gameType'] as String? ?? 'snooker',
      ),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      maxParticipants: parseFirestoreInt(data['maxParticipants']),
      minParticipants: parseFirestoreInt(data['minParticipants'], fallback: 2),
      currentParticipantCount: parseFirestoreInt(
        data['currentParticipantCount'],
      ),
      hasNoMaxLimit:
          data['hasNoMaxLimit'] as bool? ??
          parseFirestoreInt(data['maxParticipants']) == 0,
      entryFee: parseFirestoreDouble(data['entryFee']),
      prizePool: parseFirestoreDouble(data['prizePool']),
      currentRound: parseFirestoreInt(data['currentRound']),
      totalRounds: parseFirestoreInt(data['totalRounds']),
      winnerId: data['winnerId'] as String?,
      winnerName: data['winnerName'] as String?,
      runnerUpId: data['runnerUpId'] as String?,
      runnerUpName: data['runnerUpName'] as String?,
      pointsForWinner: parseFirestoreDouble(
        data['pointsForWinner'],
        fallback: 100.0,
      ),
      pointsForRunnerUp: parseFirestoreDouble(
        data['pointsForRunnerUp'],
        fallback: 50.0,
      ),
      pointsPerWin: parseFirestoreDouble(data['pointsPerWin'], fallback: 10.0),
      createdById: data['createdById'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participantIds: () {
        final raw = data['participantIds'];
        if (raw is! List) return <String>[];
        return raw.map((e) => e.toString()).toList();
      }(),
      preferredTableId: data['preferredTableId'] as String?,
      preferredTableName: data['preferredTableName'] as String?,
      rules: data['rules'] as Map<String, dynamic>?,
      isSeeded: data['isSeeded'] as bool? ?? false,
      autoGenerateBracket: data['autoGenerateBracket'] as bool? ?? true,
      pendingRegistrationCount: parseFirestoreInt(
        data['pendingRegistrationCount'],
      ),
      showOnPublicLanding: data['showOnPublicLanding'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'format': format.firestoreValue,
      'status': status.firestoreValue,
      'gameType': gameType.firestoreValue,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'maxParticipants': maxParticipants,
      'minParticipants': minParticipants,
      'currentParticipantCount': currentParticipantCount,
      'hasNoMaxLimit': hasNoMaxLimit,
      'entryFee': entryFee,
      'prizePool': prizePool,
      'currentRound': currentRound,
      'totalRounds': totalRounds,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'runnerUpId': runnerUpId,
      'runnerUpName': runnerUpName,
      'pointsForWinner': pointsForWinner,
      'pointsForRunnerUp': pointsForRunnerUp,
      'pointsPerWin': pointsPerWin,
      'createdById': createdById,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'participantIds': participantIds,
      'preferredTableId': preferredTableId,
      'preferredTableName': preferredTableName,
      'rules': rules,
      'isSeeded': isSeeded,
      'autoGenerateBracket': autoGenerateBracket,
      'pendingRegistrationCount': pendingRegistrationCount,
      'showOnPublicLanding': showOnPublicLanding,
    };
  }

  Tournament copyWith({
    String? id,
    String? name,
    String? description,
    bool clearDescription = false,
    TournamentFormat? format,
    TournamentStatus? status,
    TournamentGameType? gameType,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    int? maxParticipants,
    int? minParticipants,
    int? currentParticipantCount,
    bool? hasNoMaxLimit,
    double? entryFee,
    double? prizePool,
    int? currentRound,
    int? totalRounds,
    String? winnerId,
    bool clearWinnerId = false,
    String? winnerName,
    String? runnerUpId,
    bool clearRunnerUpId = false,
    String? runnerUpName,
    double? pointsForWinner,
    double? pointsForRunnerUp,
    double? pointsPerWin,
    String? createdById,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? participantIds,
    String? preferredTableId,
    bool clearPreferredTable = false,
    String? preferredTableName,
    Map<String, dynamic>? rules,
    bool? isSeeded,
    bool? autoGenerateBracket,
    int? pendingRegistrationCount,
    bool? showOnPublicLanding,
  }) {
    return Tournament(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      format: format ?? this.format,
      status: status ?? this.status,
      gameType: gameType ?? this.gameType,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      maxParticipants: maxParticipants ?? this.maxParticipants,
      minParticipants: minParticipants ?? this.minParticipants,
      currentParticipantCount:
          currentParticipantCount ?? this.currentParticipantCount,
      hasNoMaxLimit: hasNoMaxLimit ?? this.hasNoMaxLimit,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      winnerId: clearWinnerId ? null : (winnerId ?? this.winnerId),
      winnerName: winnerName ?? this.winnerName,
      runnerUpId: clearRunnerUpId ? null : (runnerUpId ?? this.runnerUpId),
      runnerUpName: runnerUpName ?? this.runnerUpName,
      pointsForWinner: pointsForWinner ?? this.pointsForWinner,
      pointsForRunnerUp: pointsForRunnerUp ?? this.pointsForRunnerUp,
      pointsPerWin: pointsPerWin ?? this.pointsPerWin,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participantIds: participantIds ?? this.participantIds,
      preferredTableId: clearPreferredTable
          ? null
          : (preferredTableId ?? this.preferredTableId),
      preferredTableName: preferredTableName ?? this.preferredTableName,
      rules: rules ?? this.rules,
      isSeeded: isSeeded ?? this.isSeeded,
      autoGenerateBracket: autoGenerateBracket ?? this.autoGenerateBracket,
      pendingRegistrationCount:
          pendingRegistrationCount ?? this.pendingRegistrationCount,
      showOnPublicLanding: showOnPublicLanding ?? this.showOnPublicLanding,
    );
  }

  /// Check if tournament can accept more participants
  bool get canAddParticipants {
    if (status != TournamentStatus.draft &&
        status != TournamentStatus.registration) {
      return false;
    }
    // If no max limit, always allow adding
    if (hasNoMaxLimit || maxParticipants == 0) return true;
    // Otherwise check against max
    return currentParticipantCount < maxParticipants;
  }

  /// Check if tournament has enough participants to start
  bool get canStart => currentParticipantCount >= minParticipants;

  /// Get effective max participants (for display)
  String get maxParticipantsDisplay {
    if (hasNoMaxLimit || maxParticipants == 0) return 'Unlimited';
    return maxParticipants.toString();
  }

  /// Check if tournament has started
  bool get hasStarted =>
      status == TournamentStatus.inProgress ||
      status == TournamentStatus.completed;

  /// Check if tournament is editable
  bool get isEditable =>
      status == TournamentStatus.draft ||
      status == TournamentStatus.registration;

  /// Get number of byes needed for bracket
  int get byesNeeded {
    final bracketSize = getNextPowerOfTwo(currentParticipantCount);
    return bracketSize - currentParticipantCount;
  }

  /// Get round name
  String getRoundName(int round) {
    if (totalRounds <= 0) return 'Round $round';
    final roundFromEnd = totalRounds - round + 1;
    switch (roundFromEnd) {
      case 1:
        return 'Final';
      case 2:
        return 'Semi-Finals';
      case 3:
        return 'Quarter-Finals';
      case 4:
        return 'Round of 16';
      case 5:
        return 'Round of 32';
      default:
        return 'Round $round';
    }
  }
}

class TournamentParticipant {
  final String id;
  final String tournamentId;
  final String customerId;
  final String customerName;
  final String? customerPhoneNumber;
  final int seed;
  final ParticipantStatus status;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final double pointsEarned;
  final DateTime registeredAt;
  final DateTime? eliminatedAt;
  final int? eliminatedInRound;
  final String? eliminatedByParticipantId;
  final bool hasBye;

  TournamentParticipant({
    required this.id,
    required this.tournamentId,
    required this.customerId,
    required this.customerName,
    this.customerPhoneNumber,
    this.seed = 0,
    this.status = ParticipantStatus.registered,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.pointsEarned = 0.0,
    required this.registeredAt,
    this.eliminatedAt,
    this.eliminatedInRound,
    this.eliminatedByParticipantId,
    this.hasBye = false,
  });

  factory TournamentParticipant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TournamentParticipant(
      id: doc.id,
      tournamentId: data['tournamentId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhoneNumber: data['customerPhoneNumber'] as String?,
      seed: parseFirestoreInt(data['seed']),
      status: ParticipantStatusExtension.fromString(
        data['status'] as String? ?? 'registered',
      ),
      matchesPlayed: parseFirestoreInt(data['matchesPlayed']),
      matchesWon: parseFirestoreInt(data['matchesWon']),
      matchesLost: parseFirestoreInt(data['matchesLost']),
      pointsEarned: parseFirestoreDouble(data['pointsEarned']),
      registeredAt:
          (data['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eliminatedAt: (data['eliminatedAt'] as Timestamp?)?.toDate(),
      eliminatedInRound: parseFirestoreIntOrNull(data['eliminatedInRound']),
      eliminatedByParticipantId: data['eliminatedByParticipantId'] as String?,
      hasBye: data['hasBye'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhoneNumber': customerPhoneNumber,
      'seed': seed,
      'status': status.firestoreValue,
      'matchesPlayed': matchesPlayed,
      'matchesWon': matchesWon,
      'matchesLost': matchesLost,
      'pointsEarned': pointsEarned,
      'registeredAt': Timestamp.fromDate(registeredAt),
      'eliminatedAt': eliminatedAt != null
          ? Timestamp.fromDate(eliminatedAt!)
          : null,
      'eliminatedInRound': eliminatedInRound,
      'eliminatedByParticipantId': eliminatedByParticipantId,
      'hasBye': hasBye,
    };
  }

  TournamentParticipant copyWith({
    String? id,
    String? tournamentId,
    String? customerId,
    String? customerName,
    String? customerPhoneNumber,
    int? seed,
    ParticipantStatus? status,
    int? matchesPlayed,
    int? matchesWon,
    int? matchesLost,
    double? pointsEarned,
    DateTime? registeredAt,
    DateTime? eliminatedAt,
    bool clearEliminatedAt = false,
    int? eliminatedInRound,
    String? eliminatedByParticipantId,
    bool? hasBye,
  }) {
    return TournamentParticipant(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhoneNumber: customerPhoneNumber ?? this.customerPhoneNumber,
      seed: seed ?? this.seed,
      status: status ?? this.status,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      matchesWon: matchesWon ?? this.matchesWon,
      matchesLost: matchesLost ?? this.matchesLost,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      registeredAt: registeredAt ?? this.registeredAt,
      eliminatedAt: clearEliminatedAt
          ? null
          : (eliminatedAt ?? this.eliminatedAt),
      eliminatedInRound: eliminatedInRound ?? this.eliminatedInRound,
      eliminatedByParticipantId:
          eliminatedByParticipantId ?? this.eliminatedByParticipantId,
      hasBye: hasBye ?? this.hasBye,
    );
  }

  double get winRate {
    if (matchesPlayed == 0) return 0.0;
    return (matchesWon / matchesPlayed) * 100;
  }
}

enum ParticipantStatus { registered, active, eliminated, winner, withdrawn }

extension ParticipantStatusExtension on ParticipantStatus {
  String get displayName {
    switch (this) {
      case ParticipantStatus.registered:
        return 'Registered';
      case ParticipantStatus.active:
        return 'Active';
      case ParticipantStatus.eliminated:
        return 'Eliminated';
      case ParticipantStatus.winner:
        return 'Winner';
      case ParticipantStatus.withdrawn:
        return 'Withdrawn';
    }
  }

  String get firestoreValue => name;

  static ParticipantStatus fromString(String value) {
    return ParticipantStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ParticipantStatus.registered,
    );
  }
}

class TournamentMatch {
  final String id;
  final String tournamentId;
  final int round;
  final int matchNumber;
  final String? participant1Id;
  final String? participant1Name;
  final String? participant2Id;
  final String? participant2Name;
  final String? winnerId;
  final String? winnerName;
  final int? participant1Score;
  final int? participant2Score;
  final MatchStatus status;
  final String? tableId;
  final String? tableName;
  final String? sessionId;
  final DateTime? scheduledTime;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completedById;
  final String? completedByName;
  final bool isBye;
  final String? nextMatchId;
  final int? nextMatchSlot; // 1 or 2 for winner bracket position
  final String? notes;

  TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
    required this.matchNumber,
    this.participant1Id,
    this.participant1Name,
    this.participant2Id,
    this.participant2Name,
    this.winnerId,
    this.winnerName,
    this.participant1Score,
    this.participant2Score,
    this.status = MatchStatus.pending,
    this.tableId,
    this.tableName,
    this.sessionId,
    this.scheduledTime,
    this.startedAt,
    this.completedAt,
    this.completedById,
    this.completedByName,
    this.isBye = false,
    this.nextMatchId,
    this.nextMatchSlot,
    this.notes,
  });

  factory TournamentMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TournamentMatch(
      id: doc.id,
      tournamentId: data['tournamentId'] as String? ?? '',
      round: parseFirestoreInt(data['round'], fallback: 1),
      matchNumber: parseFirestoreInt(data['matchNumber'], fallback: 1),
      participant1Id: data['participant1Id'] as String?,
      participant1Name: data['participant1Name'] as String?,
      participant2Id: data['participant2Id'] as String?,
      participant2Name: data['participant2Name'] as String?,
      winnerId: data['winnerId'] as String?,
      winnerName: data['winnerName'] as String?,
      participant1Score: parseFirestoreIntOrNull(data['participant1Score']),
      participant2Score: parseFirestoreIntOrNull(data['participant2Score']),
      status: MatchStatusExtension.fromString(
        data['status'] as String? ?? 'pending',
      ),
      tableId: data['tableId'] as String?,
      tableName: data['tableName'] as String?,
      sessionId: data['sessionId'] as String?,
      scheduledTime: (data['scheduledTime'] as Timestamp?)?.toDate(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      completedById: data['completedById'] as String?,
      completedByName: data['completedByName'] as String?,
      isBye: data['isBye'] as bool? ?? false,
      nextMatchId: data['nextMatchId'] as String?,
      nextMatchSlot: parseFirestoreIntOrNull(data['nextMatchSlot']),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'round': round,
      'matchNumber': matchNumber,
      'participant1Id': participant1Id,
      'participant1Name': participant1Name,
      'participant2Id': participant2Id,
      'participant2Name': participant2Name,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'participant1Score': participant1Score,
      'participant2Score': participant2Score,
      'status': status.firestoreValue,
      'tableId': tableId,
      'tableName': tableName,
      'sessionId': sessionId,
      'scheduledTime': scheduledTime != null
          ? Timestamp.fromDate(scheduledTime!)
          : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'completedById': completedById,
      'completedByName': completedByName,
      'isBye': isBye,
      'nextMatchId': nextMatchId,
      'nextMatchSlot': nextMatchSlot,
      'notes': notes,
    };
  }

  TournamentMatch copyWith({
    String? id,
    String? tournamentId,
    int? round,
    int? matchNumber,
    String? participant1Id,
    bool clearParticipant1 = false,
    String? participant1Name,
    String? participant2Id,
    bool clearParticipant2 = false,
    String? participant2Name,
    String? winnerId,
    bool clearWinner = false,
    String? winnerName,
    int? participant1Score,
    int? participant2Score,
    MatchStatus? status,
    String? tableId,
    bool clearTable = false,
    String? tableName,
    String? sessionId,
    bool clearSession = false,
    DateTime? scheduledTime,
    bool clearScheduledTime = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? completedById,
    String? completedByName,
    bool? isBye,
    String? nextMatchId,
    int? nextMatchSlot,
    String? notes,
  }) {
    return TournamentMatch(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      round: round ?? this.round,
      matchNumber: matchNumber ?? this.matchNumber,
      participant1Id: clearParticipant1
          ? null
          : (participant1Id ?? this.participant1Id),
      participant1Name: participant1Name ?? this.participant1Name,
      participant2Id: clearParticipant2
          ? null
          : (participant2Id ?? this.participant2Id),
      participant2Name: participant2Name ?? this.participant2Name,
      winnerId: clearWinner ? null : (winnerId ?? this.winnerId),
      winnerName: winnerName ?? this.winnerName,
      participant1Score: participant1Score ?? this.participant1Score,
      participant2Score: participant2Score ?? this.participant2Score,
      status: status ?? this.status,
      tableId: clearTable ? null : (tableId ?? this.tableId),
      tableName: tableName ?? this.tableName,
      sessionId: clearSession ? null : (sessionId ?? this.sessionId),
      scheduledTime: clearScheduledTime
          ? null
          : (scheduledTime ?? this.scheduledTime),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      completedById: completedById ?? this.completedById,
      completedByName: completedByName ?? this.completedByName,
      isBye: isBye ?? this.isBye,
      nextMatchId: nextMatchId ?? this.nextMatchId,
      nextMatchSlot: nextMatchSlot ?? this.nextMatchSlot,
      notes: notes ?? this.notes,
    );
  }

  /// Check if match is ready to be played
  bool get isReady =>
      participant1Id != null &&
      participant2Id != null &&
      status == MatchStatus.pending &&
      !isBye;

  /// Check if match is a bye (auto-win)
  bool get isAutoWin => isBye || participant2Id == null;

  /// Get display title for match
  String get displayTitle {
    final p1 = participant1Name ?? 'TBD';
    final p2 = isBye ? 'BYE' : (participant2Name ?? 'TBD');
    return '$p1 vs $p2';
  }

  /// Get score display
  String get scoreDisplay {
    if (participant1Score == null && participant2Score == null) return '-';
    return '${participant1Score ?? 0} - ${participant2Score ?? 0}';
  }
}

enum MatchStatus {
  pending,
  scheduled,
  inProgress,
  completed,
  cancelled,
  walkover,
}

extension MatchStatusExtension on MatchStatus {
  String get displayName {
    switch (this) {
      case MatchStatus.pending:
        return 'Pending';
      case MatchStatus.scheduled:
        return 'Scheduled';
      case MatchStatus.inProgress:
        return 'In Progress';
      case MatchStatus.completed:
        return 'Completed';
      case MatchStatus.cancelled:
        return 'Cancelled';
      case MatchStatus.walkover:
        return 'Walkover';
    }
  }

  String get firestoreValue => name;

  static MatchStatus fromString(String value) {
    return MatchStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MatchStatus.pending,
    );
  }
}
