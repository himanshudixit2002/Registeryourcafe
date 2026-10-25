import 'package:flutter/material.dart';
import '../theme/app_theme.dart'; // Assuming AppTheme is in lib/theme

class KeyValueText extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final TextStyle? titleStyle;
  final TextStyle? valueStyle;
  final Color? iconColor;

  const KeyValueText({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.titleStyle,
    this.valueStyle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.kSpacingXSmall / 1.5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 18,
              color:
                  iconColor ??
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          if (icon != null) const SizedBox(width: AppTheme.kSpacingSmall),
          Expanded(
            child: RichText(
              text: TextSpan(
                style:
                    titleStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                children: <TextSpan>[
                  TextSpan(text: '$title: '),
                  TextSpan(
                    text: value,
                    style:
                        valueStyle ??
                        theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
