import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/permission_id.dart';
import '../../../firestore/tenant_firestore.dart';
import '../../../models/cafe_order.dart';
import '../../../models/customer.dart';
import '../../../models/merchandise_order.dart';
import '../../../models/session.dart';
import '../../../models/table.dart';
import '../../../models/venue_ui_config.dart';
import '../../../providers/company_module_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/table_provider.dart';
import '../../../providers/tenant_provider.dart';
import '../../../theme/app_theme.dart';
import '../../cafe/cafe_screen.dart';
import '../session_checkout_flow.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

/// Staff-focused UI for an active restaurant / dining table session (orders + checkout).
class DiningSessionScreen extends ConsumerStatefulWidget {
  final TableSession session;
  final SnookerTable table;
  final String customerId;

  const DiningSessionScreen({
    super.key,
    required this.session,
    required this.table,
    required this.customerId,
  });

  @override
  ConsumerState<DiningSessionScreen> createState() =>
      _DiningSessionScreenState();
}

class _DiningSessionScreenState extends ConsumerState<DiningSessionScreen> {
  final _currency = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 2);

  Future<bool> _canCancelSession(TenantRef? tenant, TableSession live) async {
    if (tenant == null) return false;
    final diff = DateTime.now().difference(live.startTime);
    if (diff.inMinutes >= 3) return false;

    final cafeOrders = await tenant
        .cafeOrders()
        .where('sessionId', isEqualTo: live.id)
        .limit(1)
        .get();
    if (cafeOrders.docs.isNotEmpty) return false;
    final merchOrders = await tenant
        .merchandiseOrders()
        .where('sessionId', isEqualTo: live.id)
        .limit(1)
        .get();
    if (merchOrders.docs.isNotEmpty) return false;
    return true;
  }

  Future<void> _tryCancelSession(TableSession live) async {
    final tenant = ref.read(tenantRefProvider);
    final canCancel = await _canCancelSession(tenant, live);
    if (!mounted) return;
    if (!canCancel) {
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cancel only within 3 minutes and before any orders are added.',
            style: TextStyle(color: cs.onTertiaryContainer),
          ),
          backgroundColor: cs.tertiaryContainer,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel seating'),
        content: const Text('Free this table and cancel this seating session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await ref
          .read(tableServiceProvider)
          .cancelSession(session: live, table: widget.table);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Seating cancelled',
            style: TextStyle(color: cs.onTertiaryContainer),
          ),
          backgroundColor: cs.tertiaryContainer,
        ),
      );
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not cancel: $e',
              style: TextStyle(color: cs.onErrorContainer),
            ),
            backgroundColor: cs.errorContainer,
          ),
        );
      }
    }
  }

  ({Color color, IconData icon}) _cafeStatusVisual(
    ThemeData theme,
    String status,
  ) {
    final cs = theme.colorScheme;
    switch (status.toLowerCase()) {
      case 'pending':
        return (color: cs.tertiary, icon: Icons.schedule_rounded);
      case 'preparing':
        return (color: cs.primary, icon: Icons.restaurant_rounded);
      case 'ready':
        return (
          color: cs.secondary,
          icon: Icons.check_circle_outline_rounded,
        );
      case 'delivered':
        return (color: cs.onSurfaceVariant, icon: Icons.done_all_rounded);
      default:
        return (
          color: cs.outline,
          icon: Icons.receipt_long_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenant = ref.watch(tenantRefProvider);
    final customerAsync = ref.watch(singleCustomerProvider(widget.customerId));
    final isMobile = AppTheme.isMobile(context);

    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dining')),
        body: const Center(child: Text('No company context')),
      );
    }

    if (!ref.watchResolvedPermissions().can(PermissionIds.navTables)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dining')),
        body: const Center(
          child: Text('You do not have access to table sessions.'),
        ),
      );
    }

    final accent = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest.withValues(
        alpha: 0.97,
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, size: 20, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.table.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              'Dining session',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {});
              final cs = Theme.of(context).colorScheme;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Totals update automatically',
                    style: TextStyle(color: cs.onInverseSurface),
                  ),
                  duration: const Duration(seconds: 1),
                  backgroundColor: cs.inverseSurface,
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'cancel') {
                final doc = await tenant
                    .sessions()
                    .doc(widget.session.id)
                    .get();
                if (doc.exists && mounted) {
                  await _tryCancelSession(TableSession.fromFirestore(doc));
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'cancel',
                child: ListTile(
                  leading: Icon(Icons.cancel_outlined),
                  title: Text('Cancel seating'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: tenant.sessions().doc(widget.session.id).snapshots(),
        builder: (context, sessionSnap) {
          if (sessionSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load session.\n${sessionSnap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!sessionSnap.hasData || !sessionSnap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final live = TableSession.fromFirestore(sessionSnap.data!);
          if (live.status != SessionStatus.active) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).pop(true);
            });
            return const Center(child: Text('Session ended'));
          }

          final cafeTotal = live.totalCafeAmount ?? 0;
          final merchTotal = live.totalMerchandiseAmount ?? 0;
          final ordersTotal = cafeTotal + merchTotal;

          return RefreshIndicator(
            color: accent,
            onRefresh: () async {
              await HapticFeedback.mediumImpact();
              await Future<void>.delayed(const Duration(milliseconds: 350));
            },
            child: ListView(
              physics: AppTheme.scrollPhysicsFor(context),
              padding: EdgeInsets.fromLTRB(
                isMobile ? 12 : 20,
                0,
                isMobile ? 12 : 20,
                isMobile ? 100 : 120,
              ),
              children: [
                customerAsync.when(
                  data: (customer) => customer != null
                      ? _PartyHeaderCard(customer: customer, accent: accent)
                      : _InfoBanner(
                          icon: Icons.person_off_outlined,
                          message: 'Customer record not found',
                          color: theme.colorScheme.errorContainer,
                        ),
                  loading: () => const LinearProgressIndicator(minHeight: 3),
                  error: (_, _) => _InfoBanner(
                    icon: Icons.error_outline,
                    message: 'Could not load customer',
                    color: theme.colorScheme.errorContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.12),
                        theme.colorScheme.primary.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Running check total',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currency.format(ordersTotal),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TotalChip(
                            icon: Icons.local_cafe_rounded,
                            label: 'Café',
                            value: _currency.format(cafeTotal),
                            color: theme.colorScheme.tertiary,
                          ),
                          _TotalChip(
                            icon: Icons.inventory_2_outlined,
                            label: 'Merch',
                            value: _currency.format(merchTotal),
                            color: theme.colorScheme.tertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Started ${live.formattedStartTime} · No table time charge',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (ref.watch(venueKindProvider).showCourseTracking)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restaurant_menu, size: 14, color: theme.colorScheme.tertiary),
                                const SizedBox(width: 6),
                                Text(
                                  'Restaurant service',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.tertiary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  icon: ref.watch(venueKindProvider).showCourseTracking ? Icons.restaurant_menu : Icons.local_cafe_rounded,
                  title: ref.watch(venueKindProvider).showCourseTracking ? 'Kitchen orders' : 'Café orders',
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: tenant
                      .cafeOrders()
                      .where('sessionId', isEqualTo: live.id)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _InfoBanner(
                        icon: Icons.error_outline,
                        message: 'Café orders: ${snap.error}',
                        color: theme.colorScheme.errorContainer,
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final docs = snap.data!.docs.toList();
                    docs.sort((a, b) {
                      final ta =
                          (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final tb =
                          (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return tb.compareTo(ta);
                    });
                    if (docs.isEmpty) {
                      return _EmptyOrdersHint(
                        icon: Icons.coffee_outlined,
                        title: 'No café orders yet',
                        subtitle: 'Tap Add F&B items to open the menu',
                      );
                    }
                    return Column(
                      children: docs.map((d) {
                        final o = CafeOrder.fromFirestore(d);
                        final vis = _cafeStatusVisual(theme, o.status);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: theme.colorScheme.surface,
                            elevation: 0,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {},
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: vis.color.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(vis.icon, color: vis.color),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            o.items
                                                .map(
                                                  (i) =>
                                                      '${i.name} ×${i.quantity}',
                                                )
                                                .join(', '),
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${o.status.toUpperCase()} · ${DateFormat.jm().format(o.createdAt)}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _currency.format(o.total),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Merchandise',
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: tenant
                      .merchandiseOrders()
                      .where('sessionId', isEqualTo: live.id)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _InfoBanner(
                        icon: Icons.error_outline,
                        message: 'Merchandise: ${snap.error}',
                        color: theme.colorScheme.errorContainer,
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final docs = snap.data!.docs.toList();
                    docs.sort((a, b) {
                      final ta =
                          (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final tb =
                          (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return tb.compareTo(ta);
                    });
                    if (docs.isEmpty) {
                      return _EmptyOrdersHint(
                        icon: Icons.shopping_bag_outlined,
                        title: 'No merchandise on this check',
                        subtitle:
                            'Merch orders linked to this session appear here',
                      );
                    }
                    return Column(
                      children: docs.map((d) {
                        final o = MerchandiseOrder.fromFirestore(d);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiaryContainer
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: theme.colorScheme.tertiary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        o.items
                                            .map(
                                              (i) => '${i.name} ×${i.quantity}',
                                            )
                                            .join(', '),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${o.status.toUpperCase()} · ${DateFormat.jm().format(o.createdAt)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _currency.format(o.total),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 20,
            8,
            isMobile ? 12 : 20,
            12,
          ),
          child: customerAsync.when(
            data: (customer) {
              if (customer == null) {
                return const SizedBox.shrink();
              }
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: tenant.sessions().doc(widget.session.id).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData || !snap.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final live = TableSession.fromFirestore(snap.data!);
                  if (live.status != SessionStatus.active) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: accent,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            AppMaterialPageRoute<void>(
                              builder: (_) => CafeScreen(
                                presetCustomer: customer,
                                presetTable: widget.table,
                                presetSession: live,
                                lockTableAssignment: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('Add F&B items'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: accent.withValues(alpha: 0.5),
                          ),
                        ),
                        onPressed: () async {
                          await HapticFeedback.lightImpact();
                          if (!context.mounted) return;
                          final ok = await runSessionCheckoutFlow(
                            context: context,
                            ref: ref,
                            session: live,
                            table: widget.table,
                            customer: customer,
                          );
                          if (ok && context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        },
                        icon: Icon(Icons.payments_outlined, color: accent),
                        label: Text(
                          'Bill & close table',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _PartyHeaderCard extends StatelessWidget {
  final Customer customer;
  final Color accent;

  const _PartyHeaderCard({required this.customer, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: accent.withValues(alpha: 0.15),
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  customer.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (customer.phoneNumber.isNotEmpty)
                  Text(
                    customer.phoneNumber,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TotalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TotalChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text('$label $value'),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _EmptyOrdersHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyOrdersHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InfoBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
