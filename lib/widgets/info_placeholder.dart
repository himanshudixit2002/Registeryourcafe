import 'package:flutter/material.dart';
import 'package:registeryourcafe/theme/app_theme.dart';

class InfoPlaceholder extends StatelessWidget {
  final IconData iconData;
  final String title;
  final String message;
  final Color? iconColor;
  final double iconSize;

  const InfoPlaceholder({
    super.key,
    required this.iconData,
    required this.title,
    required this.message,
    this.iconColor,
    this.iconSize = 72,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: iconSize,
              color: iconColor ?? colorScheme.secondary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppTheme.kSpacingMedium),
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                color:
                    iconColor ?? colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.kSpacingSmall),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
