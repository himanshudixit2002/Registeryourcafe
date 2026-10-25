import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../models/sales_transaction.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/sales_palette.dart';
import '../../../widgets/glass_panel.dart';

class RevenueTypeBreakdownWidget extends StatefulWidget {
  final SalesDataSummary summary;

  const RevenueTypeBreakdownWidget({super.key, required this.summary});

  @override
  State<RevenueTypeBreakdownWidget> createState() =>
      _RevenueTypeBreakdownWidgetState();
}

class _RevenueTypeBreakdownWidgetState
    extends State<RevenueTypeBreakdownWidget> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);

    // Extract revenue types - include Tournament explicitly
    final revenueTypes = widget.summary.revenueByType.entries
        .where((entry) => entry.value > 0)
        .toList();

    if (revenueTypes.isEmpty) {
      final cs = theme.colorScheme;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.cardShadowFor(theme.brightness),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 40,
                color: cs.outlineVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'No revenue data',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final grandTotal = revenueTypes.fold(0.0, (sum, item) => sum + item.value);

    if (isMobile) {
      return _buildMobileChart(context, theme, revenueTypes, grandTotal);
    }

    return _buildDesktopChart(context, theme, revenueTypes, grandTotal);
  }

  Widget _buildMobileChart(
    BuildContext context,
    ThemeData theme,
    List<MapEntry<String, double>> revenueTypes,
    double grandTotal,
  ) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadowFor(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Value by Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '₹${grandTotal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Bar chart style for mobile
          ...revenueTypes.map((entry) {
            final color = SalesPalette.revenueKey(context, entry.key);
            final percentage = grandTotal > 0
                ? (entry.value / grandTotal * 100)
                : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _displayLabel(entry.key),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '₹${entry.value.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: grandTotal > 0 ? entry.value / grandTotal : 0,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDesktopChart(
    BuildContext context,
    ThemeData theme,
    List<MapEntry<String, double>> revenueTypes,
    double grandTotal,
  ) {
    final cs = theme.colorScheme;
    return AppSurface(
      borderRadius: 12,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Value by Type', style: theme.textTheme.titleLarge),
              const Spacer(),
              Text(
                'Total: ₹${grandTotal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.6,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: _generateSections(context, revenueTypes, grandTotal),
                centerSpaceRadius: 50,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(context, revenueTypes, grandTotal),
        ],
      ),
    );
  }

  String _displayLabel(String key) {
    switch (key) {
      case 'Table Charges':
        return 'Table Charges';
      case 'Credit Top-up':
        return 'Credit Top-up';
      default:
        return key;
    }
  }

  List<PieChartSectionData> _generateSections(
    BuildContext context,
    List<MapEntry<String, double>> data,
    double grandTotal,
  ) {
    return List.generate(data.length, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 13.0 : 11.0;
      final radius = isTouched ? 65.0 : 55.0;
      final entry = data[i];
      final color = SalesPalette.revenueKey(context, entry.key);

      final percentage = grandTotal > 0 ? (entry.value / grandTotal * 100) : 0;
      final labelColor = SalesPalette.onChartSlice(context, color);
      final shadowColor = Theme.of(context).colorScheme.shadow;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: labelColor,
          shadows: [
            Shadow(color: shadowColor.withValues(alpha: 0.45), blurRadius: 2),
          ],
        ),
      );
    });
  }

  Widget _buildLegend(
    BuildContext context,
    List<MapEntry<String, double>> data,
    double grandTotal,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: data.map((entry) {
        final color = SalesPalette.revenueKey(context, entry.key);
        final percentage = grandTotal > 0
            ? (entry.value / grandTotal * 100)
            : 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _displayLabel(entry.key),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '₹${entry.value.toStringAsFixed(0)} (${percentage.toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

}
