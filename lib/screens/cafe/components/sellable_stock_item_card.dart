import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/stock_item.dart';
import '../../../theme/app_theme.dart';
import '../../../auth/permission_id.dart';
import '../../../providers/permissions_provider.dart';
import '../../../widgets/dialogs/item_revenue_dialog.dart';
import '../../../widgets/safe_network_avatar.dart';

Color _menuAccentForCategory(String? category) {
  final cat = category?.toLowerCase() ?? '';
  if (cat.contains('coffee') ||
      cat.contains('espresso') ||
      cat.contains('latte')) {
    return const Color(0xFF5D4037);
  }
  if (cat.contains('tea') || cat.contains('chai')) {
    return const Color(0xFF795548);
  }
  if (cat.contains('cold') ||
      cat.contains('iced') ||
      cat.contains('shake') ||
      cat.contains('smoothie')) {
    return const Color(0xFF00838F);
  }
  if (cat.contains('snack') || cat.contains('food') || cat.contains('bite')) {
    return const Color(0xFFEF6C00);
  }
  if (cat.contains('dessert') ||
      cat.contains('sweet') ||
      cat.contains('cake')) {
    return const Color(0xFFD81B60);
  }
  if (cat.contains('juice') || cat.contains('fresh')) {
    return const Color(0xFF43A047);
  }
  if (cat.contains('soup') || cat.contains('hot')) {
    return const Color(0xFFE65100);
  }
  return const Color(0xFF546E7A);
}

Color _stockColor(ColorScheme cs, AppSemanticColors sem, StockItem item) {
  final qty = item.quantity;
  final threshold = item.lowStockThreshold;
  if (qty <= 0) return cs.outline;
  if (threshold > 0 && qty <= threshold * 0.5) {
    return cs.error;
  }
  if (threshold > 0 && qty <= threshold) {
    return cs.tertiary;
  }
  return sem.success;
}

/// Compact list row for the cafe menu (no images, minimal chrome).
class SellableMenuListTile extends ConsumerWidget {
  final StockItem stockItem;
  final void Function(StockItem) onAddToCart;

  const SellableMenuListTile({
    super.key,
    required this.stockItem,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final item = stockItem;
    final accent = _menuAccentForCategory(item.category);
    final sem = AppSemanticColors.of(context);
    final stockTint = _stockColor(colorScheme, sem, item);

    final isAvailable =
        item.isSellable &&
        item.quantity > 0 &&
        item.price != null &&
        item.price! > 0;

    String? statusMessage;
    if (!item.isSellable) {
      statusMessage = 'Not for sale';
    } else if (item.price == null || item.price! <= 0) {
      statusMessage = 'Price not set';
    } else if (item.quantity <= 0) {
      statusMessage = 'Out of stock';
    }

    final isLowStock =
        item.quantity > 0 &&
        item.lowStockThreshold > 0 &&
        item.quantity <= item.lowStockThreshold;
    final qtyLabel = item.quantity > 999
        ? '999+'
        : item.quantity.toStringAsFixed(
            item.unit == 'piece' || item.unit == 'pcs' ? 0 : 1,
          );

    final canCafeAdmin = ref.watchResolvedPermissions().can(
      PermissionIds.opsCafeAdmin,
    );

    final hasDescription =
        item.description != null && item.description!.trim().isNotEmpty;

    final cardFill = Color.lerp(colorScheme.surfaceContainerLow, accent, 0.12)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable ? () => onAddToCart(item) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 44,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SafeNetworkAvatar(
                  imageUrl: item.imageUrl,
                  radius: 20,
                  fallbackIcon: Icons.local_cafe_rounded,
                  fallbackBackgroundColor: accent.withValues(alpha: 0.12),
                  fallbackIconColor: accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.category != null &&
                          item.category!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.category!.trim(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (hasDescription) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description!.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.price != null && item.price! > 0)
                            Text(
                              '₹${item.price!.toStringAsFixed(0)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            )
                          else
                            Text(
                              'No price',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                              ),
                            ),
                          _QtyChip(
                            label: qtyLabel,
                            color: stockTint,
                            warn: isLowStock,
                          ),
                          if (!isAvailable && statusMessage != null)
                            Text(
                              statusMessage,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canCafeAdmin)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        tooltip: 'Analytics',
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => ItemRevenueDialog(item: item),
                          );
                        },
                        icon: Icon(
                          Icons.bar_chart_rounded,
                          size: 20,
                          color: accent,
                        ),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: isAvailable ? () => onAddToCart(item) : null,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool warn;

  const _QtyChip({
    required this.label,
    required this.color,
    required this.warn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            warn ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
