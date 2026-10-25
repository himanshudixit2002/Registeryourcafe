import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/table.dart';
import '../models/table_type_definition.dart';
import '../models/session.dart';
import '../models/customer.dart';
import '../models/app_user.dart';
import '../firestore/tenant_firestore.dart';
import './credit_service.dart';
import './printer_service.dart';
import './ptl_match_service.dart';
import './order_id_service.dart';
import './floor_booking_service.dart';
import './public_venue_sync_service.dart';
import '../utils/app_logger.dart';
import '../utils/firestore_utils.dart';
import '../utils/session_checkout_discounts.dart';

class TableService {
  final TenantRef _tenant;

  TableService(this._tenant);

  FirebaseFirestore get _db => _tenant.db;

  Future<void> _syncPublicFloorForTable(String tableId) async {
    try {
      await PublicVenueSyncService.syncTableById(_tenant, tableId);
    } catch (e) {
      AppLogger.warning('Public floor sync failed: $e', tag: 'TableService');
    }
  }

  /// Starts a new table session for the given customer.
  ///
  /// Creates a session document and updates the table status to occupied.
  /// Returns the created [TableSession].
  Future<TableSession> startSession({
    required SnookerTable table,
    required Customer customer,
    required PaymentMode paymentMode,
    required AppUser startedBy,
    bool isPTL = false,
    int? playerCount,
    List<Customer>? players,
  }) async {
    final now = DateTime.now();
    final hasPublicHold = await FloorBookingService.tableHasActivePublicSlotAt(
      _tenant,
      table.id,
      now,
    );
    if (hasPublicHold) {
      throw Exception(
        'This table has an approved public booking in this time window. '
        'Wait for the slot to end or ask a manager before starting a session.',
      );
    }

    final batch = _db.batch();
    final String sessionId = await OrderIdService.generate(
      _tenant,
      OrderCategory.session,
    );
    final sessionRef = _tenant.sessions().doc(sessionId);

    final bool isDining = table.tablePurpose == TablePurpose.dining;
    final newSession = TableSession(
      id: sessionRef.id,
      tableId: table.id,
      tableName: table.name,
      tablePurpose: table.tablePurpose,
      customerId: customer.id,
      customerName: customer.name,
      customerPhoneNumber: customer.phoneNumber,
      startTime: now,
      hourlyRate: table.hourlyRate,
      paymentMode: paymentMode,
      status: SessionStatus.active,
      createdAt: now,
      updatedAt: now,
      startedById: startedBy.uid,
      startedByName: startedBy.name,
      startedByRole: startedBy.role.name,
      chargeMinimumOneHour: table.chargeMinimumOneHour,
      minimumBillableMinutes: table.minimumBillableMinutes,
      isPTL: isDining ? false : isPTL,
      playerCount: (isDining || !isPTL) ? null : playerCount,
      playerIds: (!isDining && isPTL && players != null)
          ? players.map((c) => c.id).toList()
          : const [],
      playerNames: (!isDining && isPTL && players != null)
          ? players.map((c) => c.name).toList()
          : const [],
    );
    batch.set(sessionRef, newSession.toFirestore());

    final updatedTable = table.copyWith(
      status: TableStatus.occupied,
      currentSessionId: sessionRef.id,
      sessionStartTime: now,
    );
    final tableRef = _tenant.tables().doc(table.id);
    batch.update(tableRef, updatedTable.toJson());

    await batch.commit();
    await _syncPublicFloorForTable(table.id);
    return newSession;
  }

