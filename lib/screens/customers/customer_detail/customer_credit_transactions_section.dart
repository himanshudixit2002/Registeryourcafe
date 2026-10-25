import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/customer.dart';
import '../../../providers/ledger_provider.dart';
import '../../../providers/tenant_provider.dart';
import '../../../services/whatsapp_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_panel.dart';
import '../../../widgets/credit_transaction_tile.dart';

typedef ReconcileCreditsFn = Future<void> Function(
  Customer customer,
  double ledgerBalance,
);

/// Expandable credit ledger, mismatch reconcile, and WhatsApp export.
class CustomerCreditTransactionsSection extends ConsumerWidget {
  const CustomerCreditTransactionsSection({
    super.key,
    required this.customer,
    this.canCustomersAdmin = true,
    required this.onReconcileCredits,
  });

  final Customer customer;
  final bool canCustomersAdmin;
  final ReconcileCreditsFn onReconcileCredits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(customerCreditLedgerProvider(customer.id));
    final tenant = ref.watch(tenantRefProvider);
    final theme = Theme.of(context);

    Widget buildMetric(String label, double value, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(0),
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return AppSurface(
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: false,
            title: Text(
              'Credit Transactions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              const SizedBox(height: AppTheme.kSpacingMedium),
              txAsync.when(
                data: (txs) {
                  if (tenant == null) {
                    return const ListTile(
                      dense: true,
                      leading: Icon(Icons.business_rounded),
                      title: Text('No company context'),
                    );
                  }
                  if (txs.isEmpty) {
                    return const ListTile(
                      dense: true,
                      leading: Icon(Icons.history_rounded),
                      title: Text('No credit transactions found.'),
                    );
                  }

                  final totalAdded = txs
                      .where((t) => t.amount >= 0)
                      .fold<double>(0, (p, t) => p + t.amount);
                  final totalUsed = txs
                      .where((t) => t.amount < 0)
                      .fold<double>(0, (p, t) => p + t.amount.abs());
                  final balance = totalAdded - totalUsed;

                  return Column(
                    children: [
                      if ((balance - customer.credits).abs() >= 0.5)
                        AppSurface(
                          margin: const EdgeInsets.only(
                            bottom: AppTheme.kSpacingMedium,
                          ),
                          padding: const EdgeInsets.all(AppTheme.kSpacingSmall),
                          borderColor: theme.colorScheme.tertiary
                              .withValues(alpha: 0.45),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.tertiary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Credits mismatch detected',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      canCustomersAdmin
                                          ? 'Profile shows ${customer.credits.toStringAsFixed(0)} but ledger balance is ${balance.toStringAsFixed(0)}. You can reconcile to fix display everywhere.'
                                          : 'Profile shows ${customer.credits.toStringAsFixed(0)} but ledger balance is ${balance.toStringAsFixed(0)}. Ask a customer admin to reconcile.',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (canCustomersAdmin) ...[
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await onReconcileCredits(
                                      customer,
                                      balance,
                                    );
                                    if (!context.mounted) return;
                                    final cs = Theme.of(context).colorScheme;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: cs.primaryContainer,
                                        content: Text(
                                          'Credits reconciled to ledger balance',
                                          style: TextStyle(
                                            color: cs.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.sync),
                                  label: const Text('Reconcile'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        theme.colorScheme.tertiary,
                                    foregroundColor:
                                        theme.colorScheme.onTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (canCustomersAdmin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Send All via WhatsApp'),
                            onPressed: () async {
                            if (customer.phoneNumber.isEmpty) {
                              final cs = Theme.of(context).colorScheme;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: cs.tertiaryContainer,
                                  content: Text(
                                    'Customer phone not found',
                                    style: TextStyle(
                                      color: cs.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                              );
                              return;
                            }
                            final buffer = StringBuffer();
                            buffer.writeln('Registeryourcafe – Credit Ledger');
                            buffer.writeln('Customer: ${customer.name}');
                            buffer.writeln(
                              'Date: ${DateFormat.yMMMd().format(DateTime.now())}\n',
                            );

                            for (final t in txs.take(50).toList().reversed) {
                              final sign = t.amount >= 0 ? '+' : '-';
                              final amt = t.amount.abs().toStringAsFixed(0);
                              final dateStr = DateFormat(
                                'dd/MM/yy',
                              ).add_jm().format(t.date);
                              buffer.writeln(
                                '$dateStr  $sign$amt  (${t.paymentMethod.name.toUpperCase()})',
                              );
                              if ((t.note ?? '').isNotEmpty) {
                                buffer.writeln('  • ${t.note}');
                              }
                            }

                            buffer.writeln(
                              '\nBalance: ${balance.toStringAsFixed(0)}',
                            );
                            buffer.writeln('\nThank you!');

                            try {
                              await WhatsAppService.sendMessage(
                                rawPhone: customer.phoneNumber,
                                message: buffer.toString(),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              final cs = Theme.of(context).colorScheme;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: cs.errorContainer,
                                  content: Text(
                                    e.toString(),
                                    style: TextStyle(
                                      color: cs.onErrorContainer,
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          ),
                        ),
                      AppSurface(
                        margin: const EdgeInsets.only(
                          bottom: AppTheme.kSpacingMedium,
                        ),
                        padding: const EdgeInsets.all(AppTheme.kSpacingSmall),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            buildMetric(
                              'Added',
                              totalAdded,
                              theme.colorScheme.tertiary,
                            ),
                            buildMetric(
                              'Used',
                              totalUsed,
                              theme.colorScheme.error,
                            ),
                            buildMetric(
                              'Balance',
                              balance,
                              theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: txs.length,
                        separatorBuilder: (c, _) => Divider(
                          thickness: 1,
                          color: AppTheme.subtleDividerColor(Theme.of(c)),
                        ),
                        itemBuilder: (context, index) {
                          final tx = txs[index];
                          return CreditTransactionTile(tx: tx, tenant: tenant);
                        },
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Error loading transactions: $err'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
