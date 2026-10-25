import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';

class AnalyticsDataService {
  final TenantRef _tenant;

  AnalyticsDataService(this._tenant);

  Future<Map<String, double>> getRevenueByDay({
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _tenant
        .salesTransactions()
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    final map = <String, double>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = (data['createdAt'] as Timestamp?)?.toDate();
      if (ts == null) continue;
      final key =
          '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
      final amount = (data['total'] as num?)?.toDouble() ?? 0;
      map[key] = (map[key] ?? 0) + amount;
    }
    return map;
  }

  Future<Map<String, int>> getTableUtilization({
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _tenant
        .sessions()
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    final map = <String, int>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final tableName = data['tableName'] as String? ?? 'Unknown';
      map[tableName] = (map[tableName] ?? 0) + 1;
    }
    return map;
  }

  Future<Map<String, int>> getCustomerVisitFrequency({
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _tenant
        .sessions()
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    final map = <String, int>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = data['customerName'] as String?;
      if (name == null || name.isEmpty) continue;
      map[name] = (map[name] ?? 0) + 1;
    }
    return map;
  }

  Future<Map<int, double>> getRevenueByHour({
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _tenant
        .salesTransactions()
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    final map = <int, double>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = (data['createdAt'] as Timestamp?)?.toDate();
      if (ts == null) continue;
      final hour = ts.hour;
      final amount = (data['total'] as num?)?.toDouble() ?? 0;
      map[hour] = (map[hour] ?? 0) + amount;
    }
    return map;
  }
}
