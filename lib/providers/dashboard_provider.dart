import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:registeryourcafe/models/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../models/cafe_order.dart';
import '../models/stock_item.dart';
import '../models/merchandise_order.dart';
import '../utils/app_logger.dart';
import '../utils/firestore_utils.dart';
import 'tenant_provider.dart';

/// On Firestore snapshot errors (e.g. permission-denied on one collection), emits
/// [fallback] so the dashboard still loads instead of hanging on [Rx.combineLatest6].
Stream<T> _recoverDashboardStream<T>(Stream<T> source, T fallback, String tag) {
  return source.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleData: (data, sink) => sink.add(data),
      handleError: (error, stackTrace, sink) {
        AppLogger.error(
          'Dashboard stream failed: $tag',
          error: error,
          stackTrace: stackTrace,
          tag: 'Dashboard',
        );
        sink.add(fallback);
      },
    ),
  );
}

class DashboardData {
  final double totalSales;
  final int ordersToday;
  final int sessionsToday;
  final int activeTables;
  final int totalCustomers;
  final int totalTables;
  final List<MapEntry<String, int>> popularItems;
  final List<Map<String, dynamic>> recentOrders;
  final List<double> revenueData;
  final String mostActiveTable;
  final String peakHours;
  final Map<String, double> salesByCategory;
  final double averageSessionDuration;

  DashboardData({
    required this.totalSales,
    required this.ordersToday,
    required this.sessionsToday,
    required this.activeTables,
    required this.totalCustomers,
    required this.totalTables,
    required this.popularItems,
    required this.recentOrders,
    required this.revenueData,
    required this.mostActiveTable,
    required this.peakHours,
    required this.salesByCategory,
    required this.averageSessionDuration,
  });
}