  /// Calculates the bill details for a session, accounting for paused time.
  Future<Map<String, dynamic>> calculateBillDetails({
    required TableSession session,
    required Customer customer,
    double creditsToAttemptToUse = 0.0,
  }) async {
    if (session.status == SessionStatus.completed &&
        session.totalAmount != null) {
      return {
        'originalAmount': session.totalAmount,
        'creditsApplied': session.creditsUsed ?? 0.0,
        'finalAmount': session.totalAmount! - (session.creditsUsed ?? 0.0),
        'payableAmount': session.totalAmount! - (session.creditsUsed ?? 0.0),
      };
    }

    final now = DateTime.now();

    // Calculate total paused time including current pause if active
    int totalPausedSeconds = session.totalPausedSeconds;
    if (session.isPaused && session.pausedAt != null) {
      totalPausedSeconds += now.difference(session.pausedAt!).inSeconds;
    }

    // Calculate billable duration (raw duration minus paused time)
    final rawDurationMinutes = (session.endTime ?? now)
        .difference(session.startTime)
        .inMinutes;
    final pausedMinutes = (totalPausedSeconds / 60).round();
    final billableMinutes = rawDurationMinutes - pausedMinutes;
    double hours = billableMinutes / 60.0;

    if (session.tablePurpose == TablePurpose.dining) {
      hours = 0;
    } else if ((session.minimumBillableMinutes ?? 0) > 0) {
      final double minHours = (session.minimumBillableMinutes! / 60.0);
      if (hours < minHours) hours = minHours;
    }

    double originalAmount =
        (hours * session.hourlyRate) + session.combinedOrderAmount;
    originalAmount = (originalAmount * 100).round() / 100;

    double actualCreditsUsed = 0.0;
    if (creditsToAttemptToUse > 0 && customer.credits > 0) {
      final double usableCredits = customer.credits;
      actualCreditsUsed = creditsToAttemptToUse > usableCredits
          ? usableCredits
          : creditsToAttemptToUse;
      actualCreditsUsed = actualCreditsUsed > originalAmount
          ? originalAmount
          : actualCreditsUsed;
      actualCreditsUsed = (actualCreditsUsed * 100).round() / 100;
    }

    double finalPayableAmount = (originalAmount - actualCreditsUsed);
    finalPayableAmount = (finalPayableAmount * 100).round() / 100;
    finalPayableAmount = finalPayableAmount < 0 ? 0 : finalPayableAmount;

    return {
      'originalAmount': originalAmount,
      'creditsToAttemptToUse': creditsToAttemptToUse,
      'customerCreditsAvailable': customer.credits,
      'creditsApplied': actualCreditsUsed,
      'finalAmount': finalPayableAmount,
      'payableAmount': finalPayableAmount,
    };
  }

