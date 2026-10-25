import 'credit_transaction.dart';

class CreditTransactionWithCustomer {
  final CreditTransaction transaction;
  final String customerId;
  final String customerName;
  final String? phoneNumber;
  final String? membershipId;

  CreditTransactionWithCustomer({
    required this.transaction,
    required this.customerId,
    required this.customerName,
    this.phoneNumber,
    this.membershipId,
  });
}
