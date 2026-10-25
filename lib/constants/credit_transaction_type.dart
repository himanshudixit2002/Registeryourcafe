enum CreditTransactionType {
  initialBalance,
  manualTopUp,
  membership,
  debit,
  credit,
  refund,
  sessionPayment,
  orderPayment,
}

extension CreditTransactionTypeExtension on CreditTransactionType {
  String get displayName {
    switch (this) {
      case CreditTransactionType.initialBalance:
        return 'Initial Balance';
      case CreditTransactionType.manualTopUp:
        return 'Manual Top-up';
      case CreditTransactionType.membership:
        return 'Membership';
      case CreditTransactionType.debit:
        return 'Debit';
      case CreditTransactionType.credit:
        return 'Credit';
      case CreditTransactionType.refund:
        return 'Refund';
      case CreditTransactionType.sessionPayment:
        return 'Session Payment';
      case CreditTransactionType.orderPayment:
        return 'Order Payment';
    }
  }

  String get storageValue => name;

  static CreditTransactionType fromStorageValue(String? value) {
    if (value == null || value.isEmpty) {
      return CreditTransactionType.manualTopUp;
    }

    final lowerValue = value.toLowerCase();
    switch (lowerValue) {
      case 'initialbalance':
        return CreditTransactionType.initialBalance;
      case 'manualtopup':
        return CreditTransactionType.manualTopUp;
      case 'sessionpayment':
        return CreditTransactionType.sessionPayment;
      case 'orderpayment':
        return CreditTransactionType.orderPayment;
    }

    return CreditTransactionType.values.firstWhere(
      (e) => e.name.toLowerCase() == lowerValue,
      orElse: () => CreditTransactionType.manualTopUp,
    );
  }

  bool get isDebit =>
      this == CreditTransactionType.debit ||
      this == CreditTransactionType.sessionPayment ||
      this == CreditTransactionType.orderPayment;

  bool get isCredit => !isDebit;
  int get signMultiplier => isDebit ? -1 : 1;
}
