import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/order_config.dart';
import '../../providers/tenant_provider.dart';
import '../../services/order_management_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class OrderManagementScreen extends ConsumerStatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  ConsumerState<OrderManagementScreen> createState() =>
      _OrderManagementScreenState();
}

class _OrderManagementScreenState extends ConsumerState<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pre-orders'),
            Tab(text: 'Tips'),
            Tab(text: 'Queue'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PreOrdersTab(),
          _TipsTab(),
          _OrderQueueTab(),
        ],
      ),
    );
  }
}

class _PreOrdersTab extends ConsumerWidget {
  const _PreOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const Center(child: Text('No workspace'));
    final theme = Theme.of(context);
    return StreamBuilder<List<PreOrder>>(
      stream: OrderManagementService(tenant).watchPreOrders(),
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
                Icon(Icons.schedule_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No pre-orders', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final o = orders[i];
            return AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(
                  o.customerName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${o.scheduledFor.day}/${o.scheduledFor.month} '
                  '${o.scheduledFor.hour}:${o.scheduledFor.minute.toString().padLeft(2, '0')} '
                  '\u2022 ${o.items.length} items \u2022 ${o.status}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (s) async {
                    await OrderManagementService(tenant)
                        .updatePreOrderStatus(o.id, s);
                    if (context.mounted) {
                      context.showSuccessSnackbar('Status updated');
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'confirmed', child: Text('Confirm')),
                    PopupMenuItem(
                        value: 'preparing', child: Text('Preparing')),
                    PopupMenuItem(value: 'ready', child: Text('Ready')),
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

class _TipsTab extends ConsumerWidget {
  const _TipsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const Center(child: Text('No workspace'));
    final theme = Theme.of(context);
    return StreamBuilder<List<TipRecord>>(
      stream: OrderManagementService(tenant).watchTips(),
      builder: (context, snap) {
        final tips = snap.data ?? [];
        if (tips.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No tips recorded', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        final total = tips.fold(0.0, (s, t) => s + t.amount);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                children: [
                  Text('Total tips', style: theme.textTheme.titleSmall),
                  Text(
                    '\u20B9${total.toStringAsFixed(0)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final t in tips) ...[
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.volunteer_activism,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Order #${t.orderId.length > 6 ? t.orderId.substring(0, 6) : t.orderId}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '\u20B9${t.amount.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
        );
      },
    );
  }
}

class _OrderQueueTab extends ConsumerWidget {
  const _OrderQueueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_outlined,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Order queue', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Active orders are managed from the Cafe screen.\n'
            'This view shows the priority queue.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
