import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/finance.dart';
import '../../providers/tenant_provider.dart';
import '../../services/finance_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class FinanceHubScreen extends ConsumerStatefulWidget {
  const FinanceHubScreen({super.key});

  @override
  ConsumerState<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

class _FinanceHubScreenState extends ConsumerState<FinanceHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Cash register'),
            Tab(text: 'Petty cash'),
            Tab(text: 'Budget'),
            Tab(text: 'Vendor payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _CashRegisterTab(),
          _PettyCashTab(),
          _BudgetTab(),
          _VendorPaymentsTab(),
        ],
      ),
    );
  }
}

class _CashRegisterTab extends ConsumerWidget {
  const _CashRegisterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return StreamBuilder<List<CashRegisterEntry>>(
      stream: FinanceService(tenant).watchCashRegister(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final entries = snap.data ?? [];
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.point_of_sale_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No cash register entries',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final e in entries) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        e.type.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${e.date.day}/${e.date.month}/${e.date.year}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _miniStat(theme, 'Opening',
                            '\u20B9${e.openingBalance.toStringAsFixed(0)}'),
                        _miniStat(theme, 'Cash In',
                            '\u20B9${e.cashIn.toStringAsFixed(0)}'),
                        _miniStat(theme, 'Cash Out',
                            '\u20B9${e.cashOut.toStringAsFixed(0)}'),
                        _miniStat(theme, 'Closing',
                            '\u20B9${e.closingBalance.toStringAsFixed(0)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${e.staffName}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _miniStat(ThemeData theme, String label, String value) => Column(
        children: [
          Text(value,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      );
}

class _PettyCashTab extends ConsumerWidget {
  const _PettyCashTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return StreamBuilder<List<PettyCashEntry>>(
      stream: FinanceService(tenant).watchPettyCash(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final entries = snap.data ?? [];
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No petty cash entries',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final e in entries) ...[
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Icon(Icons.money,
                      color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.description,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text('Approved by ${e.approvedBy}',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text(
                    '\u20B9${e.amount.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
            ],
          ],
        );
      },
    );
  }
}

class _BudgetTab extends ConsumerWidget {
  const _BudgetTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return StreamBuilder<List<BudgetEntry>>(
      stream: FinanceService(tenant).watchBudgets(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final budgets = snap.data ?? [];
        if (budgets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_outline,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No budgets set', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final b in budgets) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.category,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Planned: \u20B9${b.planned.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          'Actual: \u20B9${b.actual.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: b.actual > b.planned
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: b.planned > 0
                          ? (b.actual / b.planned).clamp(0, 1.5)
                          : 0,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                      color: b.actual > b.planned
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _VendorPaymentsTab extends ConsumerWidget {
  const _VendorPaymentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return StreamBuilder<List<VendorPayment>>(
      stream: FinanceService(tenant).watchVendorPayments(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final payments = snap.data ?? [];
        if (payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payment_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No vendor payments',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        final total = payments.fold(0.0, (s, p) => s + p.amount);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(children: [
                Text('Total vendor payments',
                    style: theme.textTheme.titleSmall),
                Text(
                  '\u20B9${total.toStringAsFixed(0)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.error,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            for (final p in payments) ...[
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.vendorName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${p.method} \u2022 ${p.date.day}/${p.date.month}/${p.date.year}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\u20B9${p.amount.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
            ],
          ],
        );
      },
    );
  }
}
