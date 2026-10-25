import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../firestore/tenant_firestore.dart';
import '../models/floor_booking_request.dart';
import '../models/table.dart';
import '../models/table_venue_defaults.dart';
import '../models/session.dart';
import '../services/floor_booking_service.dart';
import '../services/table_service.dart';
import '../utils/app_logger.dart';
import 'company_module_provider.dart';
import 'tenant_provider.dart';

/// Sessions already scheduled for deferred cleanup. Prevents duplicate
/// cleanup attempts across multiple `combineLatest2` firings.
final _pendingCleanupIds = <String>{};

/// Performs a **safe** deferred cleanup of an orphaned session.
///
/// 1. Waits 5 seconds so both Firestore listeners can settle.
/// 2. Does a fresh read of both the session and its table document.
/// 3. Only cancels the session if ALL of:
///    - Session still has `status == active`
///    - Table's `currentSessionId` does NOT match the session ID
///    - Session's `billingInProgress` is not `true`
void _scheduleDeferredOrphanCleanup(
  TenantRef tenant,
  String sessionId,
  String tableId,
) {
  if (_pendingCleanupIds.contains(sessionId)) return; // already scheduled
  _pendingCleanupIds.add(sessionId);

  Future<void>.delayed(const Duration(seconds: 5), () async {
    try {
      // Fresh reads — NOT from any cached snapshot
      final sessionDoc = await tenant.sessions().doc(sessionId).get();
      final tableDoc = await tenant.tables().doc(tableId).get();

      if (!sessionDoc.exists) {
        AppLogger.info(
          'Deferred cleanup: session $sessionId no longer exists, skipping.',
          tag: 'OrphanCleanup',
        );
        return;
      }

      final sessionData = sessionDoc.data()!;
      final sessionStatus = sessionData['status'] as String?;
      final billingInProgress =
          sessionData['billingInProgress'] as bool? ?? false;

      // Safety check 1: session must still be active
      if (sessionStatus != 'active') {
        AppLogger.info(
          'Deferred cleanup: session $sessionId is now "$sessionStatus", '
          'no cleanup needed.',
          tag: 'OrphanCleanup',
        );
        return;
      }

      // Safety check 2: billing must not be in progress
      if (billingInProgress) {
        AppLogger.info(
          'Deferred cleanup: session $sessionId has billingInProgress=true, '
          'skipping to avoid interrupting checkout.',
          tag: 'OrphanCleanup',
        );
        // Remove from pending so it can be re-evaluated next time
        _pendingCleanupIds.remove(sessionId);
        return;
      }

      // Safety check 3: table must still NOT reference this session
      final tableCurrentSessionId = tableDoc.exists
          ? (tableDoc.data()?['currentSessionId'] as String?)
          : null;

      if (tableCurrentSessionId == sessionId) {
        AppLogger.info(
          'Deferred cleanup: table $tableId now references session $sessionId, '
          'session is legitimate.',
          tag: 'OrphanCleanup',
        );
        _pendingCleanupIds.remove(sessionId);
        return;
      }

      // All checks passed — this is genuinely orphaned. Cancel it.
      final now = DateTime.now();
      await tenant.sessions().doc(sessionId).update({
        'status': SessionStatus.cancelled.name,
        'endTime': Timestamp.fromDate(now),
        'totalAmount': 0,
        'cancelledReason': 'auto_cleanup_orphaned_session_v2',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final tableName = sessionData['tableName'] as String? ?? tableId;
      AppLogger.warning(
        'Deferred cleanup: cancelled orphaned session $sessionId on table '
        '$tableName (tableId: $tableId). '
        'Table currentSessionId=$tableCurrentSessionId.',
        tag: 'OrphanCleanup',
      );
    } catch (e) {
      AppLogger.error(
        'Deferred cleanup failed for session $sessionId: $e',
        tag: 'OrphanCleanup',
      );
      // Remove so it can be retried on next stream emission
      _pendingCleanupIds.remove(sessionId);
    }
  });
}

final tableListProvider = StreamProvider<List<SnookerTable>>((ref) {
  ref.keepAlive();
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value([]);
  final venueKind = ref.watch(venueKindProvider);

  return tenant
      .tables()
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => SnookerTable.fromJson(
                {...doc.data(), 'id': doc.id},
                venueKind: venueKind,
              ),
            )
            .toList(),
      );
});

final tableProvider = StreamProvider.family<SnookerTable?, String>((
  ref,
  tableId,
) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(null);
  final venueKind = ref.watch(venueKindProvider);
  return tenant
      .tables()
      .doc(tableId)
      .snapshots()
      .map(
        (doc) => doc.exists
            ? SnookerTable.fromJson(
                {...doc.data()!, 'id': doc.id},
                venueKind: venueKind,
              )
            : null,
      );
});

