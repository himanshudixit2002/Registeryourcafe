import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class FloatingCartButton extends StatelessWidget {
  final int itemCount;
  final double total;
  final VoidCallback onTap;
  final bool isEnabled;

  const FloatingCartButton({
    super.key,
    required this.itemCount,
    required this.total,
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Positioned(
      right: 16,
      bottom: 16,
      child: TweenAnimationBuilder<double>(
        duration: AppTheme.kAnimationDurationMedium,
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.elasticOut,
        builder: (context, value, child) => Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        ),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(28),
          shadowColor: colorScheme.primary.withValues(alpha: 0.4),
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(
                      blue:
                          ((colorScheme.primary.b * 255.0 + 20).round().clamp(
                            0,
                            255,
                          )) /
                          255.0,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cart icon with badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.shopping_bag_rounded,
                        color: colorScheme.onPrimary,
                        size: 24,
                      ),
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            itemCount.toString(),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Total amount
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View Cart',
                        style: TextStyle(
                          color: colorScheme.onPrimary.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: colorScheme.onPrimary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
