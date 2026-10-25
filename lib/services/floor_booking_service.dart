import '../firestore/tenant_firestore.dart';
import '../models/floor_booking_request.dart';
import '../models/public_booking_slot.dart';

/// Staff-side booking approvals and guest submission helpers.
class FloorBookingService {
  FloorBookingService(this._tenant);

  final TenantRef _tenant;

  /// Submits a pending request (caller must be signed in, e.g. anonymous).
  Future<String> submitRequest(FloorBookingRequest draft) async {
    final ref = _tenant.floorBookingRequests().doc();
    await ref.set(draft.toFirestoreForCreate());
    return ref.id;
  }

  Stream<List<FloorBookingRequest>> pendingRequestsStream() {
    return _tenant
        .floorBookingRequests()
        .where(
          'status',
          isEqualTo: FloorBookingRequestStatus.pending.storageName,
        )
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs.map(FloorBookingRequest.fromFirestore).toList(),
        );
  }

  /// Approve [requestId] and create a [PublicBookingSlot]. Throws if overlap.
  ///
  /// Overlap is checked before the transaction (Firestore transactions cannot
  /// run collection queries in the Dart SDK). A narrow race remains if two
  /// staff approve conflicting windows simultaneously.
  Future<void> approveRequest({
    required String requestId,
    required String decidedByUid,
    String? decisionNote,
  }) async {
    final reqRef = _tenant.floorBookingRequests().doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      throw StateError('Booking request not found.');
    }
    final req = FloorBookingRequest.fromFirestore(reqSnap);
    if (req.status != FloorBookingRequestStatus.pending) {
      throw StateError('Request is no longer pending.');
    }

    final existingSlots = await _tenant
        .publicBookingSlots()
        .where('tableId', isEqualTo: req.tableId)
        .get();
    for (final d in existingSlots.docs) {
      final slot = PublicBookingSlot.fromFirestore(d);
      if (bookingIntervalsOverlap(
        req.startAt,
        req.endAt,
        slot.startAt,
        slot.endAt,
      )) {
        throw StateError(
          'This table already has an approved booking that overlaps this time.',
        );
      }
    }

    await _tenant.db.runTransaction((tx) async {
      final fresh = await tx.get(reqRef);
      if (!fresh.exists) {
        throw StateError('Booking request not found.');
      }
      final req2 = FloorBookingRequest.fromFirestore(fresh);
      if (req2.status != FloorBookingRequestStatus.pending) {
        throw StateError('Request is no longer pending.');
      }

      final slotRef = _tenant.publicBookingSlots().doc();
      final slot = PublicBookingSlot(
        id: slotRef.id,
        tableId: req2.tableId,
        startAt: req2.startAt,
        endAt: req2.endAt,
        requestId: requestId,
      );
      tx.set(slotRef, slot.toFirestore());
      tx.update(
        reqRef,
        req2.toFirestoreStaffDecision(
          newStatus: FloorBookingRequestStatus.approved,
          decidedByUid: decidedByUid,
          decisionNote: decisionNote,
          publicSlotId: slotRef.id,
        ),
      );
    });
  }

  Future<void> declineRequest({
    required String requestId,
    required String decidedByUid,
    String? decisionNote,
  }) async {
    final reqRef = _tenant.floorBookingRequests().doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      throw StateError('Booking request not found.');
    }
    final req = FloorBookingRequest.fromFirestore(reqSnap);
    if (req.status != FloorBookingRequestStatus.pending) {
      throw StateError('Request is no longer pending.');
    }
    await reqRef.update(
      req.toFirestoreStaffDecision(
        newStatus: FloorBookingRequestStatus.declined,
        decidedByUid: decidedByUid,
        decisionNote: decisionNote,
      ),
    );
  }

  /// True if [at] falls inside an active public slot for [tableId].
  static Future<bool> tableHasActivePublicSlotAt(
    TenantRef tenant,
    String tableId,
    DateTime at,
  ) async {
    final snap = await tenant
        .publicBookingSlots()
        .where('tableId', isEqualTo: tableId)
        .get();
    for (final d in snap.docs) {
      final slot = PublicBookingSlot.fromFirestore(d);
      if (slot.containsInstant(at)) return true;
    }
    return false;
  }
}
