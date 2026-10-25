import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/venue_kind.dart';
import '../../../models/venue_ui_config.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/stat_card.dart';
import '../../../providers/dashboard_provider.dart';

/// Bento-style KPI layout with theme-aligned accents.
class DashboardKpiGrid extends StatelessWidget {
  const DashboardKpiGrid({super.key, required this.data, this.venueKind = VenueKind.gamingCafe});

  final DashboardData data;
  final VenueKind venueKind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chart = ChartTheme.of(context);
    final cs = theme.colorScheme;
    final columns = AppTheme.getGridColumns(context);
    const spacing = 20.0;

    final cards = <Widget>[
      StatCard(
        title: 'Total Sales',
        value: NumberFormat.currency(
          symbol: '\u20B9',
          decimalDigits: 0,
        ).format(data.totalSales),
        icon: Icons.trending_up_rounded,
        color: cs.primary,
      ),
      StatCard(
        title: 'Orders Today',
        value: data.ordersToday.toString(),
        icon: Icons.shopping_cart_rounded,
        color: chart.lineSecondary,
      ),
      StatCard(
        title: venueKind.isGaming ? 'Sessions Today' : 'Seatings Today',
        value: data.sessionsToday.toString(),
        icon: venueKind.isGaming ? Icons.hourglass_top_rounded : Icons.event_seat_rounded,
        color: cs.tertiary,
      ),
      StatCard(
        title: venueKind.isGaming ? 'Avg Session Duration' : 'Avg Seating Time',
        value: _formatDuration(data.averageSessionDuration),
        icon: Icons.timelapse_rounded,
        color: cs.secondary,
      ),
      StatCard(
        title: venueKind.activeSessionsLabel,
        value: '${data.activeTables}/${data.totalTables}',
        icon: venueKind.tableTabActiveIcon,
        color: chart.linePrimary,
      ),
      StatCard(
        title: 'Total ${venueKind.customerTabLabel}',
        value: data.totalCustomers.toString(),
        icon: venueKind.customerTabActiveIcon,
        color: cs.primary.withValues(alpha: 0.85),
      ),
      ..._categoryCards(context, data.salesByCategory),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final rawWidth = (maxW - (spacing * (columns - 1))) / columns;
        final capped = columns >= 4 ? rawWidth.clamp(0.0, 280.0) : rawWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: capped, child: card))
              .toList(),
        );
      },
    );
  }

  List<Widget> _categoryCards(
    BuildContext context,
    Map<String, double> categorySales,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final chart = ChartTheme.of(context);

    final iconMap = <String, IconData>{
      'Cafe': Icons.local_cafe_rounded,
      'Table': Icons.table_bar_rounded,
      'Merchandise': Icons.shopping_bag_rounded,
      'Credit Top-up': Icons.credit_score_rounded,
    };
    final colorList = [
      cs.primary,
      chart.linePrimary,
      chart.lineSecondary,
      cs.tertiary,
    ];

    var i = 0;
    return categorySales.entries.map((entry) {
      final title = entry.key == 'Credit Top-up'
          ? 'Credit Top-ups'
          : '${entry.key} Charges';
      final icon = iconMap[entry.key] ?? Icons.payments_rounded;
      final color = colorList[i % colorList.length];
      i++;
      return StatCard(
        title: title,
        value: NumberFormat.currency(
          symbol: '\u20B9',
          decimalDigits: 0,
        ).format(entry.value),
        icon: icon,
        color: color,
      );
    }).toList();
  }

  String _formatDuration(double minutes) {
    if (minutes.isNaN || minutes.isInfinite) return '0m';
    final totalMinutes = minutes.round();
    final hrs = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hrs == 0) return '${mins}m';
    return '${hrs}h ${mins}m';
  }
}
