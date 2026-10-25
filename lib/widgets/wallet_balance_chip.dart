import 'package:flutter/material.dart';

class WalletBalanceChip extends StatelessWidget {
  final double balance;

  const WalletBalanceChip({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLow = balance < 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isLow
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.primaryContainer)
            .withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 14,
            color: isLow
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            '\u20B9${balance.toStringAsFixed(0)}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isLow
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
