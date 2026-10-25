import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/receipt.dart';

class ReceiptService {
  final TenantRef _tenant;

  ReceiptService(this._tenant);

  CollectionReference<Map<String, dynamic>> _col() =>
      _tenant.companyDoc().collection('receipts');

  Future<int> _nextReceiptNumber() async {
    final counterRef =
        _tenant.companyDoc().collection('counters').doc('receipt');
    final result = await _tenant.db.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      final current = (snap.data()?['value'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      tx.set(counterRef, {'value': next});
      return next;
    });
    return result;
  }

  Future<Receipt> createReceipt(Receipt receipt) async {
    final number = await _nextReceiptNumber();
    final withNumber = Receipt(
      id: '',
      receiptNumber: number,
      companyName: receipt.companyName,
      companyAddress: receipt.companyAddress,
      companyPhone: receipt.companyPhone,
      customerName: receipt.customerName,
      customerPhone: receipt.customerPhone,
      items: receipt.items,
      subtotal: receipt.subtotal,
      taxAmount: receipt.taxAmount,
      taxLabel: receipt.taxLabel,
      total: receipt.total,
      paymentMethod: receipt.paymentMethod,
      createdAt: receipt.createdAt,
      createdBy: receipt.createdBy,
    );
    final ref = await _col().add(withNumber.toFirestore());
    return Receipt(
      id: ref.id,
      receiptNumber: number,
      companyName: withNumber.companyName,
      companyAddress: withNumber.companyAddress,
      companyPhone: withNumber.companyPhone,
      customerName: withNumber.customerName,
      customerPhone: withNumber.customerPhone,
      items: withNumber.items,
      subtotal: withNumber.subtotal,
      taxAmount: withNumber.taxAmount,
      taxLabel: withNumber.taxLabel,
      total: withNumber.total,
      paymentMethod: withNumber.paymentMethod,
      createdAt: withNumber.createdAt,
      createdBy: withNumber.createdBy,
    );
  }

  Stream<List<Receipt>> watchReceipts({int limit = 100}) {
    return _col()
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Receipt.fromFirestore).toList());
  }
}
