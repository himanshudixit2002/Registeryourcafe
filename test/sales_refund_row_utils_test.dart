import 'package:flutter_test/flutter_test.dart';
import 'package:registeryourcafe/models/sales_transaction.dart';
import 'package:registeryourcafe/screens/sales/services/sales_refund_row_utils.dart';

void main() {
  group('transactionItemFromRefundRow', () {
    test('maps Firestore-like map to TransactionItem', () {
      final item = transactionItemFromRefundRow(<String, dynamic>{
        'name': 'Latte',
        'quantity': 2,
        'price': 120.5,
      });
      expect(item, isA<TransactionItem>());
      expect(item.name, 'Latte');
      expect(item.quantity, 2);
      expect(item.price, 120.5);
    });

    test('uses defaults for missing fields', () {
      final item = transactionItemFromRefundRow(<String, dynamic>{});
      expect(item.name, '');
      expect(item.quantity, 0);
      expect(item.price, 0.0);
    });
  });

  group('refundItemDescriptionPart', () {
    test('formats name and quantity', () {
      final part = refundItemDescriptionPart(<String, dynamic>{
        'name': 'Muffin',
        'quantity': 3,
      });
      expect(part, 'Muffin (x3)');
    });

    test('handles empty name', () {
      final part = refundItemDescriptionPart(<String, dynamic>{
        'quantity': 1,
      });
      expect(part, ' (x1)');
    });
  });
}
