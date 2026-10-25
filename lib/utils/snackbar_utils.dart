import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SnackbarUtils {
  SnackbarUtils._();

  static const Duration defaultDuration = Duration(seconds: 3);

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      accentColor: AppTheme.successColor,
      duration: duration,
      action: action,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
    SnackBarAction? action,
  }) {
    final cs = Theme.of(context).colorScheme;
    _show(
      context,
      message: message,
      icon: Icons.error_outline,
      accentColor: cs.error,
      duration: duration,
      action: action,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      icon: Icons.warning_amber_outlined,
      accentColor: AppTheme.warningColor,
      duration: duration,
      action: action,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline,
      accentColor: AppTheme.infoColor,
      duration: duration,
      action: action,
    );
  }

  static ScaffoldMessengerState showLoading(
    BuildContext context,
    String message,
  ) {
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: cs.onInverseSurface),
              ),
            ),
          ],
        ),
        backgroundColor: cs.inverseSurface,
        duration: const Duration(minutes: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return messenger;
  }

  static void showUndo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    _show(
      context,
      message: message,
      icon: Icons.delete_outline,
      accentColor: AppTheme.warningColor,
      duration: duration,
      action: SnackBarAction(
        label: 'UNDO',
        textColor: AppTheme.warningColor,
        onPressed: onUndo,
      ),
    );
  }

  static void show(
    BuildContext context, {
    required String message,
    Color? accentColor,
    IconData? icon,
    Duration duration = defaultDuration,
    SnackBarAction? action,
  }) {
    final cs = Theme.of(context).colorScheme;
    _show(
      context,
      message: message,
      icon: icon,
      accentColor: accentColor ?? cs.primary,
      duration: duration,
      action: action,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    IconData? icon,
    required Color accentColor,
    Duration duration = defaultDuration,
    SnackBarAction? action,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.inverseSurface;
    final fg = cs.onInverseSurface;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(message, style: TextStyle(color: fg)),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: action,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  static void hide(BuildContext context) =>
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
}

extension SnackbarContextExtension on BuildContext {
  void showSuccessSnackbar(String message) =>
      SnackbarUtils.showSuccess(this, message);

  void showErrorSnackbar(String message) =>
      SnackbarUtils.showError(this, message);

  void showWarningSnackbar(String message) =>
      SnackbarUtils.showWarning(this, message);

  void showInfoSnackbar(String message) =>
      SnackbarUtils.showInfo(this, message);
}
