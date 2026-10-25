import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/expense.dart';

class ExpenseService {
  final TenantRef _tenant;

  ExpenseService(this._tenant);

  CollectionReference<Map<String, dynamic>> _col() =>
      _tenant.companyDoc().collection('expenses');

  Stream<List<Expense>> watchExpenses({int limit = 100}) {
    return _col()
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromFirestore).toList());
  }

  Future<void> addExpense(Expense expense) async {
    await _col().add(expense.toFirestore());
  }

  Future<void> deleteExpense(String id) async {
    await _col().doc(id).delete();
  }

  Future<double> getTotalExpenses({
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _col()
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    double total = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      total += (data['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }
}
