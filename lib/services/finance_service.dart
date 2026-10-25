import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/finance.dart';

class FinanceService {
  final TenantRef _tenant;
  FinanceService(this._tenant);

  CollectionReference<Map<String, dynamic>> _cashRegister() =>
      _tenant.companyDoc().collection('cashRegister');
  CollectionReference<Map<String, dynamic>> _pettyCash() =>
      _tenant.companyDoc().collection('pettyCash');
  CollectionReference<Map<String, dynamic>> _budgets() =>
      _tenant.companyDoc().collection('budgets');
  CollectionReference<Map<String, dynamic>> _vendorPayments() =>
      _tenant.companyDoc().collection('vendorPayments');

  Future<void> addCashRegisterEntry(CashRegisterEntry entry) async =>
      await _cashRegister().add(entry.toFirestore());

  Stream<List<CashRegisterEntry>> watchCashRegister({int limit = 50}) =>
      _cashRegister()
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(CashRegisterEntry.fromFirestore).toList());

  Future<void> addPettyCash(PettyCashEntry entry) async =>
      await _pettyCash().add(entry.toFirestore());

  Stream<List<PettyCashEntry>> watchPettyCash({int limit = 50}) => _pettyCash()
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(PettyCashEntry.fromFirestore).toList());

  Future<void> saveBudget(BudgetEntry entry) async =>
      await _budgets().add(entry.toFirestore());

  Stream<List<BudgetEntry>> watchBudgets() => _budgets()
      .snapshots()
      .map((s) => s.docs.map(BudgetEntry.fromFirestore).toList());

  Future<void> addVendorPayment(VendorPayment payment) async =>
      await _vendorPayments().add(payment.toFirestore());

  Stream<List<VendorPayment>> watchVendorPayments({int limit = 100}) =>
      _vendorPayments()
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(VendorPayment.fromFirestore).toList());
}
