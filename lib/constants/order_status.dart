import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum OrderStatus {
  pending('pending'),
  preparing('preparing'),
  ready('ready'),
  delivered('delivered'),
  cancelled('cancelled'),
  refunded('refunded'),
  completed('completed');

  final String value;
  const OrderStatus(this.value);

  static OrderStatus fromString(String? value) {
    if (value == null) return OrderStatus.pending;
    return OrderStatus.values.firstWhere(
      (status) => status.value.toLowerCase() == value.toLowerCase(),
      orElse: () => OrderStatus.pending,
    );
  }

  String get displayName => value.toUpperCase();
  bool get isActive => this == pending || this == preparing;
  bool get isFinished => this == delivered || this == completed;
  bool get isCancelled => this == cancelled || this == refunded;
}

extension OrderStatusUI on OrderStatus {
  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Icons.hourglass_empty_rounded;
      case OrderStatus.preparing:
        return Icons.restaurant_menu_rounded;
      case OrderStatus.ready:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.delivered:
        return Icons.done_all_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_presentation_rounded;
      case OrderStatus.refunded:
        return Icons.reply_all_outlined;
      case OrderStatus.completed:
        return Icons.check_circle_rounded;
    }
  }

  Color backgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (this) {
      case OrderStatus.pending:
        return colorScheme.secondaryContainer;
      case OrderStatus.preparing:
        return colorScheme.primaryContainer;
      case OrderStatus.ready:
        return colorScheme.tertiaryContainer;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return sem.successContainer;
      case OrderStatus.cancelled:
        return colorScheme.errorContainer;
      case OrderStatus.refunded:
        return colorScheme.errorContainer;
    }
  }

  Color foregroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (this) {
      case OrderStatus.pending:
        return colorScheme.onSecondaryContainer;
      case OrderStatus.preparing:
        return colorScheme.onPrimaryContainer;
      case OrderStatus.ready:
        return colorScheme.onTertiaryContainer;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return sem.onSuccessContainer;
      case OrderStatus.cancelled:
        return colorScheme.onErrorContainer;
      case OrderStatus.refunded:
        return colorScheme.onErrorContainer;
    }
  }

  Color accentColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (this) {
      case OrderStatus.pending:
        return colorScheme.secondary;
      case OrderStatus.preparing:
        return colorScheme.primary;
      case OrderStatus.ready:
        return colorScheme.tertiary;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return sem.success;
      case OrderStatus.cancelled:
        return colorScheme.error;
      case OrderStatus.refunded:
        return colorScheme.error;
    }
  }
}
