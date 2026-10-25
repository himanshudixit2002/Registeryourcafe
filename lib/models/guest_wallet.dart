import 'package:cloud_firestore/cloud_firestore.dart';

class GuestWallet {
  final String uid;
  final double balance;
  final List<WalletTransaction> transactions;

  const GuestWallet({
    required this.uid,
    this.balance = 0,
    this.transactions = const [],
  });

  factory GuestWallet.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GuestWallet(
      uid: doc.id,
      balance: (d['balance'] as num?)?.toDouble() ?? 0,
      transactions: (d['transactions'] as List?)
              ?.map((e) =>
                  WalletTransaction.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class WalletTransaction {
  final String type;
  final double amount;
  final String description;
  final DateTime date;

  const WalletTransaction({
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> m) =>
      WalletTransaction(
        type: m['type'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        description: m['description'] as String? ?? '',
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
    'type': type,
    'amount': amount,
    'description': description,
    'date': Timestamp.fromDate(date),
  };
}
