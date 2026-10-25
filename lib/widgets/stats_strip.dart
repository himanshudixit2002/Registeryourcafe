import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_panel.dart';

/// A single stat item displayed inside [StatsStrip].
class StatStripItem {
  const StatStripItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

/// Responsive row of stat items with a glass surface background.
///
/// Wraps to a 2x2 grid on narrow mobile screens (<360 logical px available).
/// On tablet+ renders as a single evenly-spaced row.
class StatsStrip extends StatelessWidget {
  const StatsStrip({super.key, required this.items, this.margin});

  final List<StatStripItem> items;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppTheme.isMobile(context);

    return GlassPanel(
      margin: margin ??
          EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 16,
            vertical: isMobile ? 6 : 12,
          ),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 10 : 14,
        horizontal: isMobile ? 8 : 12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 320 && items.length > 3) {
            return Wrap(
              alignment: WrapAlignment.spaceAround,
              runSpacing: 10,
              children: items
                  .map(
                    (item) => SizedBox(
                      width: constraints.maxWidth / 2 - 8,
                      child: _StatItem(item: item, isMobile: isMobile),
                    ),
                  )
                  .toList(),
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items
                .map((item) => _StatItem(item: item, isMobile: isMobile))
                .toList(),
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.item, required this.isMobile});

  final StatStripItem item;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 6 : 8),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(item.icon, color: item.color, size: isMobile ? 16 : 22),
        ),
        SizedBox(height: isMobile ? 4 : 6),
        Text(
          item.value,
          style: TextStyle(
            fontSize: isMobile ? 14 : 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: isMobile ? 1 : 2),
        Text(
          item.label,
          style: TextStyle(
            fontSize: isMobile ? 10 : 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
