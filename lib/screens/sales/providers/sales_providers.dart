import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/sales_transaction.dart';
import '../../../providers/tenant_provider.dart';
import '../services/sales_data_service.dart';

final salesDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  // Helper functions to keep the default range inclusive.
  DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  return DateTimeRange(
    start: startOfDay(now.subtract(const Duration(days: 7))),
    end: endOfDay(now),
  );
});

final salesRevenueTypeProvider = StateProvider<String>((ref) => 'all');
final salesPaymentMethodProvider = StateProvider<String>((ref) => 'all');

final salesDataServiceProvider = Provider((ref) {
  final tenant = ref.watch(tenantRefProvider)!;
  return SalesDataService(tenant);
});

final salesDataSummaryProvider = StreamProvider<SalesDataSummary>((ref) {
  final salesService = ref.watch(salesDataServiceProvider);
  final dateRange = ref.watch(salesDateRangeProvider);
  final revenueType = ref.watch(salesRevenueTypeProvider);
  final paymentMethod = ref.watch(salesPaymentMethodProvider);

  return salesService.getSalesDataWithCredits(
    dateRange: dateRange,
    revenueType: revenueType,
    paymentMethod: paymentMethod,
  );
});
