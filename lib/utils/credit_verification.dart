import 'package:flutter/material.dart';
import '../models/customer.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class CreditVerification {
  CreditVerification._();

  /// Shows a dialog to verify customer's credit code.
  /// Returns true if verification succeeds, false otherwise.
  static Future<bool> verifyCreditCode(
    BuildContext context,
    Customer customer,
  ) async {
    final controller = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Verify Credit Code'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter the 6-digit credit code for ${customer.name}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Enter 6-digit code',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                    maxLength: 6,
                    obscureText: true,
                    autofocus: true,
                    onSubmitted: (_) {
                      if (controller.text.trim() == customer.creditCode) {
                        Navigator.of(ctx).pop(true);
                      } else {
                        setState(() => errorText = 'Invalid code');
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim() == customer.creditCode) {
                      Navigator.of(ctx).pop(true);
                    } else {
                      setState(() => errorText = 'Invalid code');
                    }
                  },
                  child: const Text(AppStrings.confirm),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result ?? false;
  }

  /// Validates credit code format (6 digits).
  static bool isValidCreditCodeFormat(String code) {
    return RegExp(r'^\d{6}$').hasMatch(code.trim());
  }

  /// Generates a random 6-digit credit code.
  static String generateCreditCode() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return (random % 1000000).toString().padLeft(6, '0');
  }
}
