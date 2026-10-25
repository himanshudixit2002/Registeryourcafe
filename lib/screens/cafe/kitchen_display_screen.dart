import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firestore/tenant_firestore.dart';
import '../../models/venue_ui_config.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';

final _kdsOrdersProvider = StreamProvider.family<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>, TenantRef>(
  (ref, tenant) {
    return tenant
        .cafeOrders()
        .where('status', whereIn: ['pending', 'preparing'])
        .orderBy('createdAt', descending: false)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs);
  },
);

class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  ConsumerState<KitchenDisplayScreen> createState() =>
      _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  Timer? _clockTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenant = ref.watch(tenantRefProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.kitchen, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(ref.watch(venueKindProvider).kitchenTitle),
            const Spacer(),
            Text(
              _currentTime,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Immersive mode',
            onPressed: () => SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.immersiveSticky,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen_exit),
            tooltip: 'Normal mode',
            onPressed: () => SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.edgeToEdge,
            ),
          ),
        ],
      ),
      body: tenant == null
          ? const Center(child: Text('No workspace loaded'))
          : _buildGrid(context, tenant),
    );
  }

  Widget _buildGrid(BuildContext context, TenantRef tenant) {
    final theme = Theme.of(context);
    final docsAsync = ref.watch(_kdsOrdersProvider(tenant));

    return docsAsync.when(
      loading: () => const ShimmerList(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (docs) {
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'All caught up!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No pending kitchen orders',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 1200
                ? 4
                : (constraints.maxWidth > 800
                    ? 3
                    : (constraints.maxWidth > 500 ? 2 : 1));
            return GridView.builder(
              physics: AppTheme.scrollPhysicsFor(context),
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: docs.length,
              itemBuilder: (context, i) =>
                  _KdsCard(doc: docs[i], tenant: tenant),
            );
          },
        );
      },
    );
  }
}

class _KdsCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final TenantRef tenant;

  const _KdsCard({required this.doc, required this.tenant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = doc.data();
    final status = data['status'] as String? ?? 'pending';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final elapsed = createdAt != null
        ? DateTime.now().difference(createdAt)
        : Duration.zero;
    final isUrgent = elapsed.inMinutes > 15;
    final borderColor = isUrgent
        ? theme.colorScheme.error
        : (status == 'preparing' ? Colors.orange : theme.colorScheme.primary);
    final tableName = data['tableName'] as String?;
    final customerName = data['customerName'] as String?;
    final items = data['items'] as List<dynamic>? ?? [];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: isUrgent ? 3 : 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${doc.id.length > 6 ? doc.id.substring(0, 6).toUpperCase() : doc.id.toUpperCase()}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: borderColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (isUrgent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${elapsed.inMinutes}m',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onError,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Text(
                    '${elapsed.inMinutes}m',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (tableName != null && tableName.isNotEmpty)
              Text(
                tableName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (customerName != null && customerName.isNotEmpty)
              Text(
                customerName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const Divider(height: 14),
            Expanded(
              child: ListView(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '${(item is Map ? item['quantity'] : 1) ?? 1}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (item is Map ? item['name'] as String? : null) ??
                                  'Item',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (status == 'pending')
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _updateStatus(context, 'preparing'),
                      child: const Text('Start'),
                    ),
                  ),
                if (status == 'preparing')
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _updateStatus(context, 'ready'),
                      child: const Text('Ready'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      await tenant.cafeOrders().doc(doc.id).update({'status': newStatus});
      if (context.mounted) {
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (context.mounted) context.showErrorSnackbar('Failed: $e');
    }
  }
}