  /// Ends an active session, processes payment, and updates all related records.
  ///
  /// This method:
  /// 1. Aggregates all orders linked to the session
  /// 2. Calculates the final bill with discounts
  /// 3. Processes payment (credits and/or cash/UPI)
  /// 4. Updates session, table, and order documents
  /// 5. Creates PTL match records if applicable
  /// 6. Prints the final bill
  Future<void> endSession({
    required TableSession session,
    required SnookerTable table,
    required Customer customer,
    required dynamic paymentMethod,
    required AppUser completedBy,
    Map<String, double>? discounts,
    int? loserPlayerIndex,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();

    // If session is currently paused, add the final pause duration
    int finalTotalPausedSeconds = session.totalPausedSeconds;
    if (session.isPaused && session.pausedAt != null) {
      final finalPauseDuration = now.difference(session.pausedAt!);
      finalTotalPausedSeconds += finalPauseDuration.inSeconds;
    }

    // Aggregate live data for all associated orders
    final orderData = await _aggregateOrderData(session.id);
    final liveCafeTotal = orderData['cafeTotal'] as double;
    final liveMerchandiseTotal = orderData['merchandiseTotal'] as double;
    final cafeOrdersSnapshot = orderData['cafeSnapshot'] as QuerySnapshot;
    final merchandiseOrdersSnapshot =
        orderData['merchandiseSnapshot'] as QuerySnapshot;
    final orderItems = orderData['orderItems'] as List<Map<String, dynamic>>;
    final liveTotalFromOrders = liveCafeTotal + liveMerchandiseTotal;

    // Calculate table charges (accounting for paused time)
    final rawDurationMinutes = now.difference(session.startTime).inMinutes;
    final pausedMinutes = (finalTotalPausedSeconds / 60).round();
    final billableMinutes = rawDurationMinutes - pausedMinutes;
    double elapsedHours = billableMinutes / 60.0;

    if (session.tablePurpose == TablePurpose.dining) {
      elapsedHours = 0;
    } else if ((session.minimumBillableMinutes ?? 0) > 0) {
      final double minHours = (session.minimumBillableMinutes! / 60.0);
      if (elapsedHours < minHours) elapsedHours = minHours;
    }
    final double tableCharges = elapsedHours * session.hourlyRate;

    // Add table charges to order items
    final allItems = List<Map<String, dynamic>>.from(orderItems);
    if (tableCharges > 0) {
      allItems.add({
        'name': 'Table Charges',
        'price': tableCharges,
        'quantity': 1,
      });
    }

    // Calculate final bill
    final double subtotal = tableCharges + liveTotalFromOrders;
    final billResult = _calculateFinalBill(
      subtotal: subtotal,
      discounts: discounts,
      paymentMethod: paymentMethod,
      customerCredits: customer.credits,
    );

    final double totalAfterDiscounts =
        billResult['totalAfterDiscounts'] as double;
    final double intendedCreditsToDebit =
        billResult['creditsDebited'] as double;
    final double finalBillAmount = billResult['finalBillAmount'] as double;
    final PaymentMode finalPaymentMode =
        billResult['paymentMode'] as PaymentMode;
    final Map<String, dynamic> appliedDiscounts =
        billResult['appliedDiscounts'] as Map<String, dynamic>;

    // NOTE: Customer credit debit will be done AFTER batch commit using atomic transaction
    // to prevent negative balances from race conditions

    // Update session document - initially set credits to intended amount
    // Will be corrected after atomic credit debit if needed
    final sessionRef = _tenant.sessions().doc(session.id);
    batch.update(sessionRef, {
      'status': SessionStatus.completed.name,
      'endTime': now,
      'discountsApplied': appliedDiscounts,
      'totalCafeAmount': liveCafeTotal,
      'totalMerchandiseAmount': liveMerchandiseTotal,
      'totalAmount': totalAfterDiscounts,
      'grossAmount': totalAfterDiscounts,
      'totalBillAmount': finalBillAmount,
      'creditsUsed':
          intendedCreditsToDebit, // Will be updated after atomic debit
      'creditsEarned': 0.0,
      'paymentMode': finalPaymentMode.name,
      'orderItems': allItems,
      'customerId': customer.id,
      'customerName': customer.name,
      'customerPhoneNumber': customer.phoneNumber,
      'billingInProgress': false,
      'billingMarkedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'completedById': completedBy.uid,
      'completedByName': completedBy.name,
      'completedByRole': completedBy.role.name,
      // Reset pause state and store final totals
      'isPaused': false,
      'pausedAt': null,
      'totalPausedSeconds': finalTotalPausedSeconds,
      if (session.isPTL) 'loserPlayerIndex': loserPlayerIndex,
    });

    // Mark orders as billed
    // IMPORTANT: Use totalAfterDiscounts (full session amount) as denominator
    // for proportional credit allocation, not just the order totals.
    // This ensures each order gets its fair share of credits based on the
    // entire session bill (table + orders).
    _markOrdersBilled(
      batch: batch,
      snapshot: cafeOrdersSnapshot,
      collection: 'cafe_orders',
      session: session,
      creditsDebited: intendedCreditsToDebit,
      totalSessionAmount: totalAfterDiscounts,
      paymentMode: finalPaymentMode,
      now: now,
    );
    _markOrdersBilled(
      batch: batch,
      snapshot: merchandiseOrdersSnapshot,
      collection: 'merchandise_orders',
      session: session,
      creditsDebited: intendedCreditsToDebit,
      totalSessionAmount: totalAfterDiscounts,
      paymentMode: finalPaymentMode,
      now: now,
    );

    // Update table status
    final tableRef = _tenant.tables().doc(table.id);
    batch.update(tableRef, {
      'status': TableStatus.available.name,
      'currentSessionId': null,
      'sessionStartTime': null,
    });

    await batch.commit();
    await _syncPublicFloorForTable(table.id);

    // Process credits payment atomically AFTER batch commit to prevent negative balances
    double actualCreditsDebited = 0.0;
    if (intendedCreditsToDebit > 0 && customer.id.isNotEmpty) {
      final debitResult = await CreditService.safeDebitCredits(
        tenant: _tenant,
        customerId: customer.id,
        amount: intendedCreditsToDebit,
        reference: CreditReference.sessionPayment(
          session.id,
          tableName: table.name,
        ),
        performedBy: completedBy,
        allowPartial:
            true, // Allow partial debit for sessions (debit what's available)
      );

      if (debitResult.success) {
        actualCreditsDebited = debitResult.actualDebited;

        // If we debited less than intended, update the session record
        if (actualCreditsDebited < intendedCreditsToDebit) {
          await sessionRef.update({
            'creditsUsed': actualCreditsDebited,
            'creditDebitPartial': true,
            'intendedCreditsToDebit': intendedCreditsToDebit,
          });
          AppLogger.warning(
            'Session ${session.id}: Partial credit debit. Intended: ₹$intendedCreditsToDebit, Actual: ₹$actualCreditsDebited',
            tag: 'TableService',
          );
        }
      } else {
        // Credit debit completely failed - mark session as needing attention
        await sessionRef.update({
          'creditsUsed': 0,
          'creditDebitFailed': true,
          'creditDebitError': debitResult.error,
          'intendedCreditsToDebit': intendedCreditsToDebit,
        });
        AppLogger.error(
          'Session ${session.id}: Credit debit failed - ${debitResult.error}',
          tag: 'TableService',
        );
      }
    }

    // Handle PTL leaderboard integration
    await _handlePTLCompletion(
      session: session,
      table: table,
      loserPlayerIndex: loserPlayerIndex,
      completedBy: completedBy,
    );

    // Print final bill
    await _printSessionBill(
      session: session,
      table: table,
      customer: customer,
      orderItems: allItems,
      finalBillAmount: finalBillAmount,
      subtotal: subtotal,
      appliedDiscounts: appliedDiscounts,
      actualCreditsDebited: actualCreditsDebited,
      loserPlayerIndex: loserPlayerIndex,
    );
  }

  /// Pauses an active session timer.
  ///
  /// When paused:
  /// - Timer stops counting
  /// - Billing is frozen at the current duration
  /// - Session remains on the table (still occupied)
  Future<void> pauseSession({required TableSession session}) async {
    if (session.status != SessionStatus.active) {
      throw 'Cannot pause a session that is not active';
    }
    if (session.isPaused) {
      throw 'Session is already paused';
    }

    final now = DateTime.now();
    final sessionRef = _tenant.sessions().doc(session.id);

    await sessionRef.update({
      'isPaused': true,
      'pausedAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Resumes a paused session timer.
  ///
  /// When resumed:
  /// - Timer continues counting from where it left off
  /// - Paused duration is added to totalPausedSeconds
  Future<void> resumeSession({required TableSession session}) async {
    if (session.status != SessionStatus.active) {
      throw 'Cannot resume a session that is not active';
    }
    if (!session.isPaused || session.pausedAt == null) {
      throw 'Session is not paused';
    }

    final now = DateTime.now();
    final pausedDuration = now.difference(session.pausedAt!);
    final newTotalPausedSeconds =
        session.totalPausedSeconds + pausedDuration.inSeconds;

    final sessionRef = _tenant.sessions().doc(session.id);

    await sessionRef.update({
      'isPaused': false,
      'pausedAt': null,
      'totalPausedSeconds': newTotalPausedSeconds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Starts a 5-minute break. Pauses the session timer and records break state.
  Future<void> startBreak({required TableSession session}) async {
    if (session.status != SessionStatus.active) {
      throw 'Cannot start break on a session that is not active';
    }
    if (session.isOnBreak) {
      throw 'Session is already on break';
    }

    final now = DateTime.now();
    final sessionRef = _tenant.sessions().doc(session.id);

    final updates = <String, dynamic>{
      'isOnBreak': true,
      'breakStartedAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!session.isPaused) {
      updates['isPaused'] = true;
      updates['pausedAt'] = Timestamp.fromDate(now);
    }

    await sessionRef.update(updates);
  }

  /// Ends the current break, resumes the session, and increments break count.
  Future<void> endBreak({required TableSession session}) async {
    if (!session.isOnBreak) {
      throw 'Session is not on break';
    }

    final now = DateTime.now();
    int newTotalPausedSeconds = session.totalPausedSeconds;
    if (session.isPaused && session.pausedAt != null) {
      newTotalPausedSeconds += now.difference(session.pausedAt!).inSeconds;
    }

    final sessionRef = _tenant.sessions().doc(session.id);

    await sessionRef.update({
      'isOnBreak': false,
      'breakStartedAt': null,
      'breaksTaken': session.breaksTaken + 1,
      'isPaused': false,
      'pausedAt': null,
      'totalPausedSeconds': newTotalPausedSeconds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Auto-resumes a break that has expired (>= 5 minutes).
  /// Safe to call on any session; no-ops if not applicable.
  Future<void> checkAndAutoResumeBreak({required TableSession session}) async {
    if (!session.isOnBreak || session.breakStartedAt == null) return;
    if (!session.isBreakExpired) return;
    await endBreak(session: session);
  }

  /// Cancels an active session without processing payment.
  ///
  /// This will:
  /// - Mark the session as cancelled
  /// - Mark all associated orders as cancelled
  /// - Restore stock for all order items
  /// - Free up the table
  Future<void> cancelSession({
    required TableSession session,
    required SnookerTable table,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();

    // Cancel the session
    final sessionRef = _tenant.sessions().doc(session.id);
    batch.update(sessionRef, {
      'status': SessionStatus.cancelled.name,
      'endTime': now,
      'totalAmount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Free up the table
    final tableRef = _tenant.tables().doc(table.id);
    batch.update(tableRef, {
      'status': TableStatus.available.name,
      'currentSessionId': null,
      'sessionStartTime': null,
    });

    // Cancel all associated cafe orders and restore stock
    final cafeOrdersSnapshot = await _tenant
        .cafeOrders()
        .where('sessionId', isEqualTo: session.id)
        .where(
          'status',
          whereIn: ['pending', 'ready', 'preparing', 'delivered'],
        )
        .get();

    for (final doc in cafeOrdersSnapshot.docs) {
      final orderRef = _tenant.cafeOrders().doc(doc.id);
      batch.update(orderRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Restore stock for each item
      final data = doc.data();
      final items = data['items'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          final itemId = item['itemId'] as String?;
          final quantity = parseFirestoreInt(item['quantity']);
          if (itemId != null && itemId.isNotEmpty && quantity > 0) {
            final stockRef = _tenant.stockItems().doc(itemId);
            batch.update(stockRef, {
              'quantity': FieldValue.increment(quantity),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }

    // Cancel all associated merchandise orders and restore stock
    final merchOrdersSnapshot = await _tenant
        .merchandiseOrders()
        .where('sessionId', isEqualTo: session.id)
        .where('status', whereIn: ['pending', 'delivered'])
        .get();

    for (final doc in merchOrdersSnapshot.docs) {
      final orderRef = _tenant.merchandiseOrders().doc(doc.id);
      batch.update(orderRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Restore stock for each item
      final data = doc.data();
      final items = data['items'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          final itemId = item['itemId'] as String?;
          final quantity = parseFirestoreInt(item['quantity']);
          if (itemId != null && itemId.isNotEmpty && quantity > 0) {
            final stockRef = _tenant.stockItems().doc(itemId);
            batch.update(stockRef, {
              'quantity': FieldValue.increment(quantity),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }

    await batch.commit();
    await _syncPublicFloorForTable(table.id);
  }

  // ============================================================
  // Table CRUD Operations
  // ============================================================

  /// Creates a new table or updates an existing one.
  Future<void> addTable(SnookerTable table) async {
    try {
      await _tenant
          .tables()
          .doc(table.id)
          .set(table.toJson(), SetOptions(merge: true));
      await _syncPublicFloorForTable(table.id);
    } catch (e) {
      throw 'Failed to add table: $e';
    }
  }

  /// Updates an existing table's configuration.
  Future<void> updateTable(SnookerTable table) async {
    try {
      await _tenant.tables().doc(table.id).update({
        ...table.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _syncPublicFloorForTable(table.id);
    } catch (e) {
      throw 'Failed to update table: $e';
    }
  }

  /// Deletes a table if it has no active sessions.
  Future<void> deleteTable(String tableId) async {
    try {
      await _db.runTransaction((transaction) async {
        final sessionsSnapshot = await _tenant
            .sessions()
            .where('tableId', isEqualTo: tableId)
            .where('status', isEqualTo: 'active')
            .get();

        if (sessionsSnapshot.docs.isNotEmpty) {
          throw 'Cannot delete table with active sessions';
        }

        transaction.delete(_tenant.tables().doc(tableId));
      });
      try {
        await PublicVenueSyncService.deletePublicFloorTable(_tenant, tableId);
      } catch (e) {
        AppLogger.warning(
          'Public floor delete failed: $e',
          tag: 'TableService',
        );
      }
    } catch (e) {
      throw 'Failed to delete table: $e';
    }
  }

  /// Updates only the status of a table.
  Future<void> updateTableStatus(String tableId, TableStatus newStatus) async {
    try {
      await _tenant.tables().doc(tableId).update({
        'status': newStatus.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _syncPublicFloorForTable(tableId);
    } catch (e) {
      throw 'Failed to update table status: $e';
    }
  }

  /// Updates specific settings for a table.
  Future<void> updateTableSettings(
    String tableId, {
    String? name,
    String? description,
    double? hourlyRate,
    String? typeId,
    TableStatus? status,
    TablePurpose? tablePurpose,
    bool? chargeMinimumOneHour,
    int? minimumBillableMinutes,
    bool clearMinimumBillableMinutes = false,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (hourlyRate != null) updates['hourlyRate'] = hourlyRate;
      if (typeId != null && typeId.isNotEmpty) {
        updates['type'] = typeId.toLowerCase();
      }
      if (status != null) updates['status'] = status.toString().split('.').last;
      if (tablePurpose != null) {
        updates['tablePurpose'] = tablePurpose.name;
      }
      if (chargeMinimumOneHour != null) {
        updates['chargeMinimumOneHour'] = chargeMinimumOneHour;
      }
      if (clearMinimumBillableMinutes) {
        updates['minimumBillableMinutes'] = FieldValue.delete();
      } else if (minimumBillableMinutes != null) {
        updates['minimumBillableMinutes'] = minimumBillableMinutes;
      }

      await _tenant.tables().doc(tableId).update(updates);
      await _syncPublicFloorForTable(tableId);
    } catch (e) {
      throw 'Failed to update table settings: $e';
    }
  }

  /// Marks a session that was incorrectly cancelled by the orphan cleanup as completed.
  ///
  /// This method:
  /// 1. Sets the session status to 'completed' (instead of cancelled)
  /// 2. Clears the cancelledReason field
  /// 3. Calculates and preserves billing amounts so sales are properly tracked
  ///
  /// **Warning**: Only use this for sessions that have `cancelledReason: 'auto_cleanup_orphaned_session'`
  Future<void> markOrphanCancelledAsCompleted({
    required TableSession session,
  }) async {
    // Validate this was indeed cancelled by orphan cleanup
    final cancelledReason = session.data['cancelledReason'] as String?;
    if (cancelledReason != 'auto_cleanup_orphaned_session') {
      throw 'This session was not cancelled by orphan cleanup. Cannot fix.';
    }

    final sessionRef = _tenant.sessions().doc(session.id);

    // Persist endTime so sales queries on endTime include this session.
    final effectiveEnd = session.endTime ?? DateTime.now();
    final duration = effectiveEnd.difference(session.startTime);

    final pausedSeconds = session.totalPausedSeconds;
    final billableMinutes = duration.inMinutes - (pausedSeconds ~/ 60);
    double elapsedHours = billableMinutes / 60.0;

    // Apply minimum billable time if configured
    if ((session.minimumBillableMinutes ?? 0) > 0) {
      final double minHours = (session.minimumBillableMinutes! / 60.0);
      if (elapsedHours < minHours) elapsedHours = minHours;
    }

    final double tableCharges = elapsedHours * session.hourlyRate;

    // Prefer sums from non-cancelled linked orders so sales match reality after cancel/repair.
    double cafeFromOrders = 0;
    final cafeSnap = await _tenant
        .cafeOrders()
        .where('sessionId', isEqualTo: session.id)
        .get();
    var nonCancelledCafe = 0;
    for (final d in cafeSnap.docs) {
      final st = (d.data()['status'] as String?)?.toLowerCase() ?? '';
      if (st == 'cancelled') continue;
      nonCancelledCafe++;
      cafeFromOrders += parseFirestoreDouble(d.data()['total']);
    }
    final double cafeAmount = nonCancelledCafe > 0
        ? cafeFromOrders
        : (session.totalCafeAmount ?? 0.0);

    double merchFromOrders = 0;
    final merchSnap = await _tenant
        .merchandiseOrders()
        .where('sessionId', isEqualTo: session.id)
        .get();
    var nonCancelledMerch = 0;
    for (final d in merchSnap.docs) {
      final st = (d.data()['status'] as String?)?.toLowerCase() ?? '';
      if (st == 'cancelled') continue;
      nonCancelledMerch++;
      merchFromOrders += parseFirestoreDouble(d.data()['total']);
    }
    final double merchandiseAmount = nonCancelledMerch > 0
        ? merchFromOrders
        : (session.totalMerchandiseAmount ?? 0.0);

    final double totalAmount = tableCharges + cafeAmount + merchandiseAmount;

    await sessionRef.update({
      'status': SessionStatus.completed.name,
      'cancelledReason': FieldValue.delete(),
      // Always write reconciled amounts (stored 0 is valid for ?? and hid real totals).
      'totalAmount': totalAmount,
      'totalBillAmount': totalAmount,
      'tableChargesAtCheckout': tableCharges,
      'grossAmount': totalAmount,
      'totalCafeAmount': cafeAmount,
      'totalMerchandiseAmount': merchandiseAmount,
      'endTime': Timestamp.fromDate(effectiveEnd),
      'paymentMode': session.paymentMode.name,
      'fixedFromOrphanCancel': true,
      'fixedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    AppLogger.info(
      'Fixed orphan-cancelled session: ${session.id} on table ${session.tableName} - '
      'marked as completed with total ₹${totalAmount.toStringAsFixed(2)}',
      tag: 'TableService',
    );
  }

  // ============================================================
  // Private Helper Methods
  // ============================================================

  static bool _orderExcludedFromSessionCheckoutBill(
    Map<String, dynamic>? data,
  ) {
    final s = (data?['status'] as String?)?.toLowerCase() ?? '';
    return s == 'cancelled';
  }

  Future<Map<String, dynamic>> _aggregateOrderData(String sessionId) async {
    double cafeTotal = 0;
    double merchandiseTotal = 0;
    final Map<String, Map<String, dynamic>> aggregatedItems = {};

    void addItem(String name, double price, int qty) {
      if (aggregatedItems.containsKey(name)) {
        aggregatedItems[name]!['quantity'] += qty;
      } else {
        aggregatedItems[name] = {'name': name, 'price': price, 'quantity': qty};
      }
    }

    final cafeSnapshot = await _tenant
        .cafeOrders()
        .where('sessionId', isEqualTo: sessionId)
        .get();

    for (var doc in cafeSnapshot.docs) {
      final cdata = doc.data();
      if (_orderExcludedFromSessionCheckoutBill(cdata)) continue;
      cafeTotal += parseFirestoreDouble(cdata['total']);
      final items = (cdata['items'] as List? ?? []);
      for (final item in items) {
        final data = Map<String, dynamic>.from(item as Map);
        addItem(
          data['name'] as String? ?? 'Item',
          parseFirestoreDouble(data['price']),
          parseFirestoreInt(data['quantity'], fallback: 1),
        );
      }
    }

    final merchandiseSnapshot = await _tenant
        .merchandiseOrders()
        .where('sessionId', isEqualTo: sessionId)
        .get();

    for (var doc in merchandiseSnapshot.docs) {
      final mdata = doc.data();
      if (_orderExcludedFromSessionCheckoutBill(mdata)) continue;
      merchandiseTotal += parseFirestoreDouble(mdata['total']);
      final items = (mdata['items'] as List? ?? []);
      for (final item in items) {
        final data = Map<String, dynamic>.from(item as Map);
        addItem(
          data['name'] as String? ?? 'Item',
          parseFirestoreDouble(data['price']),
          parseFirestoreInt(data['quantity'], fallback: 1),
        );
      }
    }

    return {
      'cafeTotal': cafeTotal,
      'merchandiseTotal': merchandiseTotal,
      'cafeSnapshot': cafeSnapshot,
      'merchandiseSnapshot': merchandiseSnapshot,
      'orderItems': aggregatedItems.values.toList(),
    };
  }

  Map<String, dynamic> _calculateFinalBill({
    required double subtotal,
    required Map<String, double>? discounts,
    required dynamic paymentMethod,
    required double customerCredits,
  }) {
    final discountPreview = applySubtotalPercentageDiscounts(
      subtotal: subtotal,
      discounts: discounts,
    );
    final double totalAfterDiscounts = discountPreview.totalAfterDiscounts;
    final Map<String, dynamic> appliedDiscounts =
        discountPreview.appliedDiscounts;

    double creditsToDebit = 0;
    PaymentMode finalPaymentMode = PaymentMode.cash;

    // Handle PaymentMethod enum (from PaymentMethodDialog)
    if (paymentMethod is PaymentMethod) {
      switch (paymentMethod) {
        case PaymentMethod.credits:
          creditsToDebit = totalAfterDiscounts;
          finalPaymentMode = PaymentMode.credit;
          break;
        case PaymentMethod.upi:
          finalPaymentMode = PaymentMode.upi;
          break;
        case PaymentMethod.cash:
          finalPaymentMode = PaymentMode.cash;
          break;
      }
    }
    // Handle String format (legacy)
    else if (paymentMethod is String) {
      if (paymentMethod == 'Credits' || paymentMethod == 'credits') {
        creditsToDebit = totalAfterDiscounts;
        finalPaymentMode = PaymentMode.credit;
      } else if (paymentMethod == 'UPI' || paymentMethod == 'upi') {
        finalPaymentMode = PaymentMode.upi;
      }
    }
    // Handle Map format (split payments)
    else if (paymentMethod is Map) {
      creditsToDebit =
          paymentMethod['Credits'] as double? ??
          paymentMethod['credits'] as double? ??
          0.0;

      // Determine primary payment mode
      if (paymentMethod.containsKey('UPI') ||
          paymentMethod.containsKey('upi')) {
        finalPaymentMode = PaymentMode.upi;
      } else if (paymentMethod.containsKey('Cash') ||
          paymentMethod.containsKey('cash')) {
        finalPaymentMode = PaymentMode.cash;
      }

      // If only credits in the map, set to credit mode
      if (creditsToDebit > 0 &&
          !paymentMethod.containsKey('Cash') &&
          !paymentMethod.containsKey('cash') &&
          !paymentMethod.containsKey('UPI') &&
          !paymentMethod.containsKey('upi')) {
        finalPaymentMode = PaymentMode.credit;
      }
    }

    double actualCreditsDebited = 0;
    if (creditsToDebit > 0 && customerCredits > 0) {
      actualCreditsDebited = creditsToDebit > customerCredits
          ? customerCredits
          : creditsToDebit;
      actualCreditsDebited = actualCreditsDebited > totalAfterDiscounts
          ? totalAfterDiscounts
          : actualCreditsDebited;
    }

    final double finalBillAmount = totalAfterDiscounts - actualCreditsDebited;

    // If fully paid with credits, ensure payment mode is credit
    if (finalBillAmount <= 0 && actualCreditsDebited > 0) {
      finalPaymentMode = PaymentMode.credit;
    }

    return {
      'totalAfterDiscounts': totalAfterDiscounts,
      'creditsDebited': actualCreditsDebited,
      'finalBillAmount': finalBillAmount,
      'paymentMode': finalPaymentMode,
      'appliedDiscounts': appliedDiscounts,
    };
  }

  // NOTE: _debitCustomerCredits is no longer used. Credit debits are now done
  // atomically after batch commit using CreditService.safeDebitCredits to
  // prevent negative balances from race conditions.

  /// Marks orders as billed and distributes credits proportionally.
  ///
  /// CRITICAL: Credits are distributed based on each order's share of the
  /// TOTAL session amount (including table charges), not just the order totals.
  ///
  /// Example:
  /// - Table charges = ₹150, Cafe order = ₹50
  /// - Total session = ₹200, paid fully by credits
  /// - Cafe order gets: (50/200) * 200 = ₹50 of credits
  void _markOrdersBilled({
    required WriteBatch batch,
    required QuerySnapshot snapshot,
    required String collection,
    required TableSession session,
    required double creditsDebited,
    required double totalSessionAmount,
    required PaymentMode paymentMode,
    required DateTime now,
  }) {
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (_orderExcludedFromSessionCheckoutBill(data)) continue;

      final DocumentReference<Map<String, dynamic>> orderRef =
          collection == 'cafe_orders'
          ? _tenant.cafeOrders().doc(doc.id)
          : _tenant.merchandiseOrders().doc(doc.id);
      final orderTotal = parseFirestoreDouble(data?['total']);

      // Calculate credits proportionally based on TOTAL session amount
      // This ensures fair distribution when table charges are included
      double orderCreditsUsed = 0.0;
      if (creditsDebited > 0 && totalSessionAmount > 0) {
        orderCreditsUsed = (orderTotal / totalSessionAmount) * creditsDebited;
        orderCreditsUsed = double.parse(orderCreditsUsed.toStringAsFixed(2));
        // Ensure we don't allocate more credits than the order total
        if (orderCreditsUsed > orderTotal) {
          orderCreditsUsed = orderTotal;
        }
      }

      final double orderNonCreditPortion = (orderTotal - orderCreditsUsed)
          .clamp(0.0, orderTotal);

      final Map<String, double> orderPaymentBreakdown = {};
      if (orderCreditsUsed > 0) {
        orderPaymentBreakdown['credits'] = orderCreditsUsed;
      }
      if (orderNonCreditPortion > 0 && paymentMode != PaymentMode.credit) {
        orderPaymentBreakdown[paymentMode.name] = orderNonCreditPortion;
      }

      // Determine effective payment method for this order
      String effectivePaymentMethod;
      if (orderCreditsUsed >= orderTotal || paymentMode == PaymentMode.credit) {
        effectivePaymentMethod = 'credits';
      } else {
        effectivePaymentMethod = paymentMode.name;
      }

      batch.update(orderRef, {
        'isBilled': true,
        'billedAt': Timestamp.fromDate(now),
        'sessionId': session.id,
        'status': 'completed',
        'creditsUsed': orderCreditsUsed,
        'paymentMethod': effectivePaymentMethod,
        if (orderPaymentBreakdown.isNotEmpty)
          'paymentBreakdown': orderPaymentBreakdown,
      });
    }
  }

  Future<String> _resolvePtlGameType(SnookerTable table) async {
    try {
      final doc = await _tenant.tableTypeDefinitions().doc(table.typeId).get();
      if (doc.exists) {
        return TableTypeDefinition.fromFirestore(doc).ptlGameType;
      }
    } catch (e, st) {
      AppLogger.debug(
        'PTL game type: table type doc read failed, using legacy mapping: $e\n$st',
        tag: 'TableService',
      );
      // Fall through to legacy id mapping
    }
    switch (table.typeId.toLowerCase()) {
      case 'snooker':
        return 'snooker';
      case 'pool':
        return 'pool';
      case 'carrom':
        return 'carrom';
      case 'darts':
        return 'darts';
      default:
        return 'other';
    }
  }

  Future<void> _handlePTLCompletion({
    required TableSession session,
    required SnookerTable table,
    required int? loserPlayerIndex,
    required AppUser completedBy,
  }) async {
    if (!session.isPTL || loserPlayerIndex == null) return;

    try {
      final ptlService = PTLMatchService(_tenant);
      final gameType = await _resolvePtlGameType(table);
      await ptlService.createPTLMatchRecords(
        session: session,
        loserPlayerIndex: loserPlayerIndex,
        completedBy: completedBy,
        gameType: gameType,
      );
      // PTL match records created successfully
    } catch (e) {
      // Log error but don't throw - PTL is non-critical
      AppLogger.warning(
        'Error creating PTL match records: $e',
        tag: 'TableService',
      );
    }
  }

  Future<void> _printSessionBill({
    required TableSession session,
    required SnookerTable table,
    required Customer customer,
    required List<Map<String, dynamic>> orderItems,
    required double finalBillAmount,
    required double subtotal,
    required Map<String, dynamic> appliedDiscounts,
    required double actualCreditsDebited,
    required int? loserPlayerIndex,
  }) async {
    try {
      String? loserPlayerName;
      if (session.isPTL &&
          session.playerNames.isNotEmpty &&
          loserPlayerIndex != null &&
          loserPlayerIndex > 0 &&
          loserPlayerIndex <= session.playerNames.length) {
        loserPlayerName = session.playerNames[loserPlayerIndex - 1];
      }

      await PrinterService.printDocument(
        jobType: PrintJobType.billOnly,
        id: session.id,
        items: orderItems,
        total: finalBillAmount,
        customerName: customer.name,
        tableName: table.name,
        subtotal: subtotal,
        discounts: appliedDiscounts.isNotEmpty ? appliedDiscounts : null,
        creditsUsed: actualCreditsDebited > 0 ? actualCreditsDebited : null,
        isPTL: session.isPTL,
        playerCount: session.playerCount,
        loserPlayerIndex: loserPlayerIndex,
        loserPlayerName: loserPlayerName,
      );
    } catch (e) {
      AppLogger.warning(
        'Error printing final session bill: $e',
        tag: 'TableService',
      );
    }
  }
}
