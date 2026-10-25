import 'package:cloud_firestore/cloud_firestore.dart';

class CashRegisterEntry {
  final String id;
  final String type;
  final double openingBalance;
  final double closingBalance;
  final double cashIn;
  final double cashOut;
  final String staffName;
  final DateTime date;

  const CashRegisterEntry({
    required this.id,
    required this.type,
    required this.openingBalance,
    required this.closingBalance,
    required this.cashIn,
    required this.cashOut,
    required this.staffName,
    required this.date,
  });

  factory CashRegisterEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CashRegisterEntry(
      id: doc.id,
      type: d['type'] as String? ?? 'close',
      openingBalance: (d['openingBalance'] as num?)?.toDouble() ?? 0,
      closingBalance: (d['closingBalance'] as num?)?.toDouble() ?? 0,
      cashIn: (d['cashIn'] as num?)?.toDouble() ?? 0,
      cashOut: (d['cashOut'] as num?)?.toDouble() ?? 0,
      staffName: d['staffName'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'openingBalance': openingBalance,
        'closingBalance': closingBalance,
        'cashIn': cashIn,
        'cashOut': cashOut,
        'staffName': staffName,
        'date': Timestamp.fromDate(date),
      };
}

class PettyCashEntry {
  final String id;
  final double amount;
  final String description;
  final String approvedBy;
  final DateTime date;

  const PettyCashEntry({
    required this.id,
    required this.amount,
    required this.description,
    required this.approvedBy,
    required this.date,
  });

  factory PettyCashEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return PettyCashEntry(
      id: doc.id,
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      description: d['description'] as String? ?? '',
      approvedBy: d['approvedBy'] as String? ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'amount': amount,
        'description': description,
        'approvedBy': approvedBy,
        'date': Timestamp.fromDate(date),
      };
}

class BudgetEntry {
  final String id;
  final String category;
  final double planned;
  final double actual;
  final String period;

  const BudgetEntry({
    required this.id,
    required this.category,
    required this.planned,
    this.actual = 0,
    required this.period,
  });

  factory BudgetEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return BudgetEntry(
      id: doc.id,
      category: d['category'] as String? ?? '',
      planned: (d['planned'] as num?)?.toDouble() ?? 0,
      actual: (d['actual'] as num?)?.toDouble() ?? 0,
      period: d['period'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'category': category,
        'planned': planned,
        'actual': actual,
        'period': period,
      };
}

class VendorPayment {
  final String id;
  final String vendorId;
  final String vendorName;
  final double amount;
  final String method;
  final String? reference;
  final DateTime date;

  const VendorPayment({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.amount,
    required this.method,
    this.reference,
    required this.date,
  });

  factory VendorPayment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return VendorPayment(
      id: doc.id,
      vendorId: d['vendorId'] as String? ?? '',
      vendorName: d['vendorName'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      method: d['method'] as String? ?? 'cash',
      reference: d['reference'] as String?,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'vendorId': vendorId,
        'vendorName': vendorName,
        'amount': amount,
        'method': method,
        if (reference != null) 'reference': reference,
        'date': Timestamp.fromDate(date),
      };
}
