import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/customer.dart';
import '../../models/credit_transaction.dart';
import '../../providers/tenant_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class CustomerWalletScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerWalletScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerWalletScreen> createState() =>
      _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends ConsumerState<CustomerWalletScreen> {
  List<CreditTransaction>? _transactions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    try {
      final snap = await tenant
          .creditTransactions(widget.customer.id)
          .orderBy('date', descending: true)
          .limit(50)
          .get();
      if (mounted) {
        setState(() {
          _transactions =
              snap.docs.map(CreditTransaction.fromFirestore).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = widget.customer;
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: Text('${customer.name}\'s wallet')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingXLarge + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                children: [
                  Text(
                    'Wallet balance',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\u20B9${customer.credits.toStringAsFixed(0)}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: customer.credits > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                  if (customer.creditCode.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Code: ${customer.creditCode}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (customer.hasLowCreditAlert)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Low balance alert enabled',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Transaction history',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const ShimmerList(itemCount: 3)
            else if (_transactions == null || _transactions!.isEmpty)
              AppCard(
                child: Center(
                  child: Text(
                    'No transactions yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (final tx in _transactions!) ...[
                _TransactionTile(transaction: tx),
                const SizedBox(height: 6),
              ],
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final CreditTransaction transaction;
  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = transaction.amount >= 0;
    final note = transaction.note ?? '';
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            isCredit
                ? Icons.add_circle_outline
                : Icons.remove_circle_outline,
            color: isCredit
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.isEmpty
                      ? (isCredit ? 'Top up' : 'Payment')
                      : note,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : ''}\u20B9${transaction.amount.toStringAsFixed(0)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isCredit
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
