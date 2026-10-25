import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_panel.dart';
import '../../../models/cafe_order.dart';
import '../../../widgets/info_placeholder.dart';
import '../../../widgets/app_card.dart';
import '../../../utils/snackbar_helper.dart';

typedef OnQuantityChange = void Function(int index, int newQuantity);

class CurrentOrderList extends StatelessWidget {
  final List<CafeOrderItem> items;
  final GlobalKey<AnimatedListState> animatedListKey;
  final bool isMobile;
  final OnQuantityChange onQuantityChange;
  final Future<int?> Function(String itemId) getStockQuantity;

  const CurrentOrderList({
    super.key,
    required this.items,
    required this.animatedListKey,
    required this.isMobile,
    required this.onQuantityChange,
    required this.getStockQuantity,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const InfoPlaceholder(
        iconData: Icons.shopping_cart_outlined,
        title: 'Cart is Empty',
        message: 'Add items from the menu to get started.',
      );
    }

    return AnimatedList(
      key: animatedListKey,
      physics: AppTheme.scrollPhysicsFor(context),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 12,
      ),
      initialItemCount: items.length,
      itemBuilder: (context, index, animation) {
        if (index >= items.length) return const SizedBox.shrink();
        return _buildOrderItem(context, items[index], index, animation);
      },
    );
  }

  Widget _buildOrderItem(
    BuildContext context,
    CafeOrderItem orderItem,
    int index,
    Animation<double> animation,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return SizeTransition(
      sizeFactor: animation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      orderItem.quantity.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orderItem.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '₹${orderItem.price.toStringAsFixed(0)} each',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${(orderItem.price * orderItem.quantity).toStringAsFixed(0)}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQtyBtn(
                          icon: Icons.remove_rounded,
                          color: colorScheme.error,
                          onTap: () =>
                              onQuantityChange(index, orderItem.quantity - 1),
                        ),
                        const SizedBox(width: 8),
                        _buildQtyBtn(
                          icon: Icons.add_rounded,
                          color: colorScheme.primary,
                          onTap: () async {
                            final stockQty = await getStockQuantity(
                              orderItem.itemId,
                            );
                            if (stockQty == null) {
                              if (context.mounted) {
                                context.showErrorSnackbar('Error fetching stock.');
                              }
                              return;
                            }
                            if (orderItem.quantity >= stockQty) {
                              if (context.mounted) {
                                SnackbarHelper.showWarning(
                                  context,
                                  'Only $stockQty available.',
                                  duration: const Duration(seconds: 1),
                                );
                              }
                              return;
                            }
                            onQuantityChange(index, orderItem.quantity + 1);
                          },
                        ),
                      ],
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

  Widget _buildQtyBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  /// Builds a widget for animating removed items.
  static Widget buildRemovedOrderItemCard(
    BuildContext context,
    CafeOrderItem orderItem,
    bool isMobile,
  ) {
    // Return a static snapshot for exit animation
    return AppSurface(
      padding: EdgeInsets.zero,
      child: ListTile(title: Text(orderItem.name), trailing: Text('Removed')),
    );
  }
}
