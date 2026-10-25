import 'package:registeryourcafe/models/sales_transaction.dart';
import 'package:registeryourcafe/utils/firestore_utils.dart';

TransactionItem transactionItemFromRefundRow(dynamic it) {
  final row = Map<String, dynamic>.from(it as Map);
  return TransactionItem(
    name: '${row['name'] ?? ''}',
    quantity: parseFirestoreInt(row['quantity'], fallback: 0),
    price: parseFirestoreDouble(row['price']),
  );
}

String refundItemDescriptionPart(dynamic it) {
  final row = Map<String, dynamic>.from(it as Map);
  return '${row['name'] ?? ''} (x${parseFirestoreInt(row['quantity'], fallback: 0)})';
}
