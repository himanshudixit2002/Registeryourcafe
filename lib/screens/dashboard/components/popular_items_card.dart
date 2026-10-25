import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class PopularItemsCard extends StatelessWidget {
  final List<MapEntry<String, int>> popularItems;

  const PopularItemsCard({super.key, required this.popularItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.12),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular Items',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: popularItems.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.subtleDividerColor(theme),
            ),
            itemBuilder: (context, index) {
              final item = popularItems[index];
              return ListTile(
                leading: Container(
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.coffee, color: cs.primary),
                ),
                title: Text(
                  item.key,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${item.value} orders this week'),
                trailing: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
