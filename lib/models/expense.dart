import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

enum ExpenseCategory {
  rent,
  utilities,
  salaries,
  supplies,
  maintenance,
  marketing,
  equipment,
  other;

  static ExpenseCategory parse(String? value) {
    if (value == null) return ExpenseCategory.other;
    for (final c in ExpenseCategory.values) {
      if (c.name == value) return c;
    }
    return ExpenseCategory.other;
  }

  String get label {
    switch (this) {
      case ExpenseCategory.rent:
        return 'Rent';
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.salaries:
        return 'Salaries';
      case ExpenseCategory.supplies:
        return 'Supplies';
      case ExpenseCategory.maintenance:
        return 'Maintenance';
      case ExpenseCategory.marketing:
        return 'Marketing';
      case ExpenseCategory.equipment:
        return 'Equipment';
      case ExpenseCategory.other:
        return 'Other';
    }
  }
}

class Expense {
  final String id;
  final ExpenseCategory category;
  final double amount;
  final DateTime date;
  final String description;
  final String? vendorName;
  final String createdBy;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.description,
    this.vendorName,
    required this.createdBy,
    required this.createdAt,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Expense(
      id: doc.id,
      category: ExpenseCategory.parse(data['category'] as String?),
      amount: parseFirestoreDouble(data['amount']),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'] as String? ?? '',
      vendorName: data['vendorName'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category.name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'description': description,
      if (vendorName != null) 'vendorName': vendorName,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
