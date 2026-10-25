import 'package:flutter/material.dart';

import '../../../widgets/glass_modal_bottom_sheet.dart';
import '../../../models/customer.dart';
import '../../../theme/app_theme.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class PaymentDialog extends StatelessWidget {
  final Customer? customer;
  final double totalAmount;

  const PaymentDialog({
    super.key,
    required this.customer,
    required this.totalAmount,
  });

  /// Shows the payment dialog and returns the selected payment method.
  ///
  /// Returns a [PaymentMethod] enum value, or null if cancelled.
  static Future<PaymentMethod?> show(
    BuildContext context, {
    required Customer? customer,
    required double totalAmount,
  }) {
    return showDialog<PaymentMethod>(
      context: context,
      builder: (context) =>
          PaymentDialog(customer: customer, totalAmount: totalAmount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusLarge),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppTheme.kSpacingLarge,
        AppTheme.kSpacingLarge,
        AppTheme.kSpacingLarge,
        AppTheme.kSpacingSmall,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        0.0,
        AppTheme.kSpacingSmall,
        0.0,
        AppTheme.kSpacingLarge,
      ),
      title: Text(
        'Select Payment Method',
        style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPaymentOption(
            context: context,
            icon: Icons.money_outlined,
            title: 'Cash',
            paymentMethod: PaymentMethod.cash,
            color: colorScheme.primary,
          ),
          _buildPaymentOption(
            context: context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'UPI',
            paymentMethod: PaymentMethod.upi,
            color: colorScheme.primary,
          ),
          if (customer != null) _buildCreditsOption(context, colorScheme),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'CANCEL',
            style: textTheme.labelLarge?.copyWith(color: colorScheme.secondary),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required PaymentMethod paymentMethod,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: color, size: 28),
      title: Text(title, style: theme.textTheme.titleMedium),
      onTap: () => Navigator.pop(context, paymentMethod),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.kSpacingLarge,
        vertical: AppTheme.kSpacingSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusSmall),
      ),
      hoverColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
    );
  }

  Widget _buildCreditsOption(BuildContext context, ColorScheme colorScheme) {
    return ListTile(
      leading: Icon(Icons.stars_outlined, color: colorScheme.primary),
      title: const Text('Use Credits'),
      subtitle: Text('(Available: ₹${customer!.credits.toStringAsFixed(2)})'),
      onTap: () => Navigator.pop(context, PaymentMethod.credits),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.kSpacingLarge,
        vertical: AppTheme.kSpacingSmall / 2,
      ),
    );
  }
}

class AttachToSessionSheet extends StatelessWidget {
  final String? customerName;
  final String? tableName;

  const AttachToSessionSheet({
    super.key,
    required this.customerName,
    required this.tableName,
  });

  /// Shows the sheet and returns 'attach', 'pay', or null if dismissed.
  static Future<String?> show(
    BuildContext context, {
    required String? customerName,
    required String? tableName,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AttachToSessionSheet(
        customerName: customerName,
        tableName: tableName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassModalSheetChrome(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Order for ${customerName ?? 'Customer'} on ${tableName ?? 'Table'}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.subtleDividerColor(Theme.of(context)),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Add to Active Session'),
            subtitle: const Text('Total Bill will be updated.'),
            onTap: () => Navigator.pop(context, 'attach'),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Pay Separately Now'),
            subtitle: const Text('Complete this transaction independently.'),
            onTap: () => Navigator.pop(context, 'pay'),
          ),
        ],
      ),
    );
  }
}

class CreditCodeVerificationDialog extends StatefulWidget {
  final String correctCode;

  const CreditCodeVerificationDialog({super.key, required this.correctCode});

  /// Shows the dialog and returns true if verification succeeded.
  static Future<bool> verify(BuildContext context, String correctCode) async {
    if (correctCode.isEmpty) return true; // No code set, skip verification

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreditCodeVerificationDialog(correctCode: correctCode),
    );
    return result ?? false;
  }

  @override
  State<CreditCodeVerificationDialog> createState() =>
      _CreditCodeVerificationDialogState();
}

class _CreditCodeVerificationDialogState
    extends State<CreditCodeVerificationDialog> {
  final _codeController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify Credit Code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Enter 6-digit code',
              errorText: _errorText,
            ),
            maxLength: 6,
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (_codeController.text.trim() == widget.correctCode) {
              Navigator.of(context).pop(true);
            } else {
              setState(() {
                _errorText = 'Invalid code';
              });
            }
          },
          child: const Text(AppStrings.confirm),
        ),
      ],
    );
  }
}
