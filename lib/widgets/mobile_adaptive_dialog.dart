import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

Color _foregroundOnConfirmBackground(ThemeData theme, Color background) {
  final cs = theme.colorScheme;
  if (background == cs.error) return cs.onError;
  if (background == cs.primary) return cs.onPrimary;
  return background.computeLuminance() > 0.5
      ? cs.onSurface
      : cs.onInverseSurface;
}

/// A utility class for showing mobile-optimized dialogs
/// Uses bottom sheets on mobile and regular dialogs on larger screens
class MobileAdaptiveDialog {
  /// Show a dialog that adapts to screen size
  /// - Mobile: Shows as a draggable bottom sheet
  /// - Tablet/Desktop: Shows as a centered dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext context) builder,
    bool isDismissible = true,
    bool enableDrag = true,
    String? title,
    IconData? titleIcon,
    Color? titleIconColor,
    List<Widget>? actions,
    double? maxHeight,
    bool useRootNavigator = true,
    bool isScrollControlled = true,
  }) {
    final isMobile = AppTheme.isMobile(context);

    if (isMobile) {
      HapticFeedback.lightImpact();
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        useRootNavigator: useRootNavigator,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _MobileBottomSheetWrapper(
          title: title,
          titleIcon: titleIcon,
          titleIconColor: titleIconColor,
          actions: actions,
          maxHeight: maxHeight,
          child: builder(ctx),
        ),
      );
    } else {
      return showDialog<T>(
        context: context,
        barrierDismissible: isDismissible,
        useRootNavigator: useRootNavigator,
        builder: (ctx) => AlertDialog(
          title: title != null
              ? Row(
                  children: [
                    if (titleIcon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              (titleIconColor ??
                                      Theme.of(ctx).colorScheme.primary)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          titleIcon,
                          color:
                              titleIconColor ??
                              Theme.of(ctx).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: Text(title)),
                  ],
                )
              : null,
          content: SingleChildScrollView(child: builder(ctx)),
          actions: actions,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusLarge),
          ),
        ),
      );
    }
  }

  /// Show a confirmation dialog optimized for mobile
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = AppStrings.confirm,
    String cancelText = AppStrings.cancel,
    Color? confirmColor,
    IconData? icon,
    bool isDangerous = false,
  }) {
    final theme = Theme.of(context);
    final effectiveConfirmColor =
        confirmColor ??
        (isDangerous ? theme.colorScheme.error : theme.colorScheme.primary);

    return show<bool>(
      context: context,
      title: title,
      titleIcon: icon,
      titleIconColor: effectiveConfirmColor,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveConfirmColor,
            foregroundColor: _foregroundOnConfirmBackground(
              theme,
              effectiveConfirmColor,
            ),
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }

  /// Show a selection dialog with options optimized for mobile
  static Future<T?> showSelection<T>({
    required BuildContext context,
    required String title,
    required List<({T value, String label, IconData? icon, String? subtitle})>
    options,
    T? currentValue,
    IconData? titleIcon,
  }) {
    final theme = Theme.of(context);

    return show<T>(
      context: context,
      title: title,
      titleIcon: titleIcon,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final isSelected = option.value == currentValue;
          return Material(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(ctx).pop(option.value);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    if (option.icon != null) ...[
                      Icon(
                        option.icon,
                        size: 22,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (option.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              option.subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MobileBottomSheetWrapper extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final Color? titleIconColor;
  final List<Widget>? actions;
  final double? maxHeight;
  final Widget child;

  const _MobileBottomSheetWrapper({
    this.title,
    this.titleIcon,
    this.titleIconColor,
    this.actions,
    this.maxHeight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final effectiveMaxHeight = maxHeight ?? screenHeight * 0.85;

    return GlassPanel(
      blur: GlassBlur.modal,
      borderRadiusGeometry: const BorderRadius.vertical(
        top: Radius.circular(24),
      ),
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title section
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      if (titleIcon != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (titleIconColor ?? theme.colorScheme.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            titleIcon,
                            color: titleIconColor ?? theme.colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Text(
                          title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Close button
                      Material(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (title != null) const Divider(height: 1),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  physics: AppTheme.scrollPhysicsFor(context),
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
              // Actions
              if (actions != null && actions!.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!
                        .map(
                          (action) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: action,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension to easily show mobile-adaptive dialogs
extension MobileDialogExtension on BuildContext {
  Future<T?> showMobileDialog<T>({
    required Widget Function(BuildContext context) builder,
    String? title,
    IconData? titleIcon,
    List<Widget>? actions,
  }) {
    return MobileAdaptiveDialog.show<T>(
      context: this,
      builder: builder,
      title: title,
      titleIcon: titleIcon,
      actions: actions,
    );
  }

  Future<bool?> showMobileConfirmation({
    required String title,
    required String message,
    String confirmText = AppStrings.confirm,
    String cancelText = AppStrings.cancel,
    bool isDangerous = false,
    IconData? icon,
  }) {
    return MobileAdaptiveDialog.showConfirmation(
      context: this,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDangerous: isDangerous,
      icon: icon,
    );
  }
}
