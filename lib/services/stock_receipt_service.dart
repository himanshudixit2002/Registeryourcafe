import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/stock_item.dart';
import '../models/stock_receipt.dart';
import '../utils/app_logger.dart';
import '../utils/business_validators.dart';
import '../utils/firestore_utils.dart';
import 'stock_cost_service.dart';
import 'stock_helper.dart';

class _QtyCostAgg {
  double qty = 0;
  double costSum = 0;
}

class StockReceiptService {
  StockReceiptService._();

  static const int maxLinesPerReceipt = 50;

  static Stream<List<StockReceipt>> watchReceipts(
    TenantRef tenant, {
    int limit = 100,
  }) {
    return tenant
        .stockReceipts()
        .orderBy('receivedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(StockReceipt.fromFirestore).toList());
  }

  /// Receipts with [receivedAt] on or after [from], newest first (for spend analysis).
  static Stream<List<StockReceipt>> watchReceiptsFrom(
    TenantRef tenant, {
    required Timestamp from,
    int limit = 1000,
  }) {
    return tenant
        .stockReceipts()
        .where('receivedAt', isGreaterThanOrEqualTo: from)
        .orderBy('receivedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(StockReceipt.fromFirestore).toList());
  }

  /// Commits a vendor receipt: increments stock, updates [lastUnitCost], writes history, stores receipt.
  static Future<String> commitReceipt(
    TenantRef tenant, {
    required String vendorId,
    required DateTime receivedAt,
    required List<StockReceiptCommitLine> lines,
    String? invoiceNumber,
    String? reference,
    String? notes,
    String? vendorNameSnapshot,
    String? createdById,
    String? createdByName,
  }) async {
    BusinessValidators.validateIdExists(vendorId, 'Vendor');
    BusinessValidators.validateItemsNotEmpty(lines, 'receipt line');

    if (lines.length > maxLinesPerReceipt) {
      throw InvalidInputException(
        'At most $maxLinesPerReceipt lines per receipt',
      );
    }

    for (final line in lines) {
      BusinessValidators.validateIdExists(line.stockItemId, 'Stock item');
      if (line.quantity <= 0) {
        throw InvalidAmountException('Quantity must be greater than zero');
      }
      if (line.unitCost < 0) {
        throw InvalidAmountException('Unit cost cannot be negative');
      }
    }

    final receiptsCol = tenant.stockReceipts();
    final stockCol = tenant.stockItems();

    final mergedQty = <String, double>{};
    final mergedCostNumerator = <String, double>{};
    for (final line in lines) {
      mergedQty[line.stockItemId] =
          (mergedQty[line.stockItemId] ?? 0) + line.quantity;
      mergedCostNumerator[line.stockItemId] =
          (mergedCostNumerator[line.stockItemId] ?? 0) +
          line.quantity * line.unitCost;
    }

    final distinctIds = mergedQty.keys.toList();
    final receiptRef = receiptsCol.doc();
    final receiptId = receiptRef.id;

    final reasonBase = StringBuffer('Vendor receipt');
    if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty) {
      reasonBase.write(' ${invoiceNumber.trim()}');
    } else {
      reasonBase.write(' $receiptId');
    }
    final reasonStr = reasonBase.toString();

    final lineMaps = <Map<String, dynamic>>[];
    double totalCost = 0;

    final allTouchedIds = <String>{};

    try {
      await tenant.db.runTransaction((transaction) async {
        final stockSnapshots =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final id in distinctIds) {
          final ref = stockCol.doc(id);
          final snap = await transaction.get(ref);
          if (!snap.exists) {
            throw NotFoundException('Stock item not found: $id');
          }
          stockSnapshots[id] = snap;
        }

        final linkedToFetch = <String>{};
        for (final id in distinctIds) {
          final data = stockSnapshots[id]!.data()!;
          for (final L in StockItem.parseLinkedStockItemIdsField(
            data['linkedStockItemIds'],
          )) {
            if (L != id) linkedToFetch.add(L);
          }
        }
        for (final id in linkedToFetch) {
          if (stockSnapshots.containsKey(id)) continue;
          final ref = stockCol.doc(id);
          final snap = await transaction.get(ref);
          if (!snap.exists) {
            throw NotFoundException('Linked stock item not found: $id');
          }
          stockSnapshots[id] = snap;
        }

        for (final line in lines) {
          final snap = stockSnapshots[line.stockItemId]!;
          final data = snap.data()!;
          final name = data['name'] as String? ?? '';
          final isMerch = data['isMerchandise'] as bool? ?? false;
          final lineTotal = line.quantity * line.unitCost;
          totalCost += lineTotal;
          lineMaps.add(
            StockReceiptLine(
              stockItemId: line.stockItemId,
              itemNameSnapshot: name,
              quantity: line.quantity,
              unitCost: line.unitCost,
              lineTotal: lineTotal,
              isMerchandiseSnapshot: isMerch,
            ).toMap(),
          );
        }

        final agg = <String, _QtyCostAgg>{};
        void addReceipt(String id, double q, double costSum) {
          final a = agg.putIfAbsent(id, () => _QtyCostAgg());
          a.qty += q;
          a.costSum += costSum;
        }

        for (final id in distinctIds) {
          final q = mergedQty[id]!;
          final cSum = mergedCostNumerator[id]!;
          addReceipt(id, q, cSum);
          final links = StockItem.parseLinkedStockItemIdsField(
            stockSnapshots[id]!.data()!['linkedStockItemIds'],
          );
          for (final L in links.toSet()) {
            if (L == id) continue;
            addReceipt(L, q, cSum);
          }
        }

        final primaryLineIds = distinctIds.toSet();
        String? mirroredFromPrimary(String targetId) {
          if (primaryLineIds.contains(targetId)) return null;
          for (final P in distinctIds) {
            final links = StockItem.parseLinkedStockItemIdsField(
              stockSnapshots[P]!.data()!['linkedStockItemIds'],
            );
            if (links.contains(targetId)) return P;
          }
          return null;
        }

        final invoiceSnap =
            invoiceNumber != null && invoiceNumber.trim().isNotEmpty
            ? invoiceNumber.trim()
            : null;

        for (final id in agg.keys) {
          allTouchedIds.add(id);
          final snap = stockSnapshots[id]!;
          final data = snap.data()!;
          final currentQty = parseFirestoreDouble(data['quantity']);
          final addQty = agg[id]!.qty;
          final costSum = agg[id]!.costSum;
          final newQty = currentQty + addQty;
          final avgUnitCost = addQty > 0 ? costSum / addQty : 0.0;
          final mirrorSrc = mirroredFromPrimary(id);
          final previousUnitCost = parseFirestoreDoubleOrNull(
            data['lastUnitCost'],
          );
          final itemName = data['name'] as String? ?? '';

          final stockRef = stockCol.doc(id);
          transaction.update(stockRef, {
            'quantity': newQty,
            'lastUpdated': FieldValue.serverTimestamp(),
            'lastUnitCost': avgUnitCost,
            'updatedById': ?createdById,
            'updatedByName': ?createdByName,
          });

          StockCostService.logCostChangeInTransaction(
            transaction,
            stockRef: stockRef,
            previousUnitCost: previousUnitCost,
            newUnitCost: avgUnitCost,
            source: StockCostService.sourceVendorReceipt,
            receiptId: receiptId,
            vendorId: vendorId,
            invoiceNumber: invoiceSnap,
            quantityReceived: addQty,
            updatedById: createdById,
            updatedByName: createdByName,
            itemNameSnapshot: itemName,
          );

          final historyRef = stockRef.collection('history').doc();
          transaction.set(historyRef, {
            'timestamp': FieldValue.serverTimestamp(),
            'previousQuantity': currentQty,
            'newQuantity': newQty,
            'adjustment': addQty,
            'reason': reasonStr,
            'receiptId': receiptId,
            'vendorId': vendorId,
            'unitCost': avgUnitCost,
            'mirroredFromStockItemId': ?mirrorSrc,
            'updatedById': ?createdById,
            'updatedByName': ?createdByName,
          });
        }

        transaction.set(
          receiptRef,
          {
            'vendorId': vendorId,
            'vendorNameSnapshot': vendorNameSnapshot,
            'receivedAt': Timestamp.fromDate(receivedAt),
            'invoiceNumber': invoiceNumber?.trim(),
            'reference': reference?.trim(),
            'notes': notes?.trim(),
            'lines': lineMaps,
            'lineCount': lines.length,
            'totalCost': totalCost,
            'createdById': createdById,
            'createdByName': createdByName,
            'createdAt': FieldValue.serverTimestamp(),
          }..removeWhere((k, v) => v == null),
        );
      });
    } catch (e, st) {
      AppLogger.error(
        'commitReceipt failed vendorId=$vendorId invoice=${invoiceNumber ?? ''}',
        tag: 'StockReceipt',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    AppLogger.success(
      'Receipt $receiptId: ${lines.length} lines, ${allTouchedIds.length} stock docs',
      tag: 'StockReceipt',
    );

    for (final id in allTouchedIds) {
      StockHelper.invalidateCache(id);
    }

    return receiptId;
  }
}
