import 'dart:math' as math;
import '../utils/calculation_utils.dart';

class RefundCalculationHelper {
  RefundCalculationHelper._();

  static RefundAllocation calculateRefundAllocation({
    required double refundAmount,
    required double creditsUsed,
    required double originalTotal,
    required bool refundRemainderToCredits,
    bool isActiveSession = false,
  }) {
    if (isActiveSession) {
      return RefundAllocation(
        creditsToRefund: 0.0,
        nonCreditToRefund: 0.0,
        creditsRefundedFinal: 0.0,
      );
    }

    double creditsToRefund = 0.0;
    double nonCreditToRefund = refundAmount;

    if (creditsUsed > 0) {
      if (refundAmount >= creditsUsed) {
        creditsToRefund = creditsUsed;
      } else if (originalTotal > 0) {
        final proportion = CalculationUtils.safeDivide(
          refundAmount,
          originalTotal,
        );
        creditsToRefund = CalculationUtils.roundCurrency(
          creditsUsed * proportion,
        );
        creditsToRefund = math.min(creditsToRefund, creditsUsed);
      } else {
        creditsToRefund = math.min(refundAmount, creditsUsed);
      }
      nonCreditToRefund = CalculationUtils.roundCurrency(
        refundAmount - creditsToRefund,
      );
    }

    double creditsRefundedFinal = creditsToRefund;
    if (refundRemainderToCredits && nonCreditToRefund > 0) {
      creditsRefundedFinal = CalculationUtils.roundCurrency(
        creditsToRefund + nonCreditToRefund,
      );
      nonCreditToRefund = 0.0;
    }

    return RefundAllocation(
      creditsToRefund: creditsToRefund,
      nonCreditToRefund: nonCreditToRefund,
      creditsRefundedFinal: creditsRefundedFinal,
    );
  }

  static RefundPaymentResult buildRefundPaymentBreakdown({
    required double nonCreditToRefund,
    required Map<String, double> originalPaymentBreakdown,
    String? fallbackPaymentMethod,
    bool useAlternativeMethod = false,
    String? alternativeMethod,
  }) {
    if (nonCreditToRefund <= 0) {
      return const RefundPaymentResult(
        refundPaymentBreakdown: null,
        originalPaymentBreakdown: null,
      );
    }

    final nonCreditKeys = originalPaymentBreakdown.keys
        .where((k) => k.toLowerCase() != 'credits')
        .toList();

    Map<String, dynamic>? originalPaymentBreakdownResult;
    Map<String, double> refundBreakdown;

    if (nonCreditKeys.isNotEmpty) {
      final nonCreditOriginalTotal = nonCreditKeys.fold<double>(
        0.0,
        (sum, k) => sum + (originalPaymentBreakdown[k] ?? 0.0),
      );

      if (nonCreditOriginalTotal > 0) {
        final itemValues = <String, double>{};
        for (final k in nonCreditKeys) {
          itemValues[k] = originalPaymentBreakdown[k] ?? 0.0;
        }
        refundBreakdown = CalculationUtils.distributeProportionally(
          amountToDistribute: nonCreditToRefund,
          itemValues: itemValues,
        );
      } else {
        refundBreakdown = {fallbackPaymentMethod ?? 'cash': nonCreditToRefund};
      }
    } else {
      refundBreakdown = {fallbackPaymentMethod ?? 'cash': nonCreditToRefund};
    }

    if (useAlternativeMethod && alternativeMethod != null) {
      originalPaymentBreakdownResult = Map<String, dynamic>.from(
        refundBreakdown,
      );
      refundBreakdown = {alternativeMethod: nonCreditToRefund};
    }

    return RefundPaymentResult(
      refundPaymentBreakdown: refundBreakdown,
      originalPaymentBreakdown: originalPaymentBreakdownResult,
    );
  }

  static RefundOrderTotals calculateNewOrderTotals({
    required double originalTotal,
    required double originalCreditsUsed,
    required double refundAmount,
    required double creditsToRefund,
  }) {
    final newTotal = CalculationUtils.roundCurrency(
      originalTotal - refundAmount,
    );
    final newCreditsUsed = CalculationUtils.clampPositive(
      CalculationUtils.roundCurrency(originalCreditsUsed - creditsToRefund),
      max: newTotal > 0 ? newTotal : 0,
    );
    return RefundOrderTotals(
      newTotal: newTotal,
      newCreditsUsed: newCreditsUsed,
    );
  }

  static String determineFallbackPaymentMethod({
    String? orderPaymentMethod,
    String? sessionPaymentMode,
  }) {
    if (orderPaymentMethod != null &&
        orderPaymentMethod.toLowerCase() != 'credits') {
      return orderPaymentMethod;
    }
    return sessionPaymentMode ?? 'cash';
  }
}

class RefundAllocation {
  final double creditsToRefund;
  final double nonCreditToRefund;
  final double creditsRefundedFinal;

  const RefundAllocation({
    required this.creditsToRefund,
    required this.nonCreditToRefund,
    required this.creditsRefundedFinal,
  });
}

class RefundPaymentResult {
  final Map<String, double>? refundPaymentBreakdown;
  final Map<String, dynamic>? originalPaymentBreakdown;

  const RefundPaymentResult({
    this.refundPaymentBreakdown,
    this.originalPaymentBreakdown,
  });
}

class RefundOrderTotals {
  final double newTotal;
  final double newCreditsUsed;

  const RefundOrderTotals({
    required this.newTotal,
    required this.newCreditsUsed,
  });
}
