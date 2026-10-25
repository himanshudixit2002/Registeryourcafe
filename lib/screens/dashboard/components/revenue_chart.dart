import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/glass_panel.dart' show GlassBlur;
import '../widgets/dashboard_section.dart';

class RevenueChart extends StatelessWidget {
  final List<double> revenueData;

  const RevenueChart({super.key, required this.revenueData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chart = ChartTheme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;
    final chartHeight = isMobile ? screenHeight * 0.3 : 260.0;

    final maxY =
        (revenueData.isEmpty
            ? 0
            : revenueData.reduce((a, b) => a > b ? a : b)) *
        1.2;
    final yInterval = (maxY / 4).ceilToDouble();

    return DashboardSection(
      eyebrow: 'Performance',
      title: 'Revenue overview',
      subtitle: 'Daily totals — last 7 days',
      trailing: _buildChartLegend(theme),
      blur: GlassBlur.auto,
      borderRadius: 20,
      panelPadding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 18,
        isMobile ? 8 : 12,
        isMobile ? 12 : 18,
        isMobile ? 14 : 18,
      ),
      child: SizedBox(
        height: chartHeight,
        child: BarChart(
          BarChartData(
            maxY: maxY == 0 ? 10 : maxY,
            barGroups: _buildBarGroups(theme),
            gridData: _buildGridData(yInterval, chart),
            titlesData: _buildTitlesData(theme, chart),
            borderData: FlBorderData(show: false),
            barTouchData: _buildTouchData(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegend(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Revenue',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<BarChartGroupData> _buildBarGroups(ThemeData theme) {
    return revenueData.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.9),
                theme.colorScheme.primary.withValues(alpha: 0.22),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(8),
            width: 18,
          ),
        ],
      );
    }).toList();
  }

  FlGridData _buildGridData(double yInterval, ChartTheme chart) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: yInterval == 0 ? 10 : yInterval,
      getDrawingHorizontalLine: (value) =>
          FlLine(strokeWidth: 1, color: chart.gridColor),
    );
  }

  FlTitlesData _buildTitlesData(ThemeData theme, ChartTheme chart) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          getTitlesWidget: (value, meta) => Text(
            NumberFormat.compactCurrency(
              symbol: '\u20B9',
              decimalDigits: 0,
            ).format(value),
            style: TextStyle(color: chart.axisLabelColor, fontSize: 11),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= revenueData.length) {
              return const SizedBox.shrink();
            }
            final date = DateTime.now().subtract(Duration(days: 6 - idx));
            return Text(
              DateFormat('E').format(date),
              style: TextStyle(color: chart.axisLabelColor, fontSize: 12),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  BarTouchData _buildTouchData(ThemeData theme) {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => theme.colorScheme.inverseSurface,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          return BarTooltipItem(
            NumberFormat.currency(
              symbol: '\u20B9',
              decimalDigits: 0,
            ).format(rod.toY),
            TextStyle(color: theme.colorScheme.onInverseSurface, fontSize: 12),
          );
        },
      ),
    );
  }
}
