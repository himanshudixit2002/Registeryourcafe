import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../services/expense_service.dart';
import 'tenant_provider.dart';

final expenseServiceProvider = Provider<ExpenseService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return ExpenseService(tenant);
});

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final service = ref.watch(expenseServiceProvider);
  if (service == null) return Stream.value([]);
  return service.watchExpenses();
});
