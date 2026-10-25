enum PaymentMode { cash, credit, upi }

extension PaymentModeExtension on PaymentMode {
  String get displayName {
    switch (this) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.credit:
        return 'Credits';
      case PaymentMode.upi:
        return 'UPI';
    }
  }

  String get storageValue => name.toLowerCase();

  static PaymentMode fromStorageValue(String? value) {
    if (value == null || value.isEmpty) return PaymentMode.cash;
    return PaymentMode.values.firstWhere(
      (e) => e.storageValue == value.toLowerCase(),
      orElse: () => PaymentMode.cash,
    );
  }

  bool get isCredits => this == PaymentMode.credit;
  bool get isDirectPayment =>
      this == PaymentMode.cash || this == PaymentMode.upi;
}

enum PaymentMethod { cash, upi, credits }

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.credits:
        return 'Credits';
    }
  }

  String get storageValue => name.toLowerCase();

  static PaymentMethod fromStorageValue(String? value) {
    if (value == null || value.isEmpty) return PaymentMethod.cash;
    return PaymentMethod.values.firstWhere(
      (e) => e.storageValue == value.toLowerCase(),
      orElse: () => PaymentMethod.cash,
    );
  }

  bool get isCredits => this == PaymentMethod.credits;
}
