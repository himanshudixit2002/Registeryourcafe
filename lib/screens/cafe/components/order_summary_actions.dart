import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class OrderSummaryActions extends StatelessWidget {
  final double total;
  final bool hasCustomer;
  final bool hasItems;
  final bool attachToSession;
  final bool isMobile;
  final VoidCallback? onProceed;
  final VoidCallback onClearCart;

  const OrderSummaryActions({
    super.key,
    required this.total,
    required this.hasCustomer,
    required this.hasItems,
    required this.attachToSession,
    required this.isMobile,
    required this.onProceed,
    required this.onClearCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding:
          EdgeInsets.all(
            isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
          ).copyWith(
            bottom: isMobile ? AppTheme.kSpacingMedium : AppTheme.kSpacingLarge,
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.kSpacingMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(
            height: isMobile ? AppTheme.kSpacingMedium : AppTheme.kSpacingLarge,
          ),
          FilledButton.icon(
            icon: Icon(_getButtonIcon(), size: isMobile ? 18 : 20),
            label: Text(
              _getButtonLabel(),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
            onPressed: (hasItems && hasCustomer) ? onProceed : null,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(
                vertical: AppTheme.kSpacingMedium,
                horizontal: isMobile
                    ? AppTheme.kSpacingMedium
                    : AppTheme.kSpacingLarge,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppTheme.kBorderRadiusLarge,
                ),
              ),
            ),
          ),
          if (hasItems) ...[
            SizedBox(height: AppTheme.kSpacingSmall),
            TextButton.icon(
              icon: Icon(
                Icons.remove_shopping_cart_outlined,
                color: colorScheme.error,
                size: isMobile ? 18 : 20,
              ),
              label: Text(
                'Clear Cart',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: onClearCart,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile
                      ? AppTheme.kSpacingXSmall
                      : AppTheme.kSpacingSmall,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.kBorderRadiusMedium,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getButtonIcon() {
    if (!hasCustomer) {
      return Icons.person_search_rounded;
    }
    if (attachToSession) {
      return Icons.add_link_rounded;
    }
    return Icons.payment_rounded;
  }

  String _getButtonLabel() {
    if (!hasCustomer) {
      return 'Select Customer';
    }
    if (attachToSession) {
      return 'Add to Session';
    }
    return 'Proceed to Payment';
  }
}
