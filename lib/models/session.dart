import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../utils/firestore_utils.dart';
import 'table.dart';

List<String> _firestoreStringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList();
}

enum PaymentMode { cash, credit, upi }

enum SessionStatus { active, completed, cancelled }

class TableSession {
  final String id;
  final String tableId;
  final String tableName;
  final TablePurpose tablePurpose;
  final String customerId;
  final String customerName;
  final String? customerPhoneNumber;
  final DateTime startTime;
  final DateTime? endTime;
  final double hourlyRate;

  /// Bill amount after discounts, before payment by credits.
  final double? totalAmount;
  final PaymentMode paymentMode;
  final SessionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? creditsUsed;
  final double? creditsEarned;
  final Map<String, dynamic>? discountsApplied;
  final double? totalCafeAmount;
  final double? totalMerchandiseAmount;

  /// Cached final bill (table + orders) when session completed.
  final double? totalBillAmount;

  /// Whether the table for this session should charge at least one full hour.
  final bool chargeMinimumOneHour;

  /// Minimum billable minutes for this session. When set (>0),
  /// this overrides [chargeMinimumOneHour] behavior for calculating table charges.
  final int? minimumBillableMinutes;
  final List<String> cafeOrderIds;
  final List<String> merchandiseOrderIds;
  final bool hasUnbilledOrders;

  /// When true, this session is played in "Player That Loses (PTL)" mode, meaning
  /// the player who loses the game settles the entire bill.
  final bool isPTL;

  /// Number of players that participated in this PTL session. Valid only when
  /// [isPTL] is true. Values are expected between 1-6.
  final int? playerCount;

  /// Whether the session timer is currently paused.
  final bool isPaused;

  /// When the session was paused. Null if not currently paused.
  final DateTime? pausedAt;

  /// Total accumulated duration the session has been paused (in seconds).
  /// This is used to calculate the actual billable duration.
  final int totalPausedSeconds;

  /// Number of 5-minute breaks completed during this session.
  final int breaksTaken;

  /// Whether the session is currently on a scheduled 5-minute break.
  final bool isOnBreak;

  /// When the current break started. Null if not on break.
  final DateTime? breakStartedAt;

  /// Index (1-based) of the player that lost and therefore pays the bill.
  /// This will be `null` until the session is completed and a loser is picked.
  final int? loserPlayerIndex;
  final List<String> playerIds;
  final List<String> playerNames;
  final String? startedById;
  final String? startedByName;
  final String? completedById;
  final String? completedByName;
  final String? startedByRole;
  final String? completedByRole;
  final bool isRefunded;
  final double? refundAmount;
  final DateTime? refundedAt;
  final String? refundedById;
  final String? refundedByName;
  final String? refundedByRole;

  /// Credits that have been refunded from this session (for partial refunds tracking).
  final double? creditsRefunded;

  /// Raw Firestore data for accessing dynamic fields.
  final Map<String, dynamic> data;

  /// True while checkout holds a billing lock on this session document.
  bool get billingInProgress => data['billingInProgress'] == true;

  final double? tableChargesAtCheckout;
  final double? grossAmount;
  final List<Map<String, dynamic>> activityLog;

  TableSession({
    required this.id,
    required this.tableId,
    required this.tableName,
    this.tablePurpose = TablePurpose.gaming,
    required this.customerId,
    required this.customerName,
    this.customerPhoneNumber,
    required this.startTime,
    this.endTime,
    required this.hourlyRate,
    this.totalAmount,
    required this.paymentMode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.creditsUsed,
    this.creditsEarned,
    this.discountsApplied,
    this.totalCafeAmount = 0.0,
    this.totalMerchandiseAmount = 0.0,
    this.totalBillAmount,
    this.chargeMinimumOneHour = false,
    this.minimumBillableMinutes,
    this.cafeOrderIds = const [],
    this.merchandiseOrderIds = const [],
    this.hasUnbilledOrders = false,
    this.playerIds = const [],
    this.playerNames = const [],
    this.startedById,
    this.startedByName,
    this.completedById,
    this.completedByName,
    this.startedByRole,
    this.completedByRole,
    this.isPTL = false,
    this.playerCount,
    this.loserPlayerIndex,
    this.isPaused = false,
    this.pausedAt,
    this.totalPausedSeconds = 0,
    this.breaksTaken = 0,
    this.isOnBreak = false,
    this.breakStartedAt,
    this.isRefunded = false,
    this.refundAmount,
    this.refundedAt,
    this.refundedById,
    this.refundedByName,
    this.refundedByRole,
    this.creditsRefunded,
    this.data = const {},
    this.tableChargesAtCheckout,
    this.grossAmount,
    this.activityLog = const [],
  });

