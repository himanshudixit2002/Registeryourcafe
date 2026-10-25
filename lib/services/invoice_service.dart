import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/invoice.dart';
import '../models/tax_config.dart';

class InvoiceService {
  final TenantRef _tenant;

  InvoiceService(this._tenant);

  CollectionReference<Map<String, dynamic>> _col() =>
      _tenant.companyDoc().collection('invoices');

  Future<TaxConfig> getTaxConfig() async {
    final doc = await _tenant.companyDoc().get();
    final data = doc.data();
    return TaxConfig.fromMap(data?['taxConfig'] as Map<String, dynamic>?);
  }

  Future<void> saveTaxConfig(TaxConfig config) async {
    await _tenant.companyDoc().set({
      'taxConfig': config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int> _nextInvoiceNumber() async {
    final counterRef =
        _tenant.companyDoc().collection('counters').doc('invoice');
    final result = await _tenant.db.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      final current = (snap.data()?['value'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      tx.set(counterRef, {'value': next});
      return next;
    });
    return result;
  }

  Future<Invoice> createInvoice({
    required double subtotal,
    required TaxConfig taxConfig,
    String? customerName,
    String? sessionId,
    required String createdBy,
  }) async {
    final taxAmount = taxConfig.calculateTax(subtotal);
    final total = subtotal + taxAmount;
    final number = await _nextInvoiceNumber();
    final invoice = Invoice(
      id: '',
      invoiceNumber: number,
      prefix: taxConfig.invoicePrefix,
      subtotal: subtotal,
      taxAmount: taxAmount,
      taxRate: taxConfig.taxRate,
      taxLabel: taxConfig.taxLabel,
      total: total,
      customerName: customerName,
      sessionId: sessionId,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    final ref = await _col().add(invoice.toFirestore());
    return Invoice(
      id: ref.id,
      invoiceNumber: invoice.invoiceNumber,
      prefix: invoice.prefix,
      subtotal: invoice.subtotal,
      taxAmount: invoice.taxAmount,
      taxRate: invoice.taxRate,
      taxLabel: invoice.taxLabel,
      total: invoice.total,
      customerName: invoice.customerName,
      sessionId: invoice.sessionId,
      createdAt: invoice.createdAt,
      createdBy: invoice.createdBy,
    );
  }

  Stream<List<Invoice>> watchInvoices({int limit = 100}) {
    return _col()
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Invoice.fromFirestore).toList());
  }
}
