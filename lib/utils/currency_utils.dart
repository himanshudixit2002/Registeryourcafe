class CurrencyUtils {
  CurrencyUtils._();

  static const String rupeeSymbol = '₹';

  static String format(double amount, {int decimalPlaces = 2}) {
    if (amount.isNaN || amount.isInfinite) return '0.00';

    final formatted = amount.toStringAsFixed(decimalPlaces);
    final parts = formatted.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';

    final buffer = StringBuffer();
    final length = intPart.length;

    for (int i = 0; i < length; i++) {
      if (i > 0) {
        final fromRight = length - i;
        if (fromRight == 3 || (fromRight > 3 && (fromRight - 3) % 2 == 0)) {
          buffer.write(',');
        }
      }
      buffer.write(intPart[i]);
    }

    return '${buffer.toString()}.$decPart';
  }

  static String formatWithSymbol(double amount, {int decimalPlaces = 2}) {
    return '$rupeeSymbol${format(amount, decimalPlaces: decimalPlaces)}';
  }

  static String formatCompact(double amount) {
    if (amount.isNaN || amount.isInfinite) return '₹0';

    if (amount.abs() >= 10000000) {
      return '$rupeeSymbol${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount.abs() >= 100000) {
      return '$rupeeSymbol${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount.abs() >= 1000) {
      return '$rupeeSymbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return formatWithSymbol(amount, decimalPlaces: 0);
  }

  static double round(double amount, {int decimalPlaces = 2}) {
    if (amount.isNaN || amount.isInfinite) return 0.0;
    return double.parse(amount.toStringAsFixed(decimalPlaces));
  }

  static double percentage(double amount, double total) {
    if (total == 0 || total.isNaN || total.isInfinite) return 0.0;
    return round((amount / total) * 100);
  }

  static String formatPercentage(double percent, {int decimalPlaces = 1}) {
    return '${percent.toStringAsFixed(decimalPlaces)}%';
  }

  static double calculateDiscount(double amount, double discountPercent) {
    return round(amount * (discountPercent / 100));
  }

  static double applyDiscount(double amount, double discountPercent) {
    return round(amount - calculateDiscount(amount, discountPercent));
  }

  static String formatWithSign(double amount, {int decimalPlaces = 2}) {
    final formatted = format(amount.abs(), decimalPlaces: decimalPlaces);
    if (amount > 0) return '+$rupeeSymbol$formatted';
    if (amount < 0) return '-$rupeeSymbol$formatted';
    return '$rupeeSymbol$formatted';
  }

  static bool equals(double a, double b, {double tolerance = 0.001}) {
    return (a - b).abs() < tolerance;
  }
}

extension CurrencyExtension on double {
  String toCurrency({int decimalPlaces = 2}) =>
      CurrencyUtils.format(this, decimalPlaces: decimalPlaces);
  String toRupees({int decimalPlaces = 2}) =>
      CurrencyUtils.formatWithSymbol(this, decimalPlaces: decimalPlaces);
  String toCompactRupees() => CurrencyUtils.formatCompact(this);
  double roundToCurrency({int decimalPlaces = 2}) =>
      CurrencyUtils.round(this, decimalPlaces: decimalPlaces);
}
