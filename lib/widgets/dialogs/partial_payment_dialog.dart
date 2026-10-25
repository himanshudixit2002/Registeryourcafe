import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class PartialPaymentDialog extends ConsumerWidget {
  final double totalAmount;
  final double availableCredits;

  const PartialPaymentDialog({
    super.key,
    required this.totalAmount,
    required this.availableCredits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final TextEditingController creditsController = TextEditingController(
      text: availableCredits.toStringAsFixed(2),
    );
    double creditsToUse = availableCredits > totalAmount
        ? totalAmount
        : availableCredits;

    return AlertDialog(
      title: const Text('Split Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total: ₹${totalAmount.toStringAsFixed(2)}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text('Available Credits: ₹${availableCredits.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          TextField(
            controller: creditsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Credits to use'),
            onChanged: (val) {
              final parsed = double.tryParse(val) ?? 0.0;
              creditsToUse = parsed.clamp(0, availableCredits);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Remaining Payable: ₹${(totalAmount - creditsToUse).toStringAsFixed(2)}',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.money),
          label: const Text('Pay Cash'),
          onPressed: () {
            Navigator.of(context).pop({
              'credits': creditsToUse,
              'cash': totalAmount - creditsToUse,
            });
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.qr_code),
          label: const Text('Pay UPI'),
          onPressed: () {
            Navigator.of(
              context,
            ).pop({'credits': creditsToUse, 'upi': totalAmount - creditsToUse});
          },
        ),
      ],
    );
  }
}
