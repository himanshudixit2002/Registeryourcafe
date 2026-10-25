import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/stock_item.dart';
import '../../models/stock_receipt.dart';
import '../../providers/tenant_provider.dart';
import '../../services/stock_receipt_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_panel.dart';

/// Period for purchase spend (receipts). `null` = from epoch (capped by query limit).
enum _SpendPeriod { d7, d30, d90, all }

class _StockAggregates {
  const _StockAggregates({
    required this.valueAtCost,
    required this.valueAtRetail,
    required this.impliedMarginOnHand,
    required this.itemsMissingCost,
    required this.sellableWithPriceCount,
    required this.valueAtCostCafe,
    required this.valueAtCostMerch,
    required this.valueAtRetailCafe,
    required this.valueAtRetailMerch,
    required this.lowStockCount,
  });

  final double valueAtCost;
  final double valueAtRetail;
  final double impliedMarginOnHand;
  final int itemsMissingCost;
  final int sellableWithPriceCount;
  final double valueAtCostCafe;
  final double valueAtCostMerch;
  final double valueAtRetailCafe;
  final double valueAtRetailMerch;
  final int lowStockCount;
}

class InventoryAnalysisScreen extends ConsumerStatefulWidget {
  const InventoryAnalysisScreen({super.key});

  @override
  ConsumerState<InventoryAnalysisScreen> createState() =>
      _InventoryAnalysisScreenState();
}

