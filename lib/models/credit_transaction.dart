import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer.dart';
import '../utils/firestore_utils.dart';

enum CreditTransactionType {
  initialBalance,
  manualTopUp,
  membership,
  debit,
  credit,
  loyaltyConversion,
}

class CreditTransaction {
  final String id;
  final DateTime date;
  final double amount;
  final PaymentMethod paymentMethod;
  final CreditTransactionType type;
  final String? note;
  final String? performedById;
  final String? performedByName;
  final String? performedByRole;
  final Map<String, dynamic>? reference;

  CreditTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.paymentMethod,
    required this.type,
    this.note,
    this.performedById,
    this.performedByName,
    this.performedByRole,
    this.reference,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'method': paymentMethod.name.toLowerCase(),
      'type': type.name,
      if (note != null) 'note': note,
      if (performedById != null) 'performedById': performedById,
      if (performedByName != null) 'performedByName': performedByName,
      if (performedByRole != null) 'performedByRole': performedByRole,
      if (reference != null) 'reference': reference,
    };
  }

  factory CreditTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawType = (data['type'] as String?)?.toLowerCase();
    CreditTransactionType parsedType;
    switch (rawType) {
      case 'debit':
        parsedType = CreditTransactionType.debit;
        break;
      case 'credit':
        parsedType = CreditTransactionType.credit;
        break;
      case 'initialbalance':
        parsedType = CreditTransactionType.initialBalance;
        break;
      case 'manualtopup':
        parsedType = CreditTransactionType.manualTopUp;
        break;
      case 'membership':
        parsedType = CreditTransactionType.membership;
        break;
      case 'loyaltyconversion':
        parsedType = CreditTransactionType.loyaltyConversion;
        break;
      default:
        parsedType =
            (CreditTransactionType.values
                .where((e) => e.name.toLowerCase() == (rawType ?? ''))
                .toList()
                .isNotEmpty)
            ? CreditTransactionType.values.firstWhere(
                (e) => e.name.toLowerCase() == (rawType ?? ''),
              )
            : CreditTransactionType.manualTopUp;
    }

    return CreditTransaction(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      amount: parseFirestoreDouble(data['amount']),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name.toLowerCase() == (data['method'] as String).toLowerCase(),
        orElse: () => PaymentMethod.cash,
      ),
      type: parsedType,
      note: data['note'] as String?,
      performedById:
          data['performedById'] as String? ?? data['performedBy'] as String?,
      performedByName: data['performedByName'] as String?,
      performedByRole: data['performedByRole'] as String?,
      reference: data['reference'] as Map<String, dynamic>?,
    );
  }
}
