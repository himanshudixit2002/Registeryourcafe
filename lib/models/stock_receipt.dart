import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

/// Line as stored on a receipt document (audit trail).
class StockReceiptLine {
  final String stockItemId;
  final String itemNameSnapshot;
  final double quantity;
  final double unitCost;
  final double lineTotal;
  final bool isMerchandiseSnapshot;

  StockReceiptLine({
    required this.stockItemId,
    required this.itemNameSnapshot,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
    required this.isMerchandiseSnapshot,
  });

  Map<String, dynamic> toMap() {
    return {
      'stockItemId': stockItemId,
      'itemNameSnapshot': itemNameSnapshot,
      'quantity': quantity,
      'unitCost': unitCost,
      'lineTotal': lineTotal,
      'isMerchandiseSnapshot': isMerchandiseSnapshot,
    };
  }

  factory StockReceiptLine.fromMap(Map<String, dynamic> data) {
    return StockReceiptLine(
      stockItemId: data['stockItemId'] as String? ?? '',
      itemNameSnapshot: data['itemNameSnapshot'] as String? ?? '',
      quantity: parseFirestoreDouble(data['quantity']),
      unitCost: parseFirestoreDouble(data['unitCost']),
      lineTotal: parseFirestoreDouble(data['lineTotal']),
      isMerchandiseSnapshot: data['isMerchandiseSnapshot'] as bool? ?? false,
    );
  }
}

class StockReceipt {
  final String id;
  final String vendorId;
  final String? vendorNameSnapshot;
  final Timestamp receivedAt;
  final String? invoiceNumber;
  final String? reference;
  final String? notes;
  final List<StockReceiptLine> lines;
  final int lineCount;
  final double totalCost;
  final String? createdById;
  final String? createdByName;
  final Timestamp? createdAt;

  StockReceipt({
    required this.id,
    required this.vendorId,
    this.vendorNameSnapshot,
    required this.receivedAt,
    this.invoiceNumber,
    this.reference,
    this.notes,
    required this.lines,
    required this.lineCount,
    required this.totalCost,
    this.createdById,
    this.createdByName,
    this.createdAt,
  });

  factory StockReceipt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawLines = data['lines'] as List<dynamic>? ?? [];
    final lines = rawLines
        .map(
          (e) => StockReceiptLine.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return StockReceipt(
      id: doc.id,
      vendorId: data['vendorId'] as String? ?? '',
      vendorNameSnapshot: data['vendorNameSnapshot'] as String?,
      receivedAt: data['receivedAt'] is Timestamp
          ? data['receivedAt'] as Timestamp
          : Timestamp.now(),
      invoiceNumber: data['invoiceNumber'] as String?,
      reference: data['reference'] as String?,
      notes: data['notes'] as String?,
      lines: lines,
      lineCount: (data['lineCount'] as num?)?.toInt() ?? lines.length,
      totalCost: parseFirestoreDouble(data['totalCost']),
      createdById: data['createdById'] as String?,
      createdByName: data['createdByName'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

/// Input row when posting a vendor receipt from the UI.
class StockReceiptCommitLine {
  final String stockItemId;
  final double quantity;
  final double unitCost;

  const StockReceiptCommitLine({
    required this.stockItemId,
    required this.quantity,
    required this.unitCost,
  });
}
