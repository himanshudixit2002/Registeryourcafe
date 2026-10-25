import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

import '../../models/stock_item.dart';
import '../../providers/tenant_provider.dart';
import '../../theme/app_theme.dart';
import 'stock_item_cost_history_screen.dart';
import '../../widgets/glass_panel.dart';

class InventoryPricingScreen extends ConsumerStatefulWidget {
  const InventoryPricingScreen({super.key});

  @override
  ConsumerState<InventoryPricingScreen> createState() =>
      _InventoryPricingScreenState();
}

class _InventoryPricingScreenState
    extends ConsumerState<InventoryPricingScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _marginLabel(StockItem it) {
    final sell = it.price;
    final cost = it.lastUnitCost;
    if (sell == null || sell <= 0 || cost == null) return null;
    final pct = ((sell - cost) / sell) * 100;
    return '${pct.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenant = ref.watch(tenantRefProvider);

    if (tenant == null) {
      return const Center(child: Text('No company context'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: AppTheme.baseInputDecoration.copyWith(
              hintText: 'Search all stock items…',
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tenant.stockItems().orderBy('name').snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var items = snap.data!.docs
                  .map((d) => StockItem.fromFirestore(d))
                  .toList();
              if (_query.isNotEmpty) {
                items = items
                    .where((it) => it.name.toLowerCase().contains(_query))
                    .toList();
              }

              if (items.isEmpty) {
                return const Center(child: Text('No items'));
              }

              return ListView.separated(
                physics: AppTheme.scrollPhysicsFor(context),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final it = items[i];
                  final channel = it.isMerchandise ? 'Merchandise' : 'Cafe';
                  final margin = _marginLabel(it);
                  return AppSurface(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                it.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cost history',
                              icon: const Icon(Icons.history_rounded),
                              onPressed: () {
                                Navigator.of(context).push(
                                  AppMaterialPageRoute<void>(
                                    builder: (_) => StockItemCostHistoryScreen(
                                      stockItemId: it.id,
                                      itemName: it.name,
                                    ),
                                  ),
                                );
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                channel,
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _cell(
                              theme,
                              'Qty',
                              '${it.quantity.toStringAsFixed(it.unit == 'piece' || it.unit == 'pcs' ? 0 : 1)} ${it.unit}',
                            ),
                            _cell(
                              theme,
                              'Last cost',
                              it.lastUnitCost != null
                                  ? '\u20B9${it.lastUnitCost!.toStringAsFixed(2)}'
                                  : '—',
                            ),
                            _cell(
                              theme,
                              'Sell',
                              it.price != null
                                  ? '\u20B9${it.price!.toStringAsFixed(2)}'
                                  : '—',
                            ),
                            _cell(theme, 'Margin', margin ?? '—'),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cell(ThemeData theme, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
