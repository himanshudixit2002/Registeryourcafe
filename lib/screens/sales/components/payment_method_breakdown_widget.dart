import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../models/sales_transaction.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/sales_palette.dart';
import '../../../widgets/glass_panel.dart';

class PaymentMethodBreakdownWidget extends StatefulWidget {
  final SalesDataSummary summary;

  const PaymentMethodBreakdownWidget({super.key, required this.summary});

  @override
  State<PaymentMethodBreakdownWidget> createState() =>
      _PaymentMethodBreakdownWidgetState();
}

class _PaymentMethodBreakdownWidgetState
    extends State<PaymentMethodBreakdownWidget> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paymentMethods = widget.summary.paymentMethodTotals.entries
        .where((entry) => entry.value > 0)
        .toList();

    if (paymentMethods.isEmpty) {
      return const SizedBox.shrink();
    }
    final grandTotal = paymentMethods.fold(
      0.0,
      (sum, item) => sum + item.value,
    );

    return AppSurface(
      borderRadius: AppTheme.kBorderRadiusMedium,
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Methods', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingLarge),
          AspectRatio(
            aspectRatio: 1.5,
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
                sections: _generateSections(context, paymentMethods, grandTotal),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.kSpacingMedium),
          _buildLegend(context, paymentMethods),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateSections(
    BuildContext context,
    List<MapEntry<String, double>> data,
    double grandTotal,
  ) {
    return List.generate(data.length, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 12.0 : 10.0;
      final radius = isTouched ? 60.0 : 50.0;
      final entry = data[i];
      final color = SalesPalette.paymentMethod(context, entry.key);
      final percentage = grandTotal > 0 ? (entry.value / grandTotal * 100) : 0;
      final labelColor = SalesPalette.onChartSlice(context, color);
      final shadowColor = Theme.of(context).colorScheme.shadow;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title:
            '${percentage.toStringAsFixed(1)}%\n₹${entry.value.toStringAsFixed(0)}',
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
  ) {
    return Wrap(
      spacing: AppTheme.kSpacingSmall,
      runSpacing: AppTheme.kSpacingSmall,
      alignment: WrapAlignment.center,
      children: List.generate(data.length, (i) {
        final entry = data[i];
        final color = SalesPalette.paymentMethod(context, entry.key);
        return Chip(
          avatar: CircleAvatar(backgroundColor: color, radius: 8),
          label: Text(
            entry.key[0].toUpperCase() + entry.key.substring(1),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          backgroundColor: color.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        );
      }),
    );
  }

}
