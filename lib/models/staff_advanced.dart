import 'package:cloud_firestore/cloud_firestore.dart';

class StaffPerformanceKPI {
  final String staffUid;
  final String staffName;
  final int sessionsHandled;
  final int ordersProcessed;
  final double revenueGenerated;
  final double avgRating;
  final String period;

  const StaffPerformanceKPI({
    required this.staffUid,
    required this.staffName,
    this.sessionsHandled = 0,
    this.ordersProcessed = 0,
    this.revenueGenerated = 0,
    this.avgRating = 0,
    required this.period,
  });
}

class CommissionRecord {
  final String id;
  final String staffUid;
  final String staffName;
  final double saleAmount;
  final double commissionRate;
  final double commissionAmount;
  final DateTime date;

  const CommissionRecord({
    required this.id,
    required this.staffUid,
    required this.staffName,
    required this.saleAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.date,
  });

  factory CommissionRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CommissionRecord(
      id: doc.id,
      staffUid: d['staffUid'] as String? ?? '',
      staffName: d['staffName'] as String? ?? '',
      saleAmount: (d['saleAmount'] as num?)?.toDouble() ?? 0,
      commissionRate: (d['commissionRate'] as num?)?.toDouble() ?? 0,
      commissionAmount: (d['commissionAmount'] as num?)?.toDouble() ?? 0,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'staffUid': staffUid,
        'staffName': staffName,
        'saleAmount': saleAmount,
        'commissionRate': commissionRate,
        'commissionAmount': commissionAmount,
        'date': Timestamp.fromDate(date),
      };
}

class TrainingModule {
  final String id;
  final String title;
  final String description;
  final int totalSteps;
  final DateTime createdAt;

  const TrainingModule({
    required this.id,
    required this.title,
    required this.description,
    required this.totalSteps,
    required this.createdAt,
  });

  factory TrainingModule.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return TrainingModule(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      totalSteps: (d['totalSteps'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'totalSteps': totalSteps,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class LeaveRequest {
  final String id;
  final String staffUid;
  final String staffName;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final DateTime createdAt;

  const LeaveRequest({
    required this.id,
    required this.staffUid,
    required this.staffName,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = 'pending',
    required this.createdAt,
  });

  factory LeaveRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return LeaveRequest(
      id: doc.id,
      staffUid: d['staffUid'] as String? ?? '',
      staffName: d['staffName'] as String? ?? '',
      type: d['type'] as String? ?? 'casual',
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: d['reason'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'staffUid': staffUid,
        'staffName': staffName,
        'type': type,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'reason': reason,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class StaffGoal {
  final String id;
  final String staffUid;
  final String staffName;
  final String title;
  final String metric;
  final double target;
  final double current;
  final DateTime deadline;

  const StaffGoal({
    required this.id,
    required this.staffUid,
    required this.staffName,
    required this.title,
    required this.metric,
    required this.target,
    this.current = 0,
    required this.deadline,
  });

  double get progressPercent =>
      target > 0 ? (current / target * 100).clamp(0, 100) : 0;

  factory StaffGoal.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return StaffGoal(
      id: doc.id,
      staffUid: d['staffUid'] as String? ?? '',
      staffName: d['staffName'] as String? ?? '',
      title: d['title'] as String? ?? '',
      metric: d['metric'] as String? ?? '',
      target: (d['target'] as num?)?.toDouble() ?? 0,
      current: (d['current'] as num?)?.toDouble() ?? 0,
      deadline: (d['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'staffUid': staffUid,
        'staffName': staffName,
        'title': title,
        'metric': metric,
        'target': target,
        'current': current,
        'deadline': Timestamp.fromDate(deadline),
      };
}