final activeSessionsProvider = StreamProvider<List<TableSession>>((ref) {
  ref.keepAlive();
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value([]);

  final profileAsync = ref.watch(companyProfileProvider);
  if (!profileAsync.hasValue) {
    return Stream.value([]);
  }
  final diningOnly =
      profileAsync.requireValue.venueKind.restrictsTablePurposesToDining;

  final sessionsStream = tenant
      .sessions()
      .where('status', isEqualTo: 'active')
      .snapshots();

  final tablesStream = tenant.tables().snapshots();

  return Rx.combineLatest2(sessionsStream, tablesStream, (
    QuerySnapshot sessionsSnapshot,
    QuerySnapshot tablesSnapshot,
  ) {
    // Phase 1: Build a lookup of tableId -> currentSessionId
    final tableCurrentSession = <String, String?>{};
    final tablePurposeById = <String, TablePurpose>{};
    for (final doc in tablesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      tableCurrentSession[doc.id] = data['currentSessionId'] as String?;
      tablePurposeById[doc.id] = parseTablePurpose(data['tablePurpose']);
    }

    final now = DateTime.now();
    const gracePeriod = Duration(minutes: 10);

    final validSessions = <TableSession>[];

    for (final doc in sessionsSnapshot.docs) {
      final session = TableSession.fromFirestore(doc);
      final tableRefSessionId = tableCurrentSession[session.tableId];

      // Session is legitimate if the table's currentSessionId matches
      if (tableRefSessionId == session.id) {
        validSessions.add(session);
        continue;
      }

      // Grace period: if the session started less than 10 minutes ago,
      // keep it visible (could be brief out-of-sync during batch writes).
      if (now.difference(session.startTime) < gracePeriod) {
        validSessions.add(session);
        continue;
      }

      // Phase 1: Filter out — do NOT show this session on the dashboard.
      // Phase 2: Schedule a safe deferred cleanup that will re-read
      // from Firestore before making any destructive writes.
      _scheduleDeferredOrphanCleanup(tenant, session.id, session.tableId);

      // Don't include it in the returned list
    }

    if (diningOnly) {
      validSessions.removeWhere((s) {
        final tp = tablePurposeById[s.tableId];
        if (tp != null) return tp != TablePurpose.dining;
        return s.tablePurpose != TablePurpose.dining;
      });
    }

    validSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return validSessions;
  });
});

/// Provider to fetch sessions that were incorrectly cancelled by the orphan cleanup.
/// These sessions have cancelledReason = 'auto_cleanup_orphaned_session'
final orphanCancelledSessionsProvider = StreamProvider<List<TableSession>>((
  ref,
) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value([]);
  return tenant
      .sessions()
      .where('cancelledReason', isEqualTo: 'auto_cleanup_orphaned_session')
      .orderBy('endTime', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => TableSession.fromFirestore(doc))
            .toList(),
      );
});

/// Sessions with checkout `billingInProgress` stuck true (failed clear / crash).
/// Sorted client-side; query avoids composite index on `startTime`.
final billingLockedSessionsProvider = StreamProvider<List<TableSession>>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value([]);
  return tenant
      .sessions()
      .where('billingInProgress', isEqualTo: true)
      .limit(50)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => TableSession.fromFirestore(doc))
            .toList();
        list.sort((a, b) => b.startTime.compareTo(a.startTime));
        return list;
      });
});

final tableSessionsProvider = StreamProvider.family<List<TableSession>, String>(
  (ref, tableId) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return Stream.value([]);
    return tenant
        .sessions()
        .where('tableId', isEqualTo: tableId)
        .orderBy('startTime', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TableSession.fromFirestore(doc))
              .toList(),
        );
  },
);

final customerSessionsProvider =
    StreamProvider.family<List<TableSession>, String>((ref, customerId) {
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value([]);
      return tenant
          .sessions()
          .where('customerId', isEqualTo: customerId)
          .orderBy('startTime', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => TableSession.fromFirestore(doc))
                .toList(),
          );
    });

final activeSessionDetailsProvider = StreamProvider.autoDispose
    .family<TableSession?, String>((ref, sessionId) {
      if (sessionId.isEmpty) return Stream.value(null);
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) return Stream.value(null);
      return tenant
          .sessions()
          .doc(sessionId)
          .snapshots()
          .map((doc) => doc.exists ? TableSession.fromFirestore(doc) : null);
    });

const int _sessionHistoryLimit = 200;

final allSessionsProvider = StreamProvider<List<TableSession>>((ref) {
  ref.keepAlive();
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value([]);

  return tenant
      .sessions()
      .orderBy('startTime', descending: true)
      .limit(_sessionHistoryLimit)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => TableSession.fromFirestore(doc))
            .toList(),
      );
});

/// Non-null only after [tenantRefProvider] is set (see [_PostAuthShell] in main.dart).
final tableServiceProvider = Provider<TableService>((ref) {
  final tenant = ref.watch(tenantRefProvider)!;
  return TableService(tenant);
});

final floorBookingServiceProvider = Provider<FloorBookingService>((ref) {
  final tenant = ref.watch(tenantRefProvider)!;
  return FloorBookingService(tenant);
});

final pendingFloorBookingRequestsProvider =
    StreamProvider<List<FloorBookingRequest>>((ref) {
  return ref.watch(floorBookingServiceProvider).pendingRequestsStream();
});