final dashboardProvider = StreamProvider.autoDispose<DashboardData>((ref) {
  ref.keepAlive();

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(
      DashboardData(
        totalSales: 0,
        ordersToday: 0,
        sessionsToday: 0,
        activeTables: 0,
        totalCustomers: 0,
        totalTables: 0,
        popularItems: const [],
        recentOrders: const [],
        revenueData: const [],
        mostActiveTable: 'N/A',
        peakHours: 'N/A',
        salesByCategory: const {},
        averageSessionDuration: 0,
      ),
    );
  }

  final now = DateTime.now();
  final sevenDaysAgo = now.subtract(const Duration(days: 7));

  const queryLimit = 200;

  final cafeOrdersStream = tenant
      .cafeOrders()
      .where('status', isEqualTo: 'delivered')
      .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
      .orderBy('createdAt', descending: true)
      .limit(queryLimit)
      .withConverter<CafeOrder>(
        fromFirestore: (snapshot, _) => CafeOrder.fromFirestore(snapshot),
        toFirestore: (order, _) => order.toFirestore(),
      )
      .snapshots();

  final merchandiseOrdersStream = tenant
      .merchandiseOrders()
      .where('status', whereIn: ['delivered', 'completed'])
      .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
      .orderBy('createdAt', descending: true)
      .limit(queryLimit)
      .withConverter<MerchandiseOrder>(
        fromFirestore: (snapshot, _) =>
            MerchandiseOrder.fromFirestore(snapshot),
        toFirestore: (order, _) => order.toFirestore(),
      )
      .snapshots();

  // Include both completed and refunded sessions so that revenue reflects refunds correctly.
  final sessionsStream = tenant
      .sessions()
      .where('status', whereIn: ['completed', 'refunded'])
      .where('endTime', isGreaterThanOrEqualTo: sevenDaysAgo)
      .orderBy('endTime', descending: true)
      .limit(queryLimit)
      .withConverter<TableSession>(
        fromFirestore: (snapshot, _) => TableSession.fromFirestore(snapshot),
        toFirestore: (session, _) => session.toFirestore(),
      )
      .snapshots();

  final membershipPaymentsStream = tenant
      .membershipPayments()
      .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
      .orderBy('createdAt', descending: true)
      .limit(queryLimit)
      .snapshots();

  final tablesStream = tenant.tables().snapshots();
  final customersStream = tenant.customers().snapshots();

  final cafeOrdersListStream = _recoverDashboardStream(
    cafeOrdersStream.map((s) => s.docs.map((d) => d.data()).toList()),
    const <CafeOrder>[],
    'cafeOrders',
  );
  final sessionsListStream = _recoverDashboardStream(
    sessionsStream.map((s) => s.docs.map((d) => d.data()).toList()),
    const <TableSession>[],
    'sessions',
  );
  final merchandiseListStream = _recoverDashboardStream(
    merchandiseOrdersStream.map((s) => s.docs.map((d) => d.data()).toList()),
    const <MerchandiseOrder>[],
    'merchandiseOrders',
  );
  final membershipDocsStream = _recoverDashboardStream(
    membershipPaymentsStream.map((s) => s.docs),
    <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    'membershipPayments',
  );
  final tablesDashStream = _recoverDashboardStream(
    tablesStream.map((s) => (size: s.size, docs: s.docs)),
    (size: 0, docs: <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
    'tables',
  );
  final customerCountStream = _recoverDashboardStream(
    customersStream.map((s) => s.size),
    0,
    'customers',
  );

  return Rx.combineLatest6(
    cafeOrdersListStream,
    sessionsListStream,
    merchandiseListStream,
    membershipDocsStream,
    tablesDashStream,
    customerCountStream,
    (
      List<CafeOrder> cafeOrders,
      List<TableSession> sessions,
      List<MerchandiseOrder> merchandiseOrders,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> creditTopUps,
      ({int size, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs})
      tablesData,
      int totalCustomers,
    ) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sevenDaysAgo = today.subtract(const Duration(days: 7));

      // --- Combine Data ---
      // Match SalesDataService `totalBill` for every session line and refund denominator.
      double sessionBillBase(TableSession s) =>
          s.sessionPayableTotalForAnalytics;

      double sessionRevenue(TableSession s) {
        if (s.isRefunded) {
          final base = sessionBillBase(s);
          return -(s.refundAmount ?? base);
        }
        return sessionBillBase(s);
      }

      // Filter out cafe & merchandise orders that belong to a session to avoid double-counting.
      final independentCafeOrders = cafeOrders.where(
        (o) => o.sessionId == null || o.sessionId!.isEmpty,
      );
      final independentMerchOrders = merchandiseOrders.where(
        (o) => o.sessionId == null || o.sessionId!.isEmpty,
      );

      double effectiveOrderTotal(
        bool isRefunded,
        double total,
        double? refundAmount,
      ) {
        return isRefunded ? -(refundAmount ?? total) : total;
      }

      final allTransactions = [
        // Cafe orders not tied to a session
        ...independentCafeOrders.map(
          (o) => {
            'createdAt': Timestamp.fromDate(o.createdAt),
            'totalAmount': effectiveOrderTotal(
              o.isRefunded,
              o.total,
              o.refundAmount,
            ),
            'items': o.items
                .map((i) => {'name': i.name, 'quantity': i.quantity})
                .toList(),
            'type': 'Cafe Order',
            'id': o.id,
          },
        ),
        // Include table charges where necessary for accurate revenue figures.
        ...sessions
            .where((s) => s.endTime != null)
            .map(
              (s) => {
                'createdAt': Timestamp.fromDate(s.endTime!),
                'totalAmount': sessionRevenue(s),
                'items': <Map<String, dynamic>>[],
                'type': 'Table Session',
                'tableId': s.tableId,
                'tableName': s.tableName,
                'id': s.id,
              },
            ),
        // Merchandise orders not tied to a session
        ...independentMerchOrders.map(
          (o) => {
            'createdAt': Timestamp.fromDate(o.createdAt),
            'totalAmount': effectiveOrderTotal(
              o.isRefunded,
              o.total,
              o.refundAmount,
            ),
            'items': o.items
                .map((i) => {'name': i.name, 'quantity': i.quantity})
                .toList(),
            'type': 'Merchandise Order',
            'id': o.id,
          },
        ),
        ...creditTopUps.map((c) {
          final m = c.data();
          return {
            'createdAt': m['createdAt'] ?? m['date'] ?? Timestamp.now(),
            'totalAmount': parseFirestoreDouble(m['amount']),
            'items': <Map<String, dynamic>>[],
            'type': 'Credit Top-up',
            'id': c.id,
          };
        }),
      ];

      // Filter transactions from the last 7 days
      final recentTransactions = allTransactions
          .where(
            (t) =>
                t['createdAt'] != null &&
                (t['createdAt'] as Timestamp).toDate().isAfter(sevenDaysAgo),
          )
          .toList();

      // ---------------- TODAY FILTERS -----------------------------
      final todayTransactions = recentTransactions
          .where((t) => (t['createdAt'] as Timestamp).toDate().isAfter(today))
          .toList();

      // Build quick-access collections for today only
      final cafeOrdersToday = independentCafeOrders
          .where((o) => o.createdAt.isAfter(today))
          .toList();
      final sessionsToday = sessions
          .where((s) => s.endTime != null && s.endTime!.isAfter(today))
          .toList();
      final merchandiseOrdersToday = independentMerchOrders
          .where((o) => o.createdAt.isAfter(today))
          .toList();
      final creditTopUpsToday = creditTopUps.where((c) {
        final m = c.data();
        final Timestamp ts =
            (m['createdAt'] ?? m['date'] ?? Timestamp.now()) as Timestamp;
        return ts.toDate().isAfter(today);
      }).toList();
      // Helper to scale component charges for partial refunds so that the
      // proportion between table/cafe/merch amounts is maintained even when a
      // session is partially refunded.
      double multiplierForSession(TableSession s) {
        if (!s.isRefunded) return 1.0;
        final double billTotal = sessionBillBase(s);
        if (billTotal == 0) return 0.0;
        final double refunded = s.refundAmount ?? billTotal;
        return -refunded / billTotal;
      }

      double tableChargesToday = 0.0;
      double cafeChargesFromSessions = 0.0;
      double merchChargesFromSessions = 0.0;
      for (final s in sessionsToday) {
        final mult = multiplierForSession(s);
        tableChargesToday += s.tableCharges * mult;
        cafeChargesFromSessions += (s.totalCafeAmount ?? 0.0) * mult;
        merchChargesFromSessions += (s.totalMerchandiseAmount ?? 0.0) * mult;
      }
      final creditTopUpAmountToday = creditTopUpsToday.fold<double>(
        0.0,
        (acc, c) => acc + parseFirestoreDouble(c.data()['amount']),
      );

      // Signed cafe / merchandise totals from independent orders (exclude session ones)
      final cafeIndependentTodayTotal = cafeOrdersToday.fold<double>(
        0.0,
        (acc, CafeOrder o) =>
            acc + effectiveOrderTotal(o.isRefunded, o.total, o.refundAmount),
      );
      final merchIndependentTodayTotal = merchandiseOrdersToday.fold<double>(
        0.0,
        (acc, MerchandiseOrder o) =>
            acc + effectiveOrderTotal(o.isRefunded, o.total, o.refundAmount),
      );

      // ------------------------------------------------------------

      // 1. Total Sales Today = table + cafe + merch + top-up (each already signed)
      final totalSales =
          tableChargesToday +
          cafeChargesFromSessions +
          cafeIndependentTodayTotal +
          merchChargesFromSessions +
          merchIndependentTodayTotal +
          creditTopUpAmountToday;

      // 2. Orders Today
      final ordersToday = todayTransactions.length;

      // 3. Active Tables
      final activeTables = tablesData.docs.where((doc) {
        final statusStr = ((doc.data())['status'] ?? '')
            .toString()
            .toLowerCase();
        return statusStr.contains('occupied');
      }).length;

      // 4. Total Customers (from resilient count stream)

      // 5. Popular Items (Today)
      final itemCounts = <String, int>{};
      for (final transaction in todayTransactions) {
        final items = (transaction['items'] as List?)
            ?.cast<Map<String, dynamic>>();
        if (items != null) {
          for (final item in items) {
            final name = item['name'] as String?;
            if (name != null) {
              itemCounts[name] =
                  (itemCounts[name] ?? 0) +
                  parseFirestoreInt(item['quantity'], fallback: 1);
            }
          }
        }
      }
      final popularItems = itemCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5PopularItems = popularItems.take(5).toList();

      // 6. Recent Orders (Today)
      final todayAllTransactions = todayTransactions;
      todayAllTransactions.sort((a, b) {
        final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
      // Just use the raw transaction data since we're only passing it to CafeTransaction
      final recentOrdersDocs = todayAllTransactions.take(5).toList();

      // 7. Revenue Data (last 7 days)
      final revenueData = List.generate(7, (index) {
        final date = today.subtract(Duration(days: 6 - index));
        return recentTransactions
            .where((doc) {
              final createdAt = (doc['createdAt'] as Timestamp).toDate();
              return createdAt.year == date.year &&
                  createdAt.month == date.month &&
                  createdAt.day == date.day;
            })
            .fold<double>(
              0.0,
              (acc, doc) => acc + parseFirestoreDouble(doc['totalAmount']),
            );
      });

      // 8. Most Active Table
      final tableOrderCounts = <String, int>{};
      final todaySessions = sessions.where(
        (s) => s.endTime != null && s.endTime!.isAfter(today),
      );

      for (final session in todaySessions) {
        final tableName = session.tableName;
        tableOrderCounts[tableName] = (tableOrderCounts[tableName] ?? 0) + 1;
      }

      final sortedTables = tableOrderCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final mostActiveTable = sortedTables.isNotEmpty
          ? sortedTables.first.key
          : 'N/A';

      // 9. Peak Hours (Today)
      final hourCounts = <int, int>{};
      for (final order in todayTransactions) {
        final hour = (order['createdAt'] as Timestamp).toDate().hour;
        hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      }
      final sortedHours = hourCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final peakHour = sortedHours.isNotEmpty ? sortedHours.first.key : -1;
      final peakHours = peakHour != -1
          ? '$peakHour:00 - ${peakHour + 1}:00'
          : 'N/A';

      // 10. Sales by Category (Today) - separate charges for clarity
      final salesByCategory = <String, double>{
        'Cafe': (cafeIndependentTodayTotal + cafeChargesFromSessions),
        'Table': tableChargesToday,
        'Merchandise': (merchIndependentTodayTotal + merchChargesFromSessions),
        'Credit Top-up': creditTopUpAmountToday,
      };

      // 11. Session Analytics (Today)
      final completedSessionsToday = sessions
          .where((s) => s.endTime != null && s.endTime!.isAfter(today))
          .toList();

      final sessionsTodayCount = completedSessionsToday.length;

      double averageSessionDurationMinutes = 0.0;
      if (sessionsTodayCount > 0) {
        final totalMinutes = completedSessionsToday.fold<int>(
          0,
          (acc, s) => acc + s.duration.inMinutes,
        );
        averageSessionDurationMinutes = totalMinutes / sessionsTodayCount;
      }

      return DashboardData(
        totalSales: totalSales,
        ordersToday: ordersToday,
        sessionsToday: sessionsTodayCount,
        activeTables: activeTables,
        totalCustomers: totalCustomers,
        totalTables: tablesData.size,
        popularItems: top5PopularItems,
        recentOrders: recentOrdersDocs,
        revenueData: revenueData, // removed .reversed to align data with labels
        mostActiveTable: mostActiveTable,
        peakHours: peakHours,
        salesByCategory: salesByCategory,
        averageSessionDuration: averageSessionDurationMinutes,
      );
    },
  ).handleError((Object error, StackTrace stackTrace) {
    AppLogger.error(
      'Error in dashboardProvider stream',
      error: error,
      stackTrace: stackTrace,
      tag: 'Dashboard',
    );
    throw error;
  });
});

final lowStockProvider = StreamProvider.autoDispose<List<StockItem>>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(const []);

  return tenant
      .stockItems()
      .where('quantity', isLessThanOrEqualTo: 20) // Example threshold
      // .where('quantity', isLessThanOrEqualTo: ref.watch(lowStockThresholdProvider)) // For dynamic threshold
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => StockItem.fromFirestore(doc)).toList(),
      );
});
