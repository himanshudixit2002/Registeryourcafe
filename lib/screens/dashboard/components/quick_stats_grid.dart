import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/sales_palette.dart';
import '../../../widgets/stat_card.dart';

class QuickStatsGrid extends StatelessWidget {
  final double totalSales;
  final int ordersToday;
  final int sessionsToday;
  final double averageSessionDuration;
  final int activeTables;
  final int totalTables;
  final int totalCustomers;
  final Map<String, double> categorySales;

  const QuickStatsGrid({
    super.key,
    required this.totalSales,
    required this.ordersToday,
    required this.sessionsToday,
    required this.averageSessionDuration,
    required this.activeTables,
    required this.totalTables,
    required this.totalCustomers,
    required this.categorySales,
  });

  @override
  Widget build(BuildContext context) {
    final columns = AppTheme.getGridColumns(context);
    const spacing = 24.0;
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);

    final List<Widget> cards = [
      StatCard(
        title: 'Total Sales',
        value: NumberFormat.currency(
          symbol: '₹',
          decimalDigits: 0,
        ).format(totalSales),
        icon: Icons.attach_money,
        color: sem.success,
      ),
      StatCard(
        title: 'Orders Today',
        value: ordersToday.toString(),
        icon: Icons.shopping_cart,
        color: cs.primary,
      ),
      StatCard(
        title: 'Sessions Today',
        value: sessionsToday.toString(),
        icon: Icons.hourglass_bottom,
        color: sem.info,
      ),
      StatCard(
        title: 'Avg Session Duration',
        value: _formatDuration(averageSessionDuration),
        icon: Icons.timelapse,
        color: sem.warning,
      ),
      StatCard(
        title: 'Active Tables',
        value: '$activeTables/$totalTables',
        icon: Icons.table_bar,
        color: cs.tertiary,
      ),
      StatCard(
        title: 'Total Customers',
        value: totalCustomers.toString(),
        icon: Icons.people,
        color: cs.secondary,
      ),
      ..._buildCategoryStatCards(context),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }

  String _formatDuration(double minutes) {
    if (minutes.isNaN || minutes.isInfinite) return '0m';
    final totalMinutes = minutes.round();
    final hrs = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hrs == 0) return '${mins}m';
    return '${hrs}h ${mins}m';
  }

  List<Widget> _buildCategoryStatCards(BuildContext context) {
    const Map<String, IconData> iconMap = {
      'Cafe': Icons.local_cafe,
      'Table': Icons.table_bar,
      'Merchandise': Icons.shopping_bag,
      'Credit Top-up': Icons.credit_score,
    };

    return categorySales.entries.map((entry) {
      final title = entry.key == 'Credit Top-up'
          ? 'Credit Top-ups'
          : '${entry.key} Charges';
      final icon = iconMap[entry.key] ?? Icons.attach_money;
      final color = SalesPalette.revenueKey(context, entry.key);
      return StatCard(
        title: title,
        value: NumberFormat.currency(
          symbol: '₹',
          decimalDigits: 0,
        ).format(entry.value),
        icon: icon,
        color: color,
      );
    }).toList();
  }
}
