import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class SAGuestOrdersScreen extends ConsumerStatefulWidget {
  const SAGuestOrdersScreen({super.key});

  @override
  ConsumerState<SAGuestOrdersScreen> createState() => _SAGuestOrdersScreenState();
}

class _SAGuestOrdersScreenState extends ConsumerState<SAGuestOrdersScreen> {
  String _search = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ordersAsync = ref.watch(allGuestOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guest Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allGuestOrdersProvider),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Error loading orders', style: TextStyle(color: cs.error)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(allGuestOrdersProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (orders) {
          int pending = 0, converted = 0, cancelled = 0;
          for (final o in orders) {
            switch (o.data()['status'] as String? ?? 'pending') {
              case 'pending': pending++;
              case 'converted': converted++;
              case 'cancelled': cancelled++;
            }
          }

          final filtered = orders.where((doc) {
            final d = doc.data();
            final status = d['status'] as String? ?? 'pending';
            if (_statusFilter != 'all' && status != _statusFilter) return false;
            if (_search.isEmpty) return true;
            final q = _search.toLowerCase();
            final guestName = (d['guestName'] as String? ?? '').toLowerCase();
            final companyId = (doc.reference.parent.parent?.id ?? '').toLowerCase();
            return guestName.contains(q) || companyId.contains(q);
          }).toList();

          if (orders.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 16), Text('No guest orders', style: theme.textTheme.titleMedium),
            ]));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _StatCard(label: 'Total', count: orders.length, color: cs.primary)),
                    SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _StatCard(label: 'Pending', count: pending, color: AppTheme.warningColor)),
                    SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _StatCard(label: 'Converted', count: converted, color: AppTheme.successColor)),
                    SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _StatCard(label: 'Cancelled', count: cancelled, color: cs.error)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.kSpacingMedium),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by guest name or company...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: AppTheme.kSpacingSmall),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.kSpacingMedium),
                child: Row(
                  children: [
                    for (final entry in {'all': 'All', 'pending': 'Pending', 'converted': 'Converted', 'cancelled': 'Cancelled'}.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(entry.value),
                          selected: _statusFilter == entry.key,
                          onSelected: (_) => setState(() => _statusFilter = entry.key),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.kSpacingSmall),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('No orders match your filters', style: TextStyle(color: cs.onSurfaceVariant)))
                    : ListView.separated(
                        physics: AppTheme.scrollPhysicsFor(context),
                        padding: EdgeInsets.all(AppTheme.isDesktop(context) ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => FadeInWidget(
                          delay: Duration(milliseconds: 50 * i),
                          child: _OrderCard(doc: filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatCard({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        children: [
          AnimatedCountUp(
            endValue: count.toDouble(),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _OrderCard({required this.doc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final d = doc.data();
    final companyId = doc.reference.parent.parent?.id ?? '';
    final status = d['status'] as String? ?? 'pending';
    final guestName = d['guestName'] as String? ?? 'Guest';
    final items = d['items'] as List? ?? [];
    final total = d['total'] is num ? (d['total'] as num).toDouble() : 0.0;
    final orderMode = d['orderMode'] as String? ?? '';
    final createdAt = d['createdAt'];

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'pending':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.hourglass_top;
      case 'converted':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
      case 'cancelled':
        statusColor = cs.error;
        statusIcon = Icons.cancel;
      default:
        statusColor = cs.onSurfaceVariant;
        statusIcon = Icons.help_outline;
    }

    String dateStr = '';
    if (createdAt is Timestamp) {
      dateStr = DateFormat.yMMMd().add_jm().format(createdAt.toDate());
    }

    return AppCard(
      onTap: () => _showOrderDetail(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(guestName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      '${items.length} items \u2022 \u20B9${total.toStringAsFixed(0)} \u2022 $orderMode',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: status.toUpperCase(), color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (companyId.isNotEmpty)
                Expanded(
                  child: Text(
                    'Cafe: ${companyId.length > 12 ? '${companyId.substring(0, 12)}...' : companyId}',
                    style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
            ],
          ),
        ],
      ),
    );
  }

  void _showOrderDetail(BuildContext context, WidgetRef ref) {
    final d = doc.data();
    final companyId = doc.reference.parent.parent?.id ?? '';
    final status = d['status'] as String? ?? 'pending';
    final guestName = d['guestName'] as String? ?? 'Guest';
    final guestPhone = d['guestPhone'] as String? ?? '';
    final items = d['items'] as List? ?? [];
    final total = d['total'] is num ? (d['total'] as num).toDouble() : 0.0;
    final orderMode = d['orderMode'] as String? ?? '';
    final tableName = d['tableName'] as String? ?? '';
    final guestNotes = d['guestNotes'] as String? ?? '';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Order Details', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              _DetailRow(label: 'Guest', value: guestName),
              if (guestPhone.isNotEmpty) _DetailRow(label: 'Phone', value: guestPhone),
              _DetailRow(label: 'Mode', value: orderMode),
              if (tableName.isNotEmpty) _DetailRow(label: 'Table', value: tableName),
              _DetailRow(label: 'Status', value: status),
              _DetailRow(label: 'Company', value: companyId),
              _DetailRow(label: 'Total', value: '\u20B9${total.toStringAsFixed(2)}'),
              if (guestNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Notes', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(guestNotes, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
              const SizedBox(height: 16),
              Text('Items (${items.length})', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (item is Map) ? (item['name'] as String? ?? 'Item') : 'Item',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (item is Map && item['qty'] != null)
                          Text('x${item['qty']}', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(width: 12),
                        if (item is Map && item['price'] != null)
                          Text(
                            '\u20B9${(item['price'] is num ? (item['price'] as num).toStringAsFixed(0) : '0')}',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                ),
              if (status == 'pending') ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dlg) => AlertDialog(
                          title: const Text('Cancel order?'),
                          content: const Text('This will cancel the guest order.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dlg, false), child: const Text('No')),
                            FilledButton(
                              onPressed: () => Navigator.pop(dlg, true),
                              style: FilledButton.styleFrom(backgroundColor: cs.error),
                              child: const Text('Cancel Order'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      try {
                        final service = ref.read(superAdminServiceProvider);
                        await service.cancelGuestOrder(companyId, doc.id);
                        final actorEmail = FirebaseAuth.instance.currentUser?.email ?? '';
                        service.logSuperAdminAction(action: 'guest_order_cancelled', actorEmail: actorEmail, entityType: 'guest_order', entityId: doc.id, details: 'Cancelled order by ${d['guestName'] ?? 'unknown'} in $companyId');
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) context.showSuccessSnackbar('Order cancelled');
                        ref.invalidate(allGuestOrdersProvider);
                      } catch (e) {
                        if (context.mounted) context.showErrorSnackbar('Error: $e');
                      }
                    },
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancel Order'),
                    style: FilledButton.styleFrom(backgroundColor: cs.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
