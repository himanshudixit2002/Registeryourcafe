import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';
import 'venue_kind.dart';

/// Legacy default `type` when [parseTableTypeId] has no [VenueKind] (e.g. pre-auth).
/// For tenant data prefer [VenueKind.defaultTableTypeId].
const String kDefaultTableTypeId = 'snooker';

enum TableStatus { available, occupied, maintenance }

/// Whether a table is used for timed gaming billing or restaurant-style seating.
enum TablePurpose { gaming, dining }

TablePurpose parseTablePurpose(Object? raw) {
  if (raw == null) return TablePurpose.gaming;
  final s = raw.toString().toLowerCase();
  final short = s.contains('.') ? s.split('.').last : s;
  return short == 'dining' ? TablePurpose.dining : TablePurpose.gaming;
}

String parseTableTypeId(
  Map<String, dynamic> json, {
  VenueKind? venueKind,
}) {
  final raw = json['type'] ?? json['typeId'];
  if (raw == null) {
    return venueKind?.defaultTableTypeId ?? kDefaultTableTypeId;
  }
  var s = raw.toString().trim();
  if (s.isEmpty) {
    return venueKind?.defaultTableTypeId ?? kDefaultTableTypeId;
  }
  if (s.contains('.')) {
    s = s.split('.').last;
  }
  return s.toLowerCase();
}

class SnookerTable {
  final String id;
  final String name;
  final String? description;
  final double hourlyRate;
  final int capacity;

  /// Document id in `table_type_definitions` (stored as field `type` in Firestore).
  final String typeId;
  final TableStatus status;
  final TablePurpose tablePurpose;

  /// If true, at least one full hour is charged when a session starts,
  /// even if the customer plays for less than an hour.
  final bool chargeMinimumOneHour;

  /// Minimum billable minutes for a session on this table. When set (>0),
  /// this overrides [chargeMinimumOneHour] behavior and charges at least
  /// this many minutes.
  final int? minimumBillableMinutes;
  final String? currentSessionId;
  final DateTime? sessionStartTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SnookerTable({
    required this.id,
    required this.name,
    this.description,
    required this.hourlyRate,
    this.capacity = 2,
    required this.typeId,
    required this.status,
    this.tablePurpose = TablePurpose.gaming,
    this.currentSessionId,
    this.sessionStartTime,
    this.createdAt,
    this.updatedAt,
    this.chargeMinimumOneHour = false,
    this.minimumBillableMinutes,
  });

  /// Computed minimum booking charge in currency, based on [minimumBillableMinutes]
  /// and [hourlyRate]. Returns null if no minimum is configured.
  double? get minimumBookingCharge {
    final int minutes = minimumBillableMinutes ?? 0;
    if (minutes <= 0) return null;
    final double hours = minutes / 60.0;
    return hours * hourlyRate;
  }

  factory SnookerTable.fromJson(
    Map<String, dynamic> json, {
    VenueKind? venueKind,
  }) {
    return SnookerTable(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      hourlyRate: parseFirestoreDouble(json['hourlyRate']),
      capacity: parseFirestoreInt(json['capacity'], fallback: 2),
      typeId: parseTableTypeId(json, venueKind: venueKind),
      status: TableStatus.values.firstWhere(
        (e) =>
            e.toString() == json['status'] ||
            e.toString().split('.').last == json['status'],
        orElse: () => TableStatus.maintenance,
      ),
      tablePurpose: parseTablePurpose(json['tablePurpose']),
      chargeMinimumOneHour: json['chargeMinimumOneHour'] as bool? ?? false,
      minimumBillableMinutes: parseFirestoreIntOrNull(
        json['minimumBillableMinutes'],
      ),
      currentSessionId: json['currentSessionId'] as String?,
      sessionStartTime: json['sessionStartTime'] != null
          ? (json['sessionStartTime'] as Timestamp).toDate()
          : null,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'hourlyRate': hourlyRate,
      'capacity': capacity,
      'type': typeId,
      'status': status.toString().split('.').last,
      'tablePurpose': tablePurpose.name,
      'currentSessionId': currentSessionId,
      'sessionStartTime': sessionStartTime != null
          ? Timestamp.fromDate(sessionStartTime!)
          : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'chargeMinimumOneHour': chargeMinimumOneHour,
      if (minimumBillableMinutes != null)
        'minimumBillableMinutes': minimumBillableMinutes,
    };
  }

  SnookerTable copyWith({
    String? id,
    String? name,
    String? description,
    double? hourlyRate,
    int? capacity,
    String? typeId,
    TableStatus? status,
    TablePurpose? tablePurpose,
    String? currentSessionId,
    DateTime? sessionStartTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? chargeMinimumOneHour,
    int? minimumBillableMinutes,
    bool clearCurrentSessionId = false,
    bool clearSessionStartTime = false,
  }) {
    return SnookerTable(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      capacity: capacity ?? this.capacity,
      typeId: typeId ?? this.typeId,
      status: status ?? this.status,
      tablePurpose: tablePurpose ?? this.tablePurpose,
      currentSessionId: clearCurrentSessionId
          ? null
          : currentSessionId ?? this.currentSessionId,
      sessionStartTime: clearSessionStartTime
          ? null
          : sessionStartTime ?? this.sessionStartTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      chargeMinimumOneHour: chargeMinimumOneHour ?? this.chargeMinimumOneHour,
      minimumBillableMinutes:
          minimumBillableMinutes ?? this.minimumBillableMinutes,
    );
  }
}
