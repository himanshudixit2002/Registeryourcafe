import 'package:flutter/material.dart';
import '../../theme/app_theme.dart'; // Assuming AppTheme is in lib/theme
import 'package:registeryourcafe/constants/app_strings.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final Color? confirmButtonColor;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = AppStrings.confirm,
    this.cancelText = AppStrings.cancel,
    required this.onConfirm,
    this.confirmButtonColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
      ),
      title: Text(title, style: theme.textTheme.titleLarge),
      content: Text(content, style: theme.textTheme.bodyMedium),
      actions: <Widget>[
        TextButton(
          child: Text(cancelText),
          onPressed: () => Navigator.of(context).pop(false), // Returns false
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                confirmButtonColor ??
                theme
                    .colorScheme
                    .error, // Default to error color for destructive actions
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop(true); // Returns true
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}
