import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/stock_helper.dart';
import 'glass_panel.dart';
import 'safe_network_avatar.dart';

class CartBottomSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) getItemName;
  final double Function(T) getItemPrice;
  final int Function(T) getItemQuantity;
  final void Function(int index, int newQuantity)? onQuantityChanged;
  final Widget? associationSection;
  final double total;
  final bool canProceed;
  final String proceedButtonText;
  final VoidCallback? onProceed;
  final VoidCallback? onClearCart;
  final Future<int?> Function(String itemId)? getStockQuantity;
  final String Function(T)? getItemId;
  final String? Function(T)? getItemImageUrl;

  const CartBottomSheet({
    super.key,
    required this.title,
    required this.items,
    required this.getItemName,
    required this.getItemPrice,
    required this.getItemQuantity,
    this.onQuantityChanged,
    this.associationSection,
    required this.total,
    required this.canProceed,
    required this.proceedButtonText,
    this.onProceed,
    this.onClearCart,
    this.getStockQuantity,
    this.getItemId,
    this.getItemImageUrl,
  });

  @override
  State<CartBottomSheet<T>> createState() => _CartBottomSheetState<T>();
}

class _CartBottomSheetState<T> extends State<CartBottomSheet<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isProcessing = false;
  int? _lastChangedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<double>(begin: 0.1, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          MediaQuery.of(context).size.height * _slideAnimation.value,
        ),
        child: Opacity(
          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: GlassPanel(
          blur: GlassBlur.modal,
          borderRadiusGeometry: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shopping_bag_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              '${widget.items.length} ${widget.items.length == 1 ? 'item' : 'items'}',
                              key: ValueKey(widget.items.length),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onClearCart != null && widget.items.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          widget.onClearCart!();
                        },
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        label: Text(
                          'Clear',
                          style: TextStyle(color: colorScheme.error),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Association section (customer/table selection)
              if (widget.associationSection != null) ...[
                widget.associationSection!,
                const Divider(height: 1),
              ],

              // Items list
              if (widget.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: colorScheme.outline.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your cart is empty',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add items to get started',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      return _buildCartItem(context, item, index);
                    },
                  ),
                ),

              // Bottom summary and action
              Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Total row with animation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          tween: Tween(begin: widget.total, end: widget.total),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Text(
                            '₹${value.toStringAsFixed(2)}',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Action button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            widget.canProceed &&
                                widget.items.isNotEmpty &&
                                !_isProcessing
                            ? () {
                                setState(() => _isProcessing = true);
                                widget.onProceed?.call();
                              }
                            : null,
                        icon: _isProcessing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Icon(
                                widget.canProceed
                                    ? Icons.arrow_forward_rounded
                                    : Icons.person_search_rounded,
                                size: 20,
                              ),
                        label: Text(
                          _isProcessing
                              ? 'Processing...'
                              : widget.proceedButtonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, T item, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final name = widget.getItemName(item);
    final price = widget.getItemPrice(item);
    final quantity = widget.getItemQuantity(item);
    final lineTotal = price * quantity;
    final isRecentlyChanged = _lastChangedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRecentlyChanged
            ? colorScheme.primaryContainer.withValues(alpha: 0.2)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRecentlyChanged
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Quantity controls
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQtyButton(
                  context,
                  icon: Icons.remove_rounded,
                  onTap: widget.onQuantityChanged != null
                      ? () {
                          HapticFeedback.lightImpact();
                          setState(() => _lastChangedIndex = index);
                          widget.onQuantityChanged!(index, quantity - 1);
                          Future<void>.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() => _lastChangedIndex = null);
                            }
                          });
                        }
                      : null,
                  color: quantity > 1
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.outline,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Container(
                    key: ValueKey(quantity),
                    constraints: const BoxConstraints(minWidth: 32),
                    child: Text(
                      quantity.toString(),
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                _buildQtyButton(
                  context,
                  icon: Icons.add_rounded,
                  onTap: widget.onQuantityChanged != null
                      ? () async {
                          // Stock validation
                          if (widget.getStockQuantity != null &&
                              widget.getItemId != null) {
                            final stockQty = await widget.getStockQuantity!(
                              widget.getItemId!(item),
                            );
                            if (stockQty == null) {
                              if (context.mounted) {
                                StockHelper.showStockError(
                                  context,
                                  'Error fetching stock.',
                                );
                              }
                              return;
                            }
                            if (quantity >= stockQty) {
                              await HapticFeedback.heavyImpact();
                              if (context.mounted) {
                                StockHelper.showStockError(
                                  context,
                                  'Only $stockQty available in stock.',
                                );
                              }
                              return;
                            }
                          }
                          await HapticFeedback.lightImpact();
                          setState(() => _lastChangedIndex = index);
                          widget.onQuantityChanged!(index, quantity + 1);
                          Future<void>.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() => _lastChangedIndex = null);
                            }
                          });
                        }
                      : null,
                  color: colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          ...() {
            final url = widget.getItemImageUrl?.call(item)?.trim();
            if (url == null || url.isEmpty) return <Widget>[];
            return [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SafeNetworkAvatar(
                  imageUrl: url,
                  radius: 22,
                  fallbackIcon: Icons.image_outlined,
                ),
              ),
            ];
          }(),
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${price.toStringAsFixed(0)} each',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Line total with animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 200),
            tween: Tween(begin: lineTotal, end: lineTotal),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Text(
              '₹${value.toStringAsFixed(0)}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
