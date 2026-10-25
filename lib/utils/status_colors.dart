import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/membership_tier_colors.dart';

class StatusColors {
  StatusColors._();

  static AppSemanticColors _semantic(BuildContext context) =>
      AppSemanticColors.of(context);

  // Order Status
  static Color getOrderStatusForeground(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = _semantic(context);
    switch (status.toLowerCase()) {
      case 'pending':
        return colorScheme.onSecondaryContainer;
      case 'preparing':
        return colorScheme.onPrimaryContainer;
      case 'ready':
        return colorScheme.onTertiaryContainer;
      case 'delivered':
      case 'completed':
        return semantic.onSuccessContainer;
      case 'cancelled':
        return colorScheme.onErrorContainer;
      case 'refunded':
        return colorScheme.onError;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  static Color getOrderStatusBackground(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = _semantic(context);
    switch (status.toLowerCase()) {
      case 'pending':
        return colorScheme.secondaryContainer;
      case 'preparing':
        return colorScheme.primaryContainer;
      case 'ready':
        return colorScheme.tertiaryContainer;
      case 'delivered':
      case 'completed':
        return semantic.successContainer;
      case 'cancelled':
        return colorScheme.errorContainer;
      case 'refunded':
        return colorScheme.errorContainer;
      default:
        return colorScheme.surfaceContainerHighest;
    }
  }

  static Color getOrderStatusAccent(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = _semantic(context);
    switch (status.toLowerCase()) {
      case 'pending':
        return colorScheme.secondary;
      case 'preparing':
        return colorScheme.primary;
      case 'ready':
        return colorScheme.tertiary;
      case 'delivered':
      case 'completed':
        return semantic.success;
      case 'cancelled':
        return colorScheme.error;
      case 'refunded':
        return colorScheme.error;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  static IconData getOrderStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'preparing':
        return Icons.restaurant_menu_rounded;
      case 'ready':
        return Icons.check_circle_outline_rounded;
      case 'delivered':
      case 'completed':
        return Icons.done_all_rounded;
      case 'cancelled':
        return Icons.cancel_presentation_rounded;
      case 'refunded':
        return Icons.reply_all_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  // Table Status
  static Color getTableStatusForeground(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = _semantic(context);
    switch (status.toLowerCase()) {
      case 'available':
        return semantic.onSuccessContainer;
      case 'occupied':
        return colorScheme.onPrimaryContainer;
      case 'maintenance':
        return semantic.onWarningContainer;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  static Color getTableStatusBackground(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = _semantic(context);
    switch (status.toLowerCase()) {
      case 'available':
        return semantic.successContainer;
      case 'occupied':
        return colorScheme.primaryContainer;
      case 'maintenance':
        return semantic.warningContainer;
      default:
        return colorScheme.surfaceContainerHighest;
    }
  }

  // Session Status
  static Color getSessionStatusForeground(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = _semantic(context);
    switch (status.toLowerCase()) {
      case 'active':
        return colorScheme.onPrimaryContainer;
      case 'completed':
        return semantic.onSuccessContainer;
      case 'cancelled':
        return colorScheme.onErrorContainer;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  static Color getSessionStatusBackground(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = _semantic(context);
    switch (status.toLowerCase()) {
      case 'active':
        return colorScheme.primaryContainer;
      case 'completed':
        return semantic.successContainer;
      case 'cancelled':
        return colorScheme.errorContainer;
      default:
        return colorScheme.surfaceContainerHighest;
    }
  }

  // Membership
  static Color getMembershipColor(String membershipType) =>
      MembershipTierColors.surface(membershipType);

  static Color getMembershipTextColor(String membershipType) =>
      MembershipTierColors.label(membershipType);
}
