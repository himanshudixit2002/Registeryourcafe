import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/app_user.dart';
import '../models/guest_cafe_order.dart';
import '../models/table.dart';
import '../models/venue_kind.dart';
import 'order_service.dart';

class GuestCafeOrderService {
  GuestCafeOrderService(this._tenant);

  final TenantRef _tenant;

  /// Pending guest orders (newest first).
  Stream<List<GuestCafeOrder>> pendingOrdersStream() {
    return _tenant
        .guestCafeOrders()
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (s) => s.docs.map(GuestCafeOrder.fromFirestore).toList(),
        );
  }

  /// Creates a kitchen [CafeOrder] from a pending guest order and marks guest doc converted.
  Future<String> promoteToCafeOrder({
    required GuestCafeOrder guest,
    required AppUser staff,
    VenueKind venueKind = VenueKind.diningCafe,
  }) async {
    if (!guest.isPending) {
      throw StateError('Guest order is not pending.');
    }
    if (guest.convertedCafeOrderId != null &&
        guest.convertedCafeOrderId!.isNotEmpty) {
      throw StateError('Already converted.');
    }

    final items = guest.items.map((e) => e.toCafeOrderItem()).toList();
    final table = guest.orderMode == 'table' && guest.tableId.isNotEmpty
        ? SnookerTable(
            id: guest.tableId,
            name: guest.tableName.isNotEmpty ? guest.tableName : guest.tableId,
            hourlyRate: 0,
            typeId: venueKind.defaultTableTypeId,
            status: TableStatus.available,
            tablePurpose: TablePurpose.dining,
          )
        : null;

    final noteParts = <String>[
      'Guest: ${guest.guestName} · ${guest.guestPhone}',
      if (guest.orderMode == 'table')
        'Table: ${guest.tableName} (${guest.tableId})'
      else
        'Counter / takeaway',
      if (guest.guestNotes.trim().isNotEmpty) guest.guestNotes.trim(),
    ];

    final cafe = await OrderService.createCafeOrder(
      tenant: _tenant,
      items: items,
      total: guest.total,
      customer: null,
      table: table,
      session: null,
      paymentMethod: null,
      paymentBreakdown: null,
      creditsUsed: 0,
      createdBy: staff,
      unbilledKitchenQueue: true,
      sourceGuestCafeOrderId: guest.id,
      orderNotes: noteParts.join('\n'),
    );

    await _tenant.guestCafeOrders().doc(guest.id).update({
      'status': 'converted',
      'convertedCafeOrderId': cafe.id,
      'updatedAt': Timestamp.now(),
    });

    return cafe.id;
  }

  Future<void> cancelGuestOrder(String guestOrderId) async {
    await _tenant.guestCafeOrders().doc(guestOrderId).update({
      'status': 'cancelled',
      'updatedAt': Timestamp.now(),
    });
  }
}

/// Submit from anonymous landing (uses root Firestore; no tenant staff context).
Future<String> submitGuestCafeOrder({
  required String companyId,
  required List<GuestCafeOrderItem> items,
  required double total,
  required String guestName,
  required String guestPhone,
  required String orderMode,
  required String tableId,
  required String tableName,
  required String guestNotes,
  required String requesterUid,
}) async {
  if (items.isEmpty) throw ArgumentError('items empty');
  final db = FirebaseFirestore.instance;
  final ref = await db.collection('companies')
      .doc(companyId)
      .collection('guest_cafe_orders')
      .add({
        'items': items.map((e) => e.toFirestoreMap()).toList(),
        'total': total,
        'status': 'pending',
        'requesterUid': requesterUid,
        'createdAt': Timestamp.now(),
        'guestName': guestName.trim(),
        'guestPhone': guestPhone.trim(),
        'orderMode': orderMode,
        'tableId': tableId,
        'tableName': tableName,
        'guestNotes': guestNotes.trim(),
      });
  return ref.id;
}
