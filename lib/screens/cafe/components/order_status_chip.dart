import 'package:flutter/material.dart';
import '../../../constants/order_status.dart';
import '../../../theme/app_theme.dart';

enum ChipSize { small, large }

class OrderStatusChip extends StatelessWidget {
  final String status;
  final ChipSize chipSize;

  const OrderStatusChip({
    super.key,
    required this.status,
    this.chipSize = ChipSize.small,
  });

  @override
  Widget build(BuildContext context) {
    final orderStatus = OrderStatus.fromString(status);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final isMobile = AppTheme.isMobile(context);

    final chipBackgroundColor = orderStatus.backgroundColor(context);
    final chipForegroundColor = orderStatus.foregroundColor(context);
    final iconData = orderStatus.icon;
    final label = status.toUpperCase();

    final fontSize = chipSize == ChipSize.small
        ? (isMobile ? 10.0 : 11.0)
        : (isMobile ? 12.0 : 13.0);
    final iconSizeVal = chipSize == ChipSize.small
        ? (isMobile ? 14.0 : 16.0)
        : (isMobile ? 16.0 : 18.0);
    final padding = chipSize == ChipSize.small
        ? EdgeInsets.symmetric(
            horizontal: isMobile
                ? AppTheme.kSpacingXSmall
                : AppTheme.kSpacingSmall,
            vertical: isMobile
                ? AppTheme.kSpacingXSmall / 2
                : AppTheme.kSpacingXSmall / 1.5,
          )
        : EdgeInsets.symmetric(
            horizontal: AppTheme.kSpacingMedium,
            vertical: isMobile
                ? AppTheme.kSpacingXSmall
                : AppTheme.kSpacingSmall / 1.5,
          );
    final borderRadius = chipSize == ChipSize.small
        ? 20.0
        : AppTheme.kBorderRadiusMedium;

    return Chip(
      avatar: Icon(iconData, color: chipForegroundColor, size: iconSizeVal),
      label: Text(
        label,
        style: textTheme.labelLarge?.copyWith(
          color: chipForegroundColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: chipBackgroundColor,
      padding: padding,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      side: BorderSide(
        color: chipForegroundColor.withValues(alpha: 0.3),
        width: chipBackgroundColor == colorScheme.surfaceContainerHighest
            ? 1
            : 0,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