  factory TableSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TableSession(
      id: doc.id,
      tableId: data['tableId'] as String? ?? '',
      tableName: data['tableName'] as String? ?? '',
      tablePurpose: parseTablePurpose(data['tablePurpose']),
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhoneNumber: data['customerPhoneNumber'] as String?,
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      hourlyRate: parseFirestoreDouble(data['hourlyRate']),
      totalAmount:
          parseFirestoreDoubleOrNull(data['totalAmount']) ??
          parseFirestoreDoubleOrNull(data['totalBillAmount']),
      paymentMode: PaymentMode.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            (data['paymentMode'] as String?)?.toLowerCase(),
        orElse: () => PaymentMode.cash,
      ),
      status: SessionStatus.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            (data['status'] as String?)?.toLowerCase(),
        orElse: () => SessionStatus.completed,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      creditsUsed: parseFirestoreDoubleOrNull(data['creditsUsed']),
      creditsEarned: parseFirestoreDoubleOrNull(data['creditsEarned']),
      discountsApplied: data['discountsApplied'] as Map<String, dynamic>?,
      totalCafeAmount: parseFirestoreDouble(data['totalCafeAmount']),
      totalMerchandiseAmount: parseFirestoreDouble(
        data['totalMerchandiseAmount'],
      ),
      totalBillAmount: parseFirestoreDoubleOrNull(data['totalBillAmount']),
      chargeMinimumOneHour: data['chargeMinimumOneHour'] as bool? ?? false,
      minimumBillableMinutes: parseFirestoreIntOrNull(
        data['minimumBillableMinutes'],
      ),
      cafeOrderIds: _firestoreStringList(data['cafeOrderIds']),
      merchandiseOrderIds: _firestoreStringList(data['merchandiseOrderIds']),
      hasUnbilledOrders: data['hasUnbilledOrders'] as bool? ?? false,
      playerIds: _firestoreStringList(data['playerIds']),
      playerNames: _firestoreStringList(data['playerNames']),
      startedById: data['startedById'] as String?,
      startedByName: data['startedByName'] as String?,
      completedById: data['completedById'] as String?,
      completedByName: data['completedByName'] as String?,
      startedByRole: data['startedByRole'] as String?,
      completedByRole: data['completedByRole'] as String?,
      isPTL: data['isPTL'] as bool? ?? false,
      playerCount: parseFirestoreIntOrNull(data['playerCount']),
      loserPlayerIndex: parseFirestoreIntOrNull(data['loserPlayerIndex']),
      isPaused: data['isPaused'] as bool? ?? false,
      pausedAt: (data['pausedAt'] as Timestamp?)?.toDate(),
      totalPausedSeconds: parseFirestoreInt(data['totalPausedSeconds']),
      breaksTaken: parseFirestoreInt(data['breaksTaken']),
      isOnBreak: data['isOnBreak'] as bool? ?? false,
      breakStartedAt: (data['breakStartedAt'] as Timestamp?)?.toDate(),
      isRefunded: data['isRefunded'] as bool? ?? false,
      refundAmount: parseFirestoreDoubleOrNull(data['refundAmount']),
      refundedAt: (data['refundedAt'] as Timestamp?)?.toDate(),
      refundedById: data['refundedById'] as String?,
      refundedByName: data['refundedByName'] as String?,
      refundedByRole: data['refundedByRole'] as String?,
      creditsRefunded: parseFirestoreDoubleOrNull(data['creditsRefunded']),
      data: data,
      tableChargesAtCheckout: parseFirestoreDoubleOrNull(
        data['tableChargesAtCheckout'],
      ),
      grossAmount: parseFirestoreDoubleOrNull(data['grossAmount']),
      activityLog:
          (data['activityLog'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tableId': tableId,
      'tableName': tableName,
      'tablePurpose': tablePurpose.name,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhoneNumber': customerPhoneNumber,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'hourlyRate': hourlyRate,
      'totalAmount': totalAmount,
      'paymentMode': paymentMode.toString().split('.').last.toLowerCase(),
      'status': status.toString().split('.').last.toLowerCase(),
      'createdAt':
          createdAt.isAtSameMomentAs(DateTime.fromMillisecondsSinceEpoch(0))
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'creditsUsed': creditsUsed,
      'creditsEarned': creditsEarned,
      'discountsApplied': discountsApplied,
      'totalCafeAmount': totalCafeAmount,
      'totalMerchandiseAmount': totalMerchandiseAmount,
      'totalBillAmount': totalBillAmount,
      'chargeMinimumOneHour': chargeMinimumOneHour,
      if (minimumBillableMinutes != null)
        'minimumBillableMinutes': minimumBillableMinutes,
      'cafeOrderIds': cafeOrderIds,
      'merchandiseOrderIds': merchandiseOrderIds,
      'hasUnbilledOrders': hasUnbilledOrders,
      'playerIds': playerIds,
      'playerNames': playerNames,
      'startedById': startedById,
      'startedByName': startedByName,
      'completedById': completedById,
      'completedByName': completedByName,
      'startedByRole': startedByRole,
      'completedByRole': completedByRole,
      'isPTL': isPTL,
      'playerCount': playerCount,
      'loserPlayerIndex': loserPlayerIndex,
      'isPaused': isPaused,
      'pausedAt': pausedAt != null ? Timestamp.fromDate(pausedAt!) : null,
      'totalPausedSeconds': totalPausedSeconds,
      'breaksTaken': breaksTaken,
      'isOnBreak': isOnBreak,
      'breakStartedAt': breakStartedAt != null
          ? Timestamp.fromDate(breakStartedAt!)
          : null,
      'isRefunded': isRefunded,
      if (refundAmount != null) 'refundAmount': refundAmount,
      'refundedAt': refundedAt != null ? Timestamp.fromDate(refundedAt!) : null,
      'refundedById': refundedById,
      'refundedByName': refundedByName,
      'refundedByRole': refundedByRole,
      if (creditsRefunded != null) 'creditsRefunded': creditsRefunded,
      if (tableChargesAtCheckout != null)
        'tableChargesAtCheckout': tableChargesAtCheckout,
      if (grossAmount != null) 'grossAmount': grossAmount,
      if (activityLog.isNotEmpty) 'activityLog': activityLog,
    };
  }

