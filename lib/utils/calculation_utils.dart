import 'dart:math' as math;

class CalculationUtils {
  CalculationUtils._();

  /// Rounds to 2 decimal places.
  static double roundCurrency(double amount) {
    if (amount.isNaN || amount.isInfinite) return 0.0;
    return (amount * 100).round() / 100;
  }

  /// Safe division with fallback.
  static double safeDivide(
    double numerator,
    double denominator, {
    double fallback = 0.0,
  }) {
    if (denominator == 0 || denominator.isNaN || denominator.isInfinite) {
      return fallback;
    }
    if (numerator.isNaN || numerator.isInfinite) return fallback;
    return numerator / denominator;
  }

  /// Percentage of total.
  static double percentage(double part, double total) {
    return safeDivide(part, total) * 100;
  }

  /// Calculate percentage of amount.
  static double percentageOf(double amount, double percent) {
    if (amount.isNaN || percent.isNaN) return 0.0;
    return roundCurrency(amount * (percent / 100));
  }

  /// Apply discount percentage.
  static double applyDiscount(double amount, double discountPercent) {
    return roundCurrency(amount - percentageOf(amount, discountPercent));
  }

  /// Clamp to non-negative.
  static double clampPositive(double value, {double min = 0.0, double? max}) {
    if (value.isNaN || value.isInfinite) return min;
    final clamped = value < min ? min : value;
    if (max != null && clamped > max) return max;
    return clamped;
  }

  /// Distribute amount proportionally across items.
  static Map<String, double> distributeProportionally({
    required double amountToDistribute,
    required Map<String, double> itemValues,
  }) {
    if (itemValues.isEmpty) return {};

    final total = itemValues.values.fold(0.0, (sum, v) => sum + v);
    if (total <= 0) return {};

    final result = <String, double>{};
    double distributed = 0.0;
    final entries = itemValues.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (i == entries.length - 1) {
        result[entry.key] = roundCurrency(amountToDistribute - distributed);
      } else {
        final share = roundCurrency(
          amountToDistribute * safeDivide(entry.value, total),
        );
        result[entry.key] = share;
        distributed += share;
      }
    }

    return result;
  }

  /// Calculate billable hours with minimum.
  static double calculateBillableHours({
    required DateTime startTime,
    DateTime? endTime,
    int minimumBillableMinutes = 0,
  }) {
    final end = endTime ?? DateTime.now();
    final durationMinutes = end.difference(startTime).inMinutes;
    final effectiveMinutes = durationMinutes < minimumBillableMinutes
        ? minimumBillableMinutes
        : durationMinutes;
    return effectiveMinutes / 60.0;
  }

  /// Calculate table charges.
  static double calculateTableCharges({
    required double hours,
    required double hourlyRate,
  }) {
    return roundCurrency(hours * hourlyRate);
  }

  /// Calculate usable credits.
  static double calculateCreditsToUse({
    required double requestedCredits,
    required double availableCredits,
    required double maxAmount,
  }) {
    if (requestedCredits <= 0 || availableCredits <= 0) return 0.0;
    double usable = math.min(requestedCredits, availableCredits);
    usable = math.min(usable, maxAmount);
    return roundCurrency(usable);
  }

  /// Calculate proportional credits refund.
  static double calculateProportionalCreditsRefund({
    required double refundAmount,
    required double originalTotal,
    required double creditsUsed,
  }) {
    if (creditsUsed <= 0 || originalTotal <= 0) return 0.0;
    final proportion = safeDivide(refundAmount, originalTotal);
    return roundCurrency(math.min(creditsUsed * proportion, creditsUsed));
  }

  /// Sum values safely.
  static double sum(Iterable<double> values) {
    return roundCurrency(values.fold(0.0, (sum, v) => sum + (v.isNaN ? 0 : v)));
  }

  /// Check currency equality.
  static bool currencyEquals(double a, double b) {
    return (roundCurrency(a) - roundCurrency(b)).abs() < 0.005;
  }
}

extension NumCalculationExtension on num {
  double toCurrencyPrecision() => CalculationUtils.roundCurrency(toDouble());
  double toPositive() => CalculationUtils.clampPositive(toDouble());
  double percentOf(num value) =>
      CalculationUtils.percentageOf(value.toDouble(), toDouble());
}
