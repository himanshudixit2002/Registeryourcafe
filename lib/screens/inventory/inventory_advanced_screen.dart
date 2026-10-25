import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/inventory_advanced.dart';
import '../../providers/tenant_provider.dart';
import '../../services/inventory_advanced_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class InventoryAdvancedScreen extends ConsumerStatefulWidget {
  const InventoryAdvancedScreen({super.key});

  @override
  ConsumerState<InventoryAdvancedScreen> createState() =>
      _InventoryAdvancedScreenState();
}

class _InventoryAdvancedScreenState
    extends ConsumerState<InventoryAdvancedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
        title: const Text('Inventory advanced'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Purchase orders'),
            Tab(text: 'Expiry tracking'),
            Tab(text: 'Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _POTab(),
          _ExpiryTab(),
          _AlertsTab(),
        ],
      ),
    );
  }
}

class _POTab extends ConsumerWidget {
  const _POTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<PurchaseOrder>>(
      stream: InventoryAdvancedService(tenant).watchPurchaseOrders(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final orders = snap.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No purchase orders',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final po = orders[i];
            return AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(
                  po.vendorName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${po.items.length} items \u2022 \u20B9${po.totalAmount.toStringAsFixed(0)} \u2022 ${po.status}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (s) async {
                    await InventoryAdvancedService(tenant)
                        .updatePOStatus(po.id, s);
                    if (context.mounted) {
                      context.showSuccessSnackbar('Updated');
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'sent', child: Text('Mark Sent')),
                    PopupMenuItem(
                      value: 'received',
                      child: Text('Mark Received'),
                    ),
                    PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExpiryTab extends ConsumerWidget {
  const _ExpiryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<ExpiryRecord>>(
      stream: InventoryAdvancedService(tenant).watchExpiringItems(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final records = snap.data ?? [];
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_available,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No items expiring soon',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = records[i];
            final isExpired = r.expiryDate.isBefore(DateTime.now());
            return AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: isExpired
                        ? theme.colorScheme.error
                        : Colors.orange,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.itemName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Batch: ${r.batchId} \u2022 Qty: ${r.quantity}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${r.expiryDate.day}/${r.expiryDate.month}/${r.expiryDate.year}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isExpired
                          ? theme.colorScheme.error
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('Stock alerts', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Configure low-stock thresholds per item\nfrom inventory settings.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