  TableSession copyWith({
    String? id,
    String? tableId,
    String? tableName,
    TablePurpose? tablePurpose,
    String? customerId,
    String? customerName,
    String? customerPhoneNumber,
    DateTime? startTime,
    DateTime? endTime,
    double? hourlyRate,
    double? totalAmount,
    PaymentMode? paymentMode,
    SessionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? creditsUsed,
    double? creditsEarned,
    Map<String, dynamic>? discountsApplied,
    double? totalCafeAmount,
    double? totalMerchandiseAmount,
    double? totalBillAmount,
    bool? chargeMinimumOneHour,
    int? minimumBillableMinutes,
    List<String>? cafeOrderIds,
    List<String>? merchandiseOrderIds,
    bool? hasUnbilledOrders,
    List<String>? playerIds,
    List<String>? playerNames,
    String? startedById,
    String? startedByName,
    String? completedById,
    String? completedByName,
    String? startedByRole,
    String? completedByRole,
    bool? isPTL,
    int? playerCount,
    int? loserPlayerIndex,
    bool? isPaused,
    DateTime? pausedAt,
    int? totalPausedSeconds,
    int? breaksTaken,
    bool? isOnBreak,
    DateTime? breakStartedAt,
    bool? isRefunded,
    double? refundAmount,
    DateTime? refundedAt,
    String? refundedById,
    String? refundedByName,
    String? refundedByRole,
    double? creditsRefunded,
    Map<String, dynamic>? data,
    double? tableChargesAtCheckout,
    double? grossAmount,
    List<Map<String, dynamic>>? activityLog,
  }) {
    return TableSession(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      tablePurpose: tablePurpose ?? this.tablePurpose,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhoneNumber: customerPhoneNumber ?? this.customerPhoneNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      creditsUsed: creditsUsed ?? this.creditsUsed,
      creditsEarned: creditsEarned ?? this.creditsEarned,
      discountsApplied: discountsApplied ?? this.discountsApplied,
      totalCafeAmount: totalCafeAmount ?? this.totalCafeAmount,
      totalMerchandiseAmount:
          totalMerchandiseAmount ?? this.totalMerchandiseAmount,
      totalBillAmount: totalBillAmount ?? this.totalBillAmount,
      chargeMinimumOneHour: chargeMinimumOneHour ?? this.chargeMinimumOneHour,
      minimumBillableMinutes:
          minimumBillableMinutes ?? this.minimumBillableMinutes,
      cafeOrderIds: cafeOrderIds ?? this.cafeOrderIds,
      merchandiseOrderIds: merchandiseOrderIds ?? this.merchandiseOrderIds,
      hasUnbilledOrders: hasUnbilledOrders ?? this.hasUnbilledOrders,
      playerIds: playerIds ?? this.playerIds,
      playerNames: playerNames ?? this.playerNames,
      startedById: startedById ?? this.startedById,
      startedByName: startedByName ?? this.startedByName,
      completedById: completedById ?? this.completedById,
      completedByName: completedByName ?? this.completedByName,
      startedByRole: startedByRole ?? this.startedByRole,
      completedByRole: completedByRole ?? this.completedByRole,
      isPTL: isPTL ?? this.isPTL,
      playerCount: playerCount ?? this.playerCount,
      loserPlayerIndex: loserPlayerIndex ?? this.loserPlayerIndex,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: pausedAt ?? this.pausedAt,
      totalPausedSeconds: totalPausedSeconds ?? this.totalPausedSeconds,
      breaksTaken: breaksTaken ?? this.breaksTaken,
      isOnBreak: isOnBreak ?? this.isOnBreak,
      breakStartedAt: breakStartedAt ?? this.breakStartedAt,
      isRefunded: isRefunded ?? this.isRefunded,
      refundAmount: refundAmount ?? this.refundAmount,
      refundedAt: refundedAt ?? this.refundedAt,
      refundedById: refundedById ?? this.refundedById,
      refundedByName: refundedByName ?? this.refundedByName,
      refundedByRole: refundedByRole ?? this.refundedByRole,
      creditsRefunded: creditsRefunded ?? this.creditsRefunded,
      data: data ?? this.data,
      tableChargesAtCheckout:
          tableChargesAtCheckout ?? this.tableChargesAtCheckout,
      grossAmount: grossAmount ?? this.grossAmount,
      activityLog: activityLog ?? this.activityLog,
    );
  }