class _InventoryAnalysisScreenState
    extends ConsumerState<InventoryAnalysisScreen> {
  _SpendPeriod _spendPeriod = _SpendPeriod.d30;

  static const int _receiptLimit = 1000;

  String _rupee(double v) => '₹${v.toStringAsFixed(2)}';

  Timestamp _receiptFromTimestamp() {
    switch (_spendPeriod) {
      case _SpendPeriod.d7:
        return Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 7)),
        );
      case _SpendPeriod.d30:
        return Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 30)),
        );
      case _SpendPeriod.d90:
        return Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 90)),
        );
      case _SpendPeriod.all:
        return Timestamp.fromMillisecondsSinceEpoch(0);
    }
  }

  _StockAggregates _computeStockAgg(List<StockItem> items) {
    double valueAtCost = 0;
    double valueAtRetail = 0;
    double impliedMarginOnHand = 0;
    int itemsMissingCost = 0;
    int sellableWithPriceCount = 0;
    double valueAtCostCafe = 0;
    double valueAtCostMerch = 0;
    double valueAtRetailCafe = 0;
    double valueAtRetailMerch = 0;
    int lowStockCount = 0;

    for (final it in items) {
      if (it.quantity <= it.lowStockThreshold) {
        lowStockCount++;
      }

      final cost = it.lastUnitCost;
      if (cost != null && cost > 0) {
        final line = it.quantity * cost;
        valueAtCost += line;
        if (it.isMerchandise) {
          valueAtCostMerch += line;
        } else {
          valueAtCostCafe += line;
        }
      } else {
        itemsMissingCost++;
      }

      if (it.isSellable && it.price != null && it.price! > 0) {
        sellableWithPriceCount++;
        final line = it.quantity * it.price!;
        valueAtRetail += line;
        if (it.isMerchandise) {
          valueAtRetailMerch += line;
        } else {
          valueAtRetailCafe += line;
        }

        if (cost != null && cost > 0) {
          impliedMarginOnHand += it.quantity * (it.price! - cost);
        }
      }
    }

    return _StockAggregates(
      valueAtCost: valueAtCost,
      valueAtRetail: valueAtRetail,
      impliedMarginOnHand: impliedMarginOnHand,
      itemsMissingCost: itemsMissingCost,
      sellableWithPriceCount: sellableWithPriceCount,
      valueAtCostCafe: valueAtCostCafe,
      valueAtCostMerch: valueAtCostMerch,
      valueAtRetailCafe: valueAtRetailCafe,
      valueAtRetailMerch: valueAtRetailMerch,
      lowStockCount: lowStockCount,
    );
  }

  String _vendorKey(StockReceipt r) {
    final name = r.vendorNameSnapshot?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (r.vendorId.isNotEmpty) return r.vendorId;
    return 'Unknown vendor';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenant = ref.watch(tenantRefProvider);
    final from = _receiptFromTimestamp();

    if (tenant == null) {
      return const Center(child: Text('No company context'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Purchase spend (receipts)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _periodChip(theme, _SpendPeriod.d7, '7 days'),
              _periodChip(theme, _SpendPeriod.d30, '30 days'),
              _periodChip(theme, _SpendPeriod.d90, '90 days'),
              _periodChip(theme, _SpendPeriod.all, 'All'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tenant.stockItems().orderBy('name').snapshots(),
            builder: (context, stockSnap) {
              if (stockSnap.hasError) {
                return Center(child: Text('Error: ${stockSnap.error}'));
              }
              if (!stockSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = stockSnap.data!.docs
                  .map((d) => StockItem.fromFirestore(d))
                  .toList();
              final stockAgg = _computeStockAgg(items);

              return StreamBuilder<List<StockReceipt>>(
                key: ValueKey<_SpendPeriod>(_spendPeriod),
                stream: StockReceiptService.watchReceiptsFrom(
                  tenant,
                  from: from,
                  limit: _receiptLimit,
                ),
                builder: (context, receiptSnap) {
                  if (receiptSnap.hasError) {
                    return Center(child: Text('Error: ${receiptSnap.error}'));
                  }
                  if (!receiptSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final receipts = receiptSnap.data!;
                  double spendTotal = 0;
                  final vendorTotals = <String, double>{};
                  for (final r in receipts) {
                    spendTotal += r.totalCost;
                    final k = _vendorKey(r);
                    vendorTotals[k] = (vendorTotals[k] ?? 0) + r.totalCost;
                  }
                  final topVendors = vendorTotals.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  final capped =
                      receipts.length >= _receiptLimit &&
                      _spendPeriod == _SpendPeriod.all;

                  return ListView(
                    physics: AppTheme.scrollPhysicsFor(context),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (capped)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Showing the $_receiptLimit most recent receipts. Totals may be incomplete for “All”.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      Text(
                        'Spend in period',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _metricRow(
                        theme,
                        'Receipts',
                        '${receipts.length}',
                        'Total',
                        _rupee(spendTotal),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'On-hand stock (live)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _metricRow(
                        theme,
                        'Value at last cost',
                        _rupee(stockAgg.valueAtCost),
                        'Retail value (sellable)',
                        stockAgg.valueAtRetail > 0
                            ? _rupee(stockAgg.valueAtRetail)
                            : '—',
                      ),
                      const SizedBox(height: 8),
                      _metricRow(
                        theme,
                        'Implied margin on hand',
                        stockAgg.valueAtRetail > 0
                            ? _rupee(stockAgg.impliedMarginOnHand)
                            : '—',
                        'Low stock rows',
                        '${stockAgg.lowStockCount}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Items missing unit cost: ${stockAgg.itemsMissingCost} · Sellable with price: ${stockAgg.sellableWithPriceCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'By channel (on-hand)',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _metricRow(
                        theme,
                        'Cafe at cost',
                        _rupee(stockAgg.valueAtCostCafe),
                        'Merch at cost',
                        _rupee(stockAgg.valueAtCostMerch),
                      ),
                      const SizedBox(height: 8),
                      _metricRow(
                        theme,
                        'Cafe retail',
                        stockAgg.valueAtRetailCafe > 0
                            ? _rupee(stockAgg.valueAtRetailCafe)
                            : '—',
                        'Merch retail',
                        stockAgg.valueAtRetailMerch > 0
                            ? _rupee(stockAgg.valueAtRetailMerch)
                            : '—',
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Top vendors by spend (period)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (topVendors.isEmpty)
                        Text(
                          'No receipts in this range.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        ...topVendors
                            .take(10)
                            .map(
                              (e) => AppSurface(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                  title: Text(e.key),
                                  trailing: Text(
                                    _rupee(e.value),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _periodChip(ThemeData theme, _SpendPeriod p, String label) {
    final selected = _spendPeriod == p;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _spendPeriod = p),
      showCheckmark: false,
      selectedColor: theme.colorScheme.primaryContainer,
    );
  }

  Widget _metricRow(
    ThemeData theme,
    String aLabel,
    String aValue,
    String bLabel,
    String bValue,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _metricCell(theme, aLabel, aValue)),
        const SizedBox(width: 12),
        Expanded(child: _metricCell(theme, bLabel, bValue)),
      ],
    );
  }

  Widget _metricCell(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
