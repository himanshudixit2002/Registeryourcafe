import 'package:flutter/material.dart';

import '../models/sales_transaction.dart';
import 'app_theme.dart';

/// Themed accent colors for sales transaction types, revenue buckets, and charts.
abstract final class SalesPalette {
  SalesPalette._();

  static Color transactionType(BuildContext context, TransactionType type) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (type) {
      case TransactionType.session:
        return cs.primary;
      case TransactionType.cafe:
        return sem.success;
      case TransactionType.merchandise:
        return sem.warning;
      case TransactionType.tournamentRegistration:
        return cs.tertiary;
      case TransactionType.credit:
        return cs.secondary;
    }
  }

  /// Keys from [SalesDataSummary.revenueByType] and summary card row labels.
  static Color revenueKey(BuildContext context, String key) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (key) {
      case 'Table Charges':
      case 'Table':
        return cs.primary;
      case 'Cafe':
        return sem.success;
      case 'Merchandise':
      case 'Merch':
        return sem.warning;
      case 'Tournament':
        return cs.tertiary;
      case 'Credit Top-up':
      case 'Credit':
        return cs.secondary;
      default:
        return cs.outline;
    }
  }

  static Color paymentMethod(BuildContext context, String key) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (key) {
      case 'cash':
        return sem.success;
      case 'upi':
        return sem.info;
      case 'credit':
        return sem.warning;
      default:
        return cs.outline;
    }
  }

  /// Readable label color on top of a saturated chart slice.
  static Color onChartSlice(BuildContext context, Color slice) {
    final cs = Theme.of(context).colorScheme;
    return ThemeData.estimateBrightnessForColor(slice) == Brightness.dark
        ? cs.surfaceContainerLowest
        : cs.onSurface;
  }
}
