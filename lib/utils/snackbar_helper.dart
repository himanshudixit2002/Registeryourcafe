import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'app_logger.dart';

class SnackbarHelper {
  static void showSuccess(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final cs = Theme.of(context).colorScheme;
    _showSnackbar(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      accentColor: AppTheme.successColor,
      backgroundColor: cs.inverseSurface,
      foregroundColor: cs.onInverseSurface,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    HapticFeedback.mediumImpact();
    final cs = Theme.of(context).colorScheme;
    _showSnackbar(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      accentColor: cs.error,
      backgroundColor: cs.inverseSurface,
      foregroundColor: cs.onInverseSurface,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final cs = Theme.of(context).colorScheme;
    _showSnackbar(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      accentColor: AppTheme.infoColor,
      backgroundColor: cs.inverseSurface,
      foregroundColor: cs.onInverseSurface,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final cs = Theme.of(context).colorScheme;
    _showSnackbar(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      accentColor: AppTheme.warningColor,
      backgroundColor: cs.inverseSurface,
      foregroundColor: cs.onInverseSurface,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoading(
    BuildContext context,
    String message,
  ) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    return ScaffoldMessenger.of(context).showSnackBar(
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(minutes: 5),
      ),
    );
  }

  static void dismiss(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Heuristic match for Firestore / client permission failures (aligned with
  /// [SectionAsyncError] classification).
  static bool isLikelyFirestorePermissionDenied(Object error) =>
      AppLogger.isLikelyFirestorePermissionDenied(error);

  /// User-facing copy for tenant writes when access is denied.
  static String messageForFirestoreMutationFailure(Object error) {
    if (isLikelyFirestorePermissionDenied(error)) {
      return 'Firestore denied this write. The registered owner (company '
          'ownerUid in Firebase) must open the app once so '
          'companies/.../permissionRoles/* can sync. Check your user doc has the '
          'correct companyId and a roleId whose permissionIds include '
          'nav.tables (or ops.table_types_configure). Deploy firestore.rules, '
          'then sign out and in.';
    }
    return 'Failed: $error';
  }

  static void _showSnackbar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color accentColor,
    required Color backgroundColor,
    required Color foregroundColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: foregroundColor,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: accentColor,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }
}

extension SnackbarExtension on BuildContext {
  void showSuccessSnackbar(String message) =>
      SnackbarHelper.showSuccess(this, message);

  void showErrorSnackbar(String message) =>
      SnackbarHelper.showError(this, message);

  void showInfoSnackbar(String message) =>
      SnackbarHelper.showInfo(this, message);

  void showWarningSnackbar(String message) =>
      SnackbarHelper.showWarning(this, message);
}