  /// Returns the actual billable duration, accounting for paused time.
  ///
  /// If session is currently paused, duration stops at [pausedAt].
  /// Total paused time is subtracted from the raw duration.
  Duration get duration {
    final DateTime effectiveEndTime;

    if (endTime != null) {
      // Session is completed - use stored end time
      effectiveEndTime = endTime!;
    } else if (isPaused && pausedAt != null) {
      // Session is paused - use pause time as effective end
      effectiveEndTime = pausedAt!;
    } else {
      // Session is active and running
      effectiveEndTime = DateTime.now();
    }

    final rawDuration = effectiveEndTime.difference(startTime);
    final pausedDuration = Duration(seconds: totalPausedSeconds);

    // Subtract paused time from raw duration
    final actualDuration = rawDuration - pausedDuration;

    // Ensure duration is never negative
    return actualDuration.isNegative ? Duration.zero : actualDuration;
  }

  /// Whether a 5-minute break is available (every 30 min of active play).
  bool get isBreakAvailable {
    if (status != SessionStatus.active) return false;
    if (isOnBreak || isPaused) return false;
    final playMinutes = duration.inMinutes;
    final nextBreakAt = (breaksTaken + 1) * 30;
    return playMinutes >= nextBreakAt;
  }

  /// Seconds remaining in the current break. Returns 0 if not on break.
  int get breakRemainingSeconds {
    if (!isOnBreak || breakStartedAt == null) return 0;
    const breakDuration = Duration(minutes: 5);
    final elapsed = DateTime.now().difference(breakStartedAt!);
    final remaining = breakDuration - elapsed;
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  /// Whether the current break has expired and should be auto-resumed.
  bool get isBreakExpired {
    if (!isOnBreak || breakStartedAt == null) return false;
    return DateTime.now().difference(breakStartedAt!).inMinutes >= 5;
  }

  /// Returns the raw elapsed time since session started (ignoring pauses).
  /// Useful for displaying total wall-clock time.
  Duration get rawDuration {
    if (endTime == null) {
      return DateTime.now().difference(startTime);
    }
    return endTime!.difference(startTime);
  }

  bool get isGaming => tablePurpose == TablePurpose.gaming;
  bool get isDining => tablePurpose == TablePurpose.dining;

  /// Computes table charges using configurable minimum billable minutes.
  double get tableCharges {
    if (tablePurpose == TablePurpose.dining) return 0;
    double hours = duration.inMinutes / 60.0;
    final int minMinutes = (minimumBillableMinutes ?? 0);
    if (minMinutes > 0) {
      final double minHours = minMinutes / 60.0;
      if (hours < minHours) hours = minHours;
    }
    return hours * hourlyRate;
  }

  /// Computed minimum booking charge for this session's table pricing,
  /// based on [minimumBillableMinutes] and [hourlyRate]. Null when not configured.
  double? get minimumBookingCharge {
    final int minutes = minimumBillableMinutes ?? 0;
    if (minutes <= 0) return null;
    return (minutes / 60.0) * hourlyRate;
  }

  double calculateCreditsEarned(double creditRate) {
    if (status != SessionStatus.completed) return 0;
    final baseAmountForEarning =
        totalAmount ?? (duration.inMinutes / 60.0 * hourlyRate);
    return ((baseAmountForEarning * (creditRate / 100)) * 100).round() / 100;
  }

  bool get isRunningOvertime {
    if (status != SessionStatus.active) return false;
    final hours = duration.inMinutes / 60.0;
    return hours > 3; // Consider sessions over 3 hours as overtime
  }

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  String get formattedStartTime {
    return DateFormat('dd MMM, hh:mm a').format(startTime);
  }

  String get formattedEndTime {
    if (endTime == null) return 'Active';
    return DateFormat('dd MMM, hh:mm a').format(endTime!);
  }

  double get combinedOrderAmount {
    return (totalCafeAmount ?? 0.0) + (totalMerchandiseAmount ?? 0.0);
  }

  /// Cafe activity for UI/badges: linked doc ids and/or denormalized total.
  bool get hasCafeBillActivity =>
      cafeOrderIds.isNotEmpty || (totalCafeAmount ?? 0) > 0;

  /// Merchandise activity for UI/badges.
  bool get hasMerchandiseBillActivity =>
      merchandiseOrderIds.isNotEmpty || (totalMerchandiseAmount ?? 0) > 0;

  /// Count from session doc id arrays (can undercount if arrays were not maintained).
  int get linkedOrderDocumentCount =>
      cafeOrderIds.length + merchandiseOrderIds.length;

  /// Table + cafe + merch using stored fields; falls back if totals were cleared incorrectly.
  double get effectiveBillSubtotal {
    final table = tableChargesAtCheckout ?? tableCharges;
    final sum =
        table + (totalCafeAmount ?? 0.0) + (totalMerchandiseAmount ?? 0.0);
    if (sum > 0) return sum;
    final g = grossAmount;
    if (g != null && g > 0) return g;
    return calculateTotalBillAmount();
  }

  /// Shown on receipts/history when [totalBillAmount] is null or incorrectly 0.
  double get effectiveDisplayTotalBillAmount {
    final stored = totalBillAmount;
    if (stored != null && stored > 0) return stored;
    final g = grossAmount;
    if (g != null && g > 0) return g;
    return effectiveBillSubtotal;
  }

  /// Payable total for analytics and dashboard; matches [SalesDataService] sessions branch (`totalBill`).
  double get sessionPayableTotalForAnalytics {
    double g = grossAmount ?? 0.0;
    if (g <= 0) {
      final computed = calculateTotalBillAmount();
      if (computed > 0) g = computed;
    }
    return totalBillAmount ??
        (g != 0.0 ? g : ((totalAmount ?? 0.0) + tableCharges));
  }

  /// Cash-equivalent cap for validating session refund amounts after checkout.
  /// Full-credit sessions may return 0 here while credits are still refunded separately.
  double get effectiveSessionRefundCap {
    final tb = totalBillAmount;
    if (tb != null && tb > 0) return tb;
    final g = grossAmount;
    if (g != null && g > 0) return g;
    final sub = effectiveBillSubtotal;
    return sub > 0 ? sub : 0.0;
  }

  double calculateTotalBillAmount() {
    return tableCharges +
        (totalCafeAmount ?? 0.0) +
        (totalMerchandiseAmount ?? 0.0);
  }

  double calculateFinalAmount() {
    double bill = calculateTotalBillAmount();
    if (discountsApplied != null) {
      final membershipDiscount = parseFirestoreDouble(
        discountsApplied!['membershipDiscountPercentage'],
        fallback: 0,
      );
      final specialDiscount = parseFirestoreDouble(
        discountsApplied!['specialDiscountPercentage'],
        fallback: 0,
      );
      final totalDiscountPercentage = membershipDiscount + specialDiscount;
      if (totalDiscountPercentage > 0) {
        bill -= bill * (totalDiscountPercentage / 100);
      }
    }
    bill -= creditsUsed ?? 0;
    return bill < 0 ? 0 : bill;
  }

  /// Creates an activity log entry for session history tracking.
  static Map<String, dynamic> createActivityLogEntry({
    required String type,
    required DateTime timestamp,
    required String description,
    String? orderId,
    String? performedById,
    String? performedByName,
    String? performedByRole,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'description': description,
      'orderId': ?orderId,
      'performedById': ?performedById,
      'performedByName': ?performedByName,
      'performedByRole': ?performedByRole,
      'metadata': ?metadata,
    };
  }
}
