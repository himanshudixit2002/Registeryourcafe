import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // for DateTimeRange
import 'package:registeryourcafe/models/cafe_order.dart';
import 'package:registeryourcafe/models/merchandise_order.dart';
import 'package:registeryourcafe/utils/firestore_utils.dart';
import 'package:registeryourcafe/utils/app_logger.dart';

class ItemRevenueService {
  final FirebaseFirestore _firestore;

  ItemRevenueService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Calculates total revenue for a given [itemId] within an optional [dateRange].
  /// If [includeRefunds] is true, refunded orders will be subtracted from revenue.
  Future<double> calculateRevenue({
    required String itemId,
    DateTimeRange? dateRange,
    bool includeRefunds = false,
  }) async {
    final double cafeRevenue = await _calculateForCollection(
      collection: 'cafe_orders',
      itemId: itemId,
      dateRange: dateRange,
      includeRefunds: includeRefunds,
    );
    final double merchRevenue = await _calculateForCollection(
      collection: 'merchandise_orders',
      itemId: itemId,
      dateRange: dateRange,
      includeRefunds: includeRefunds,
    );
    return cafeRevenue + merchRevenue;
  }

  Future<double> _calculateForCollection({
    required String collection,
    required String itemId,
    DateTimeRange? dateRange,
    required bool includeRefunds,
  }) async {
    Query query = _firestore.collection(collection);

    // Status filter – include only finished orders. Refunds are processed separately.
    query = query.where(
      'status',
      whereIn: ['delivered', 'completed', 'refunded'],
    );

    // Date range filter if provided.
    if (dateRange != null) {
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: dateRange.start)
          .where('createdAt', isLessThanOrEqualTo: dateRange.end);
    }

    final snapshot = await query.get();

    double revenue = 0.0;
    for (final doc in snapshot.docs) {
      if (collection == 'cafe_orders') {
        final order = CafeOrder.fromFirestore(doc);
        revenue +=
            _extractRevenueFromItems(order.items, itemId) *
            _refundMultiplier(order.isRefunded, includeRefunds);
      } else if (collection == 'merchandise_orders') {
        final order = MerchandiseOrder.fromFirestore(doc);
        revenue +=
            _extractRevenueFromItems(order.items, itemId) *
            _refundMultiplier(order.isRefunded, includeRefunds);
      }
    }
    return revenue;
  }

  double _extractRevenueFromItems(List<dynamic> items, String itemId) {
    double total = 0.0;
    for (final item in items) {
      // CafeOrderItem and MerchandiseOrderItem both expose itemId, price, quantity.
      try {
        final id = (item as dynamic).itemId?.toString();
        if (id == itemId) {
          final price = parseFirestoreDouble((item as dynamic).price);
          final qty = parseFirestoreInt((item as dynamic).quantity, fallback: 1);
          total += price * qty;
        }
      } catch (e, st) {
        AppLogger.debug(
          'Item revenue: skip malformed line item: $e\n$st',
          tag: 'ItemRevenue',
        );
      }
    }
    return total;
  }

  double _refundMultiplier(bool isRefunded, bool includeRefunds) {
    if (!includeRefunds) return isRefunded ? 0.0 : 1.0;
    return isRefunded ? -1.0 : 1.0;
  }
}
