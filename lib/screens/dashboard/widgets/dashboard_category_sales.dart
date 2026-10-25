import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import 'dashboard_section.dart';

class DashboardCategorySales extends StatelessWidget {
  const DashboardCategorySales({
    super.key,
    required this.salesByCategory,
    required this.screenWidth,
  });

  final Map<String, double> salesByCategory;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = screenWidth < AppTheme.kMobileBreakpoint;
    final dataEntries = salesByCategory.entries.toList();
    final totalSales = salesByCategory.values.fold(0.0, (a, b) => a + b);
    final pieSize = isMobile ? 108.0 : 128.0;

    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
    ];

    return DashboardSection(
      eyebrow: 'Mix',
      title: 'Charges by category',
      subtitle: 'Share of revenue in the last 7 days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                NumberFormat.currency(
                  symbol: '\u20B9',
                  decimalDigits: 0,
                ).format(totalSales),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              SizedBox(
                height: pieSize,
                width: pieSize,
                child: PieChart(
                  PieChartData(
                    sections: List.generate(dataEntries.length, (i) {
                      final entry = dataEntries[i];
                      final pct = totalSales == 0
                          ? 0.0
                          : (entry.value / totalSales * 100);
                      return PieChartSectionData(
                        color: colors[i % colors.length],
                        value: entry.value,
                        title: '${pct.toStringAsFixed(0)}%',
                        radius: isMobile ? 42 : 48,
                        titleStyle: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onPrimary,
                        ),
                      );
                    }),
                    sectionsSpace: 2,
                    centerSpaceRadius: isMobile ? 28 : 32,
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 14 : 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(dataEntries.length, (i) {
                    final entry = dataEntries[i];
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[i % colors.length],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${entry.key}: ${NumberFormat.compactCurrency(symbol: '\u20B9', decimalDigits: 0).format(entry.value)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 12 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
