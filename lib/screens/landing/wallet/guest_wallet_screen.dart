import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class GuestWalletScreen extends ConsumerWidget {
  const GuestWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pad = AppTheme.isDesktop(context)
        ? AppTheme.kSpacingXLarge
        : AppTheme.kSpacingMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(
                children: [
                  Text('Available balance',
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  AnimatedCountUp(
                    endValue: 0,
                    prefix: '\u20B9',
                    style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add),
                          label: const Text('Top up')),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.send),
                          label: const Text('Transfer')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeInWidget(
              delay: const Duration(milliseconds: 100),
              child: Text('Quick top-up',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            FadeInWidget(
              delay: const Duration(milliseconds: 200),
              child: Row(
              children: [
                for (final amt in [100, 500, 1000, 2000])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                          onPressed: () {},
                          child: Text('\u20B9$amt')),
                    ),
                  ),
              ],
            ),
            ),
            const SizedBox(height: 24),
            FadeInWidget(
              delay: const Duration(milliseconds: 300),
              child: Text('Gift cards',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            FadeInWidget(
              delay: const Duration(milliseconds: 400),
              child: AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading:
                    Icon(Icons.card_giftcard, color: theme.colorScheme.primary),
                title: const Text('Redeem gift card'),
                subtitle: const Text('Enter a gift card code to add balance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ),
            ),
            const SizedBox(height: 8),
            FadeInWidget(
              delay: const Duration(milliseconds: 450),
              child: AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.card_giftcard,
                    color: theme.colorScheme.tertiary),
                title: const Text('Buy a gift card'),
                subtitle:
                    const Text('Send a gift card to someone special'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ),
            ),
            const SizedBox(height: 24),
            FadeInWidget(
              delay: const Duration(milliseconds: 500),
              child: Text('Transactions',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            FadeInWidget(
              delay: const Duration(milliseconds: 600),
              child: AppCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('No transactions yet',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Your wallet transactions will appear here',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
            const SizedBox(height: 24),
            FadeInWidget(
              delay: const Duration(milliseconds: 700),
              child: Text('Settings',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            FadeInWidget(
              delay: const Duration(milliseconds: 800),
              child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Auto top-up'),
                    subtitle: const Text(
                        'Automatically add funds when balance is low'),
                    value: false,
                    onChanged: (_) {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Payment security'),
                    subtitle:
                        const Text('PIN / biometric for payments'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
