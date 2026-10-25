class PaymentUtils {
  PaymentUtils._();

  static Map<String, double> calculateRefundAllocation({
    required double refundAmount,
    required double originalTotal,
    required double creditsUsed,
    bool refundRemainderToCredits = false,
  }) {
    double creditsToRefund = 0.0;
    double nonCreditToRefund = refundAmount;

    if (creditsUsed > 0) {
      final proportion = refundAmount / originalTotal;
      final provisionalCredits = (creditsUsed * proportion).clamp(
        0.0,
        creditsUsed,
      );
      creditsToRefund = double.parse(provisionalCredits.toStringAsFixed(2));
      nonCreditToRefund = refundAmount - creditsToRefund;
    }

    double finalCreditsRefunded = creditsToRefund;
    if (refundRemainderToCredits && nonCreditToRefund > 0) {
      finalCreditsRefunded += nonCreditToRefund;
      nonCreditToRefund = 0.0;
    }

    return {
      'creditsToRefund': finalCreditsRefunded,
      'nonCreditToRefund': nonCreditToRefund,
    };
  }

  static Map<String, double>? buildRefundPaymentBreakdown({
    required double nonCreditToRefund,
    required Map<String, double>? originalBreakdown,
    required String? fallbackPaymentMethod,
    String? sessionPaymentMode,
    bool useAlternativeMethod = false,
    String? alternativeMethod,
  }) {
    if (nonCreditToRefund <= 0) return null;

    Map<String, double> refundBreakdown = {};

    if (originalBreakdown != null && originalBreakdown.isNotEmpty) {
      final nonCreditKeys = originalBreakdown.keys
          .where((k) => k.toLowerCase() != 'credits')
          .toList();

      if (nonCreditKeys.isNotEmpty) {
        final double nonCreditOriginalTotal = nonCreditKeys.fold(
          0.0,
          (sum, k) => sum + (originalBreakdown[k] ?? 0.0),
        );

        if (nonCreditOriginalTotal > 0) {
          for (final k in nonCreditKeys) {
            final share =
                (originalBreakdown[k] ?? 0.0) / nonCreditOriginalTotal;
            refundBreakdown[k] = double.parse(
              (nonCreditToRefund * share).toStringAsFixed(2),
            );
          }

          if (useAlternativeMethod && alternativeMethod != null) {
            refundBreakdown = {alternativeMethod: nonCreditToRefund};
          }
          return refundBreakdown;
        }
      }
    }

    final key = fallbackPaymentMethod ?? sessionPaymentMode ?? 'cash';
    if (useAlternativeMethod && alternativeMethod != null) {
      return {alternativeMethod: nonCreditToRefund};
    }
    return {key: nonCreditToRefund};
  }

  static double calculateOrderCreditsUsed({
    required double orderTotal,
    required double totalFromAllOrders,
    required double totalCreditsDebited,
  }) {
    if (totalCreditsDebited <= 0 || totalFromAllOrders <= 0) return 0.0;
    return double.parse(
      ((orderTotal / totalFromAllOrders) * totalCreditsDebited).toStringAsFixed(
        2,
      ),
    );
  }

  static Map<String, double> buildOrderPaymentBreakdown({
    required double orderCreditsUsed,
    required double orderNonCreditPortion,
    required String paymentModeName,
  }) {
    final Map<String, double> breakdown = {};
    if (orderCreditsUsed > 0) breakdown['credits'] = orderCreditsUsed;
    if (orderNonCreditPortion > 0) {
      breakdown[paymentModeName] = orderNonCreditPortion;
    }
    return breakdown;
  }

  static double roundCurrency(double value) => (value * 100).round() / 100;

  static String formatCurrency(double value, {String symbol = '₹'}) {
    final formatted = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
    return '$symbol$formatted';
  }
}
