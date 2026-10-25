import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../models/sales_transaction.dart';
import '../../../widgets/glass_panel.dart';

class BreakdownTableWidget extends StatelessWidget {
  final SalesDataSummary summary;
  const BreakdownTableWidget({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatCurrency = NumberFormat.simpleCurrency(
      locale: 'en_IN',
      decimalDigits: 0,
    );

    // Using pivot below; keep maps for future enhancements if needed.

    // We need to build a pivot table from the transaction list, as the summary maps are post-aggregation.
    final Map<String, Map<String, double>> pivotData = {};

    for (final tx in summary.transactions) {
      if (tx.type == TransactionType.session) {
        // Always include session components – values may be negative for refunds.
        _distribute(
          pivotData,
          'Table Charges',
          tx.tableCharges,
          tx.paidTotal,
          tx.creditsUsed,
          tx.paymentMethod,
          tx.total,
        );
        _distribute(
          pivotData,
          'Cafe',
          tx.cafeCharges,
          tx.paidTotal,
          tx.creditsUsed,
          tx.paymentMethod,
          tx.total,
        );
        _distribute(
          pivotData,
          'Merchandise',
          tx.merchandiseCharges,
          tx.paidTotal,
          tx.creditsUsed,
          tx.paymentMethod,
          tx.total,
        );
      } else if (tx.type == TransactionType.credit) {
        pivotData.putIfAbsent('Credit Top-up', () => {});
        pivotData['Credit Top-up']!.update(
          tx.paymentMethod,
          (v) => v + tx.paidTotal,
          ifAbsent: () => tx.paidTotal,
        );
      } else if (tx.type == TransactionType.tournamentRegistration) {
        // Tournament registration fees
        pivotData.putIfAbsent('Tournament', () => {});
        // Add non-credit paid portion (can be negative for refunds)
        if (tx.paidTotal != 0) {
          pivotData['Tournament']!.update(
            tx.paymentMethod,
            (v) => v + tx.paidTotal,
            ifAbsent: () => tx.paidTotal,
          );
        }
        // Add credits portion (positive or negative)
        if (tx.creditsUsed != 0) {
          pivotData['Tournament']!.update(
            'credit',
            (v) => v + tx.creditsUsed,
            ifAbsent: () => tx.creditsUsed,
          );
        }
      } else {
        final key = tx.type == TransactionType.cafe ? 'Cafe' : 'Merchandise';
        pivotData.putIfAbsent(key, () => {});
        // Add non-credit paid portion (can be negative for refunds)
        if (tx.paidTotal != 0) {
          pivotData[key]!.update(
            tx.paymentMethod,
            (v) => v + tx.paidTotal,
            ifAbsent: () => tx.paidTotal,
          );
        }
        // Add credits portion (positive or negative)
        if (tx.creditsUsed != 0) {
          pivotData[key]!.update(
            'credit',
            (v) => v + tx.creditsUsed,
            ifAbsent: () => tx.creditsUsed,
          );
        }
      }
    }

    // --- Build Rows ---
    final rows = <DataRow>[];
    final colTotals = <String, double>{'total': 0};

    pivotData.forEach((title, values) {
      double rowTotal = 0;
      final cells = <DataCell>[DataCell(Text(title))];

      final payOrder = ['cash', 'upi', 'credit'];
      for (final pMethod in payOrder) {
        final amount = values[pMethod] ?? 0.0;
        cells.add(DataCell(Text(formatCurrency.format(amount))));
        rowTotal += amount;
        colTotals.update(pMethod, (v) => v + amount, ifAbsent: () => amount);
      }
      cells.add(
        DataCell(
          Text(
            formatCurrency.format(rowTotal),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      colTotals.update('total', (v) => v + rowTotal, ifAbsent: () => rowTotal);

      rows.add(DataRow(cells: cells));
    });

    // Add totals row if there is data
    if (rows.isNotEmpty) {
      final totalCells = <DataCell>[
        const DataCell(
          Text('Totals', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ];
      final payOrder = ['cash', 'upi', 'credit', 'total'];
      for (final pMethod in payOrder) {
        totalCells.add(
          DataCell(
            Text(
              formatCurrency.format(colTotals[pMethod] ?? 0.0),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      rows.add(
        DataRow(
          color: WidgetStateProperty.all(
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ),
          cells: totalCells,
        ),
      );
    }

    return AppSurface(
      borderRadius: AppTheme.kBorderRadiusMedium,
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detailed Breakdown', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingMedium),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              columns: const [
                DataColumn(label: Text('Revenue Type')),
                DataColumn(label: Text('Cash')),
                DataColumn(label: Text('UPI')),
                DataColumn(label: Text('Credits')),
                DataColumn(label: Text('Total Value')),
              ],
              rows: rows,
            ),
          ),
        ],
      ),
    );
  }

  void _distribute(
    Map<String, Map<String, double>> data,
    String key,
    double componentValue,
    double paidTotal,
    double creditsUsed,
    String paymentMethod,
    double grossTotal,
  ) {
    if (componentValue == 0) return;

    data.putIfAbsent(key, () => {});

    if (grossTotal == 0) {
      // Fallback for zero gross: attribute the full component value to the respective payment buckets proportionally.
      final double nonCreditPortion = paidTotal;
      if (nonCreditPortion != 0) {
        data[key]!.update(
          paymentMethod,
          (v) => v + nonCreditPortion,
          ifAbsent: () => nonCreditPortion,
        );
      }
      if (creditsUsed != 0) {
        data[key]!.update(
          'credit',
          (v) => v + creditsUsed,
          ifAbsent: () => creditsUsed,
        );
      }
      return;
    }

    final double ratio = componentValue / grossTotal;

    // Distribute cash/upi payment
    if (paidTotal != 0) {
      final double portion = ratio * paidTotal;
      data[key]!.update(
        paymentMethod,
        (v) => v + portion,
        ifAbsent: () => portion,
      );
    }
    // Distribute credit payment
    if (creditsUsed != 0) {
      final double portion = ratio * creditsUsed;
      data[key]!.update('credit', (v) => v + portion, ifAbsent: () => portion);
    }
  }
}
