import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/session.dart';
import '../../models/customer.dart';
import '../../models/table.dart';
import '../../models/cafe_order.dart';
import '../../models/merchandise_order.dart';
import '../../providers/table_provider.dart' show tableServiceProvider;
import '../../providers/customer_provider.dart' show singleCustomerProvider;
import '../../widgets/dialogs/unified_refund_widget.dart';
import '../../widgets/refund_history_widget.dart';
import '../../widgets/loading_indicator.dart';
import '../../auth/permission_id.dart';
import '../../providers/permissions_provider.dart';
import '../refund/unified_refund_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../providers/tenant_provider.dart';
import '../../firestore/tenant_firestore.dart';
import '../../widgets/glass_panel.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'session_checkout_flow.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class SessionDetailsDialog extends ConsumerWidget {
  final TableSession session;
  final SnookerTable table;
  final String customerId;
  final bool isReadOnly;

  const SessionDetailsDialog({
    super.key,
    required this.session,
    required this.table,
    required this.customerId,
    this.isReadOnly = false,
  });

  /// Checks if session can be cancelled (within 3 mins and no orders).
  Future<bool> _canCancelSession(TenantRef? tenant) async {
    if (tenant == null) return false;
    final diff = DateTime.now().difference(session.startTime);
    if (diff.inMinutes >= 3) return false;

    final cafeOrders = await tenant
        .cafeOrders()
        .where('sessionId', isEqualTo: session.id)
        .limit(1)
        .get();
    if (cafeOrders.docs.isNotEmpty) return false;
    final merchOrders = await tenant
        .merchandiseOrders()
        .where('sessionId', isEqualTo: session.id)
        .limit(1)
        .get();
    if (merchOrders.docs.isNotEmpty) return false;
    return true;
  }

  Future<void> _cancelThisSession(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Session'),
        content: const Text('Are you sure you want to cancel this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(tableServiceProvider)
          .cancelSession(session: session, table: table);
      if (context.mounted) {
        Navigator.of(context).pop(true);
        context.showSuccessSnackbar('Session cancelled');
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorSnackbar('Unable to cancel session: $e');
      }
    }
  }

  Future<void> _endSession(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final ok = await runSessionCheckoutFlow(
      context: context,
      ref: ref,
      session: session,
      table: table,
      customer: customer,
    );
    if (ok && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);
    final tenant = ref.watch(tenantRefProvider);
    final customerAsyncValue = ref.watch(singleCustomerProvider(customerId));
    final canRefund = ref.watchResolvedPermissions().can(
      PermissionIds.opsRefund,
    );

    // For mobile, return content only (used in bottom sheet)
    if (isMobile) {
      return _buildMobileContent(
        context,
        ref,
        theme,
        customerAsyncValue,
        canRefund,
        tenant,
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.table_restaurant_rounded,
              color: theme.colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session on ${table.name}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ID: ${_truncateId(session.id)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: customerAsyncValue.when(
        data: (customer) {
          if (customer == null) return const Text('Customer not found.');
          return SizedBox(
            width: 500,
            child: SingleChildScrollView(
              physics: AppTheme.scrollPhysicsFor(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!session.isPTL) ...[
                    _buildCustomerCard(theme, customer, false),
                  ] else ...[
                    _buildPTLPlayersCard(theme, false),
                  ],
                  const SizedBox(height: 12),
                  _buildSessionInfoGrid(theme, false),
                  if (session.totalCafeAmount != null &&
                      session.totalCafeAmount! > 0) ...[
                    Divider(
                      height: 24,
                      thickness: 1,
                      color: AppTheme.subtleDividerColor(theme),
                    ),
                    _buildOrderTotalRow(
                      theme,
                      Icons.local_cafe_rounded,
                      'Cafe Orders',
                      session.totalCafeAmount!,
                      theme.colorScheme.tertiary,
                    ),
                  ],
                  StreamBuilder<QuerySnapshot>(
                    stream: tenant == null
                        ? const Stream<
                            QuerySnapshot<Map<String, dynamic>>
                          >.empty()
                        : tenant
                              .cafeOrders()
                              .where('sessionId', isEqualTo: session.id)
                              .snapshots(),
                    builder: (ctx, orderSnap) {
                      if (orderSnap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Error loading café orders',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        );
                      }
                      if (!orderSnap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (!orderSnap.hasData || orderSnap.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No café orders linked to this session.'),
                        );
                      }
                      final orders = orderSnap.data!.docs
                          .map((d) => CafeOrder.fromFirestore(d))
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(
                            thickness: 1,
                            color: AppTheme.subtleDividerColor(theme),
                          ),
                          Text(
                            'Cafe Orders',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          ...orders.map(
                            (order) => ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 0,
                              ),
                              leading: const Icon(Icons.receipt_long_rounded),
                              trailing:
                                  canRefund &&
                                      !order.isRefunded &&
                                      order.isBilled
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.reply_all_outlined,
                                            color: theme.colorScheme.tertiary,
                                          ),
                                          tooltip: 'Refund Order',
                                          onPressed: () async {
                                            final result =
                                                await Navigator.of(
                                                  context,
                                                ).push<bool>(
                                                  AppMaterialPageRoute<bool>(
                                                    builder: (context) =>
                                                        UnifiedRefundScreen(
                                                          orderId: order.id,
                                                          orderType:
                                                              RefundOrderType
                                                                  .cafe,
                                                          sessionId: session.id,
                                                        ),
                                                  ),
                                                );
                                            if (result == true &&
                                                context.mounted) {
                                              context.showSuccessSnackbar(
                                                'Refund processed successfully',
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  : null,
                              title: Text(
                                'Order #${order.id} · ₹${order.total.toStringAsFixed(2)}',
                              ),
                              subtitle: Text(
                                '${order.isRefunded ? 'REFUNDED' : order.status.toUpperCase()} · ${DateFormat.yMMMd().add_jm().format(order.createdAt)}',
                              ),
                              children: [
                                ...order.items.map(
                                  (item) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.circle, size: 6),
                                    title: Text(
                                      '${item.name} (x${item.quantity})',
                                    ),
                                    trailing: Text(
                                      '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                    ),
                                  ),
                                ),
                                if (order.refundHistory.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: RefundHistoryWidget(
                                      refundHistory: order.refundHistory,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (session.totalMerchandiseAmount != null &&
                      session.totalMerchandiseAmount! > 0) ...[
                    Divider(
                      thickness: 1,
                      color: AppTheme.subtleDividerColor(theme),
                    ),
                    ListTile(
                      leading: const Icon(Icons.shopping_bag),
                      title: const Text('Merchandise Total'),
                      subtitle: Text(
                        '₹${session.totalMerchandiseAmount!.toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                  StreamBuilder<QuerySnapshot>(
                    stream: tenant == null
                        ? const Stream<
                            QuerySnapshot<Map<String, dynamic>>
                          >.empty()
                        : tenant
                              .merchandiseOrders()
                              .where('sessionId', isEqualTo: session.id)
                              .snapshots(),
                    builder: (ctx, merchSnap) {
                      if (merchSnap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Error loading merchandise orders',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        );
                      }
                      if (!merchSnap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (!merchSnap.hasData || merchSnap.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'No merchandise orders linked to this session.',
                          ),
                        );
                      }
                      final merchOrders = merchSnap.data!.docs
                          .map((d) => MerchandiseOrder.fromFirestore(d))
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(
                            thickness: 1,
                            color: AppTheme.subtleDividerColor(theme),
                          ),
                          Text(
                            'Merchandise Orders',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          ...merchOrders.map(
                            (order) => ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 0,
                              ),
                              leading: const Icon(Icons.local_mall_rounded),
                              trailing:
                                  canRefund &&
                                      !order.isRefunded &&
                                      order.isBilled
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.reply_all_outlined,
                                            color: theme.colorScheme.tertiary,
                                          ),
                                          tooltip: 'Refund Order',
                                          onPressed: () async {
                                            final result =
                                                await Navigator.of(
                                                  context,
                                                ).push<bool>(
                                                  AppMaterialPageRoute<bool>(
                                                    builder: (context) =>
                                                        UnifiedRefundScreen(
                                                          orderId: order.id,
                                                          orderType:
                                                              RefundOrderType
                                                                  .merchandise,
                                                          sessionId: session.id,
                                                        ),
                                                  ),
                                                );
                                            if (result == true &&
                                                context.mounted) {
                                              context.showSuccessSnackbar(
                                                'Refund processed successfully',
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  : null,
                              title: Text(
                                'Order #${order.id} · ₹${order.total.toStringAsFixed(2)}',
                              ),
                              subtitle: Text(
                                '${order.isRefunded ? 'REFUNDED' : order.status.toUpperCase()} · ${DateFormat.yMMMd().add_jm().format(order.createdAt)}',
                              ),
                              children: [
                                ...order.items.map(
                                  (item) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.circle, size: 6),
                                    title: Text(
                                      '${item.name} (x${item.quantity})',
                                    ),
                                    trailing: Text(
                                      '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                    ),
                                  ),
                                ),
                                if (order.refundHistory != null &&
                                    order.refundHistory!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: RefundHistoryWidget(
                                      refundHistory: order.refundHistory!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const LoadingIndicator(message: 'Loading details...'),
        error: (e, s) => Text('Error loading customer: $e'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        if (!isReadOnly &&
            session.status == SessionStatus.active &&
            session.isOnBreak)
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume from Break'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
            ),
            onPressed: () async {
              try {
                await ref.read(tableServiceProvider).endBreak(session: session);
                if (context.mounted) Navigator.of(context).pop(true);
              } catch (e) {
                if (context.mounted) {
                  context.showErrorSnackbar('Error: $e');
                }
              }
            },
          ),
        if (!isReadOnly &&
            session.status == SessionStatus.active &&
            session.isBreakAvailable)
          ElevatedButton.icon(
            icon: const Icon(Icons.coffee_rounded),
            label: const Text('Take 5 Min Break'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
            ),
            onPressed: () async {
              try {
                await ref
                    .read(tableServiceProvider)
                    .startBreak(session: session);
                if (context.mounted) Navigator.of(context).pop(true);
              } catch (e) {
                if (context.mounted) {
                  context.showErrorSnackbar('Error: $e');
                }
              }
            },
          ),
        if (canRefund &&
            session.status == SessionStatus.completed &&
            !session.isRefunded)
          ElevatedButton.icon(
            icon: const Icon(Icons.reply_all_outlined),
            label: const Text('Refund'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) =>
                    UnifiedRefundWidget.sessionOrders(sessionId: session.id),
              );
              if (ok == true && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        if (!isReadOnly)
          customerAsyncValue.when(
            data: (customer) => customer != null
                ? ElevatedButton.icon(
                    onPressed: () => _endSession(context, ref, customer),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('End Session & Bill'),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        // Cancel button – shown conditionally
        if (!isReadOnly && session.status == SessionStatus.active)
          FutureBuilder<bool>(
            future: _canCancelSession(tenant),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              if (snapshot.data == true) {
                return TextButton.icon(
                  onPressed: () => _cancelThisSession(context, ref),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Session'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.tertiary,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  // Mobile-optimized content
  Widget _buildMobileContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AsyncValue<Customer?> customerAsyncValue,
    bool canRefund,
    TenantRef? tenant,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: customerAsyncValue.when(
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('Customer not found.'));
          }
          return CustomScrollView(
            physics: AppTheme.scrollPhysicsFor(context),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.table_restaurant_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Session on ${table.name}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Clipboard.setData(
                                      ClipboardData(text: session.id),
                                    );
                                    SnackbarHelper.showInfo(
                                      context,
                                      'Session ID copied',
                                      duration: const Duration(seconds: 1),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        'ID: ${_truncateId(session.id)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontFamily: 'monospace',
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 14,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!session.isPTL)
                        _buildCustomerCard(theme, customer, true)
                      else
                        _buildPTLPlayersCard(theme, true),
                    ],
                  ),
                ),
              ),

              // Session Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(12),
                    child: _buildSessionInfoGrid(theme, true),
                  ),
                ),
              ),

              // Order Totals
              if (session.totalCafeAmount != null &&
                  session.totalCafeAmount! > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildOrderTotalRow(
                      theme,
                      Icons.local_cafe_rounded,
                      'Cafe Orders',
                      session.totalCafeAmount!,
                      theme.colorScheme.tertiary,
                    ),
                  ),
                ),

              if (session.totalMerchandiseAmount != null &&
                  session.totalMerchandiseAmount! > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _buildOrderTotalRow(
                      theme,
                      Icons.shopping_bag_rounded,
                      'Merchandise',
                      session.totalMerchandiseAmount!,
                      theme.colorScheme.secondary,
                    ),
                  ),
                ),

              // Cafe Orders Stream
              SliverToBoxAdapter(
                child: _buildCafeOrdersSection(
                  context,
                  theme,
                  canRefund,
                  true,
                  tenant,
                ),
              ),

              // Merchandise Orders Stream
              SliverToBoxAdapter(
                child: _buildMerchandiseOrdersSection(
                  context,
                  theme,
                  canRefund,
                  true,
                  tenant,
                ),
              ),

              // Bottom spacing for action buttons
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => const Center(
          child: LoadingIndicator(message: 'Loading details...'),
        ),
        error: (e, s) => Center(child: Text('Error loading customer: $e')),
      ),
      bottomNavigationBar: _buildMobileActionBar(
        context,
        ref,
        customerAsyncValue,
        canRefund,
        theme,
        tenant,
      ),
    );
  }

  Widget _buildMobileActionBar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Customer?> customerAsyncValue,
    bool canRefund,
    ThemeData theme,
    TenantRef? tenant,
  ) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel button for active sessions
          if (!isReadOnly && session.status == SessionStatus.active)
            FutureBuilder<bool>(
              future: _canCancelSession(tenant),
              builder: (ctx, snapshot) {
                if (snapshot.data == true) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelThisSession(context, ref),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text(AppStrings.cancel),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.tertiary,
                        side: BorderSide(
                          color: theme.colorScheme.tertiary.withValues(
                            alpha: 0.65,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

          // Refund button when permitted
          if (canRefund &&
              session.status == SessionStatus.completed &&
              !session.isRefunded)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await HapticFeedback.mediumImpact();
                  if (!context.mounted) return;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => UnifiedRefundWidget.sessionOrders(
                      sessionId: session.id,
                    ),
                  );
                  if (ok == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                icon: const Icon(Icons.reply_all_outlined, size: 18),
                label: const Text('Refund'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.75),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),

          if (!isReadOnly &&
              session.status == SessionStatus.active &&
              session.isOnBreak)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await HapticFeedback.mediumImpact();
                  if (!context.mounted) return;
                  try {
                    await ref
                        .read(tableServiceProvider)
                        .endBreak(session: session);
                    if (context.mounted) Navigator.of(context).pop(true);
                  } catch (e) {
                    if (context.mounted) {
                      context.showErrorSnackbar('Error: $e');
                    }
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Resume'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          if (!isReadOnly &&
              session.status == SessionStatus.active &&
              session.isBreakAvailable)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await HapticFeedback.mediumImpact();
                  if (!context.mounted) return;
                  try {
                    await ref
                        .read(tableServiceProvider)
                        .startBreak(session: session);
                    if (context.mounted) Navigator.of(context).pop(true);
                  } catch (e) {
                    if (context.mounted) {
                      context.showErrorSnackbar('Error: $e');
                    }
                  }
                },
                icon: const Icon(Icons.coffee_rounded, size: 18),
                label: const Text('Break'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.secondary,
                  side: BorderSide(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.55),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),

          const Spacer(),

          // End Session button
          if (!isReadOnly)
            customerAsyncValue.when(
              data: (customer) => customer != null
                  ? ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _endSession(context, ref, customer);
                      },
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('End & Bill'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  Widget _buildCustomerCard(ThemeData theme, Customer customer, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isMobile ? 22 : 24,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 15 : 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  customer.phoneNumber,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
                if (customer.membershipId != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.card_membership_rounded,
                        size: isMobile ? 12 : 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        customer.membershipId!,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPTLPlayersCard(ThemeData theme, bool isMobile) {
    final cs = theme.colorScheme;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(
          color: cs.tertiary.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people_alt_rounded,
                size: isMobile ? 16 : 18,
                color: cs.onTertiaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                'PTL Players (${session.playerCount ?? session.playerNames.length})',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: FontWeight.bold,
                  color: cs.onTertiaryContainer,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 10),
          Wrap(
            spacing: isMobile ? 6 : 8,
            runSpacing: isMobile ? 6 : 8,
            children: [
              for (int i = 0; i < session.playerNames.length; i++)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 12,
                    vertical: isMobile ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: session.loserPlayerIndex == (i + 1)
                        ? cs.errorContainer.withValues(alpha: 0.92)
                        : cs.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: session.loserPlayerIndex == (i + 1)
                          ? cs.error.withValues(alpha: 0.45)
                          : cs.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        session.loserPlayerIndex == (i + 1)
                            ? Icons.sentiment_dissatisfied_rounded
                            : Icons.person_outline_rounded,
                        size: isMobile ? 14 : 16,
                        color: session.loserPlayerIndex == (i + 1)
                            ? cs.onErrorContainer
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.playerNames[i],
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.w500,
                          color: session.loserPlayerIndex == (i + 1)
                              ? cs.onErrorContainer
                              : cs.onSurface,
                        ),
                      ),
                      if (session.loserPlayerIndex == (i + 1)) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(Pays)',
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 11,
                            color: cs.error,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoGrid(ThemeData theme, bool isMobile) {
    final duration = session.duration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final cs = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(51),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  theme,
                  Icons.timer_outlined,
                  'Started',
                  DateFormat(
                    isMobile ? 'MMM d, h:mm a' : 'MMM d, yyyy h:mm a',
                  ).format(session.startTime),
                  cs.primary,
                  isMobile,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: _buildInfoTile(
                  theme,
                  Icons.hourglass_bottom_rounded,
                  'Duration',
                  '${hours}h ${minutes}m',
                  cs.tertiary,
                  isMobile,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  theme,
                  Icons.monetization_on_outlined,
                  'Rate',
                  '₹${table.hourlyRate.toStringAsFixed(0)}/hr',
                  cs.secondary,
                  isMobile,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: _buildInfoTile(
                  theme,
                  Icons.payment_rounded,
                  'Payment',
                  session.paymentMode.toString().split('.').last.toUpperCase(),
                  cs.outline,
                  isMobile,
                ),
              ),
            ],
          ),
          if (session.minimumBookingCharge != null) ...[
            SizedBox(height: isMobile ? 8 : 12),
            _buildInfoTile(
              theme,
              Icons.payments_outlined,
              'Min. Booking',
              '₹${session.minimumBookingCharge!.toStringAsFixed(0)} (${session.minimumBillableMinutes} min)',
              cs.secondary,
              isMobile,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
    bool isMobile, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(icon, size: isMobile ? 18 : 20, color: color),
          SizedBox(width: isMobile ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTotalRow(
    ThemeData theme,
    IconData icon,
    String label,
    double amount,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCafeOrdersSection(
    BuildContext context,
    ThemeData theme,
    bool canRefund,
    bool isMobile,
    TenantRef? tenant,
  ) {
    if (tenant == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: tenant
          .cafeOrders()
          .where('sessionId', isEqualTo: session.id)
          .snapshots(),
      builder: (ctx, orderSnap) {
        if (orderSnap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error loading café orders',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          );
        }
        if (!orderSnap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (orderSnap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final orders = orderSnap.data!.docs
            .map((d) => CafeOrder.fromFirestore(d))
            .toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_cafe_rounded,
                    size: 18,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cafe Orders (${orders.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...orders.map(
                (order) => _buildOrderCard(
                  context,
                  theme,
                  order.id,
                  order.total,
                  order.status,
                  order.isRefunded,
                  order.createdAt,
                  order.items.map((i) => '${i.name} x${i.quantity}').toList(),
                  order.refundHistory,
                  canRefund && !order.isRefunded && order.isBilled,
                  RefundOrderType.cafe,
                  Icons.local_cafe_rounded,
                  theme.colorScheme.tertiary,
                  isMobile,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMerchandiseOrdersSection(
    BuildContext context,
    ThemeData theme,
    bool canRefund,
    bool isMobile,
    TenantRef? tenant,
  ) {
    if (tenant == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: tenant
          .merchandiseOrders()
          .where('sessionId', isEqualTo: session.id)
          .snapshots(),
      builder: (ctx, merchSnap) {
        if (merchSnap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error loading merchandise orders',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          );
        }
        if (!merchSnap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (merchSnap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final orders = merchSnap.data!.docs
            .map((d) => MerchandiseOrder.fromFirestore(d))
            .toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_rounded,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Merchandise Orders (${orders.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...orders.map(
                (order) => _buildOrderCard(
                  context,
                  theme,
                  order.id,
                  order.total,
                  order.status,
                  order.isRefunded,
                  order.createdAt,
                  order.items.map((i) => '${i.name} x${i.quantity}').toList(),
                  order.refundHistory ?? [],
                  canRefund && !order.isRefunded && order.isBilled,
                  RefundOrderType.merchandise,
                  Icons.shopping_bag_rounded,
                  theme.colorScheme.secondary,
                  isMobile,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    ThemeData theme,
    String orderId,
    double total,
    String status,
    bool isRefunded,
    DateTime createdAt,
    List<String> items,
    List<Map<String, dynamic>> refundHistory,
    bool canRefund,
    RefundOrderType orderType,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isRefunded
            ? cs.errorContainer.withValues(alpha: 0.75)
            : cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isRefunded
              ? cs.error.withValues(alpha: 0.35)
              : color.withAlpha(77),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
          childrenPadding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 16,
            0,
            isMobile ? 12 : 16,
            12,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: isMobile ? 16 : 18, color: color),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${_truncateId(orderId)}',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      isRefunded ? 'REFUNDED' : status.toUpperCase(),
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        fontWeight: FontWeight.w500,
                        color: isRefunded
                            ? cs.error
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                  decoration: isRefunded ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          trailing: canRefund
              ? IconButton(
                  icon: Icon(
                    Icons.reply_all_outlined,
                    color: cs.tertiary,
                    size: isMobile ? 18 : 20,
                  ),
                  onPressed: () async {
                    await HapticFeedback.mediumImpact();
                    if (!context.mounted) return;
                    final result = await Navigator.of(context).push<bool>(
                      AppMaterialPageRoute<bool>(
                        builder: (context) => UnifiedRefundScreen(
                          orderId: orderId,
                          orderType: orderType,
                          sessionId: session.id,
                        ),
                      ),
                    );
                    if (result == true && context.mounted) {
                      context.showSuccessSnackbar(
                        'Refund processed successfully',
                      );
                    }
                  },
                )
              : const SizedBox(width: 48),
          children: [
            // Items list
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: cs.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (refundHistory.isNotEmpty) ...[
              const SizedBox(height: 8),
              RefundHistoryWidget(refundHistory: refundHistory),
            ],
          ],
        ),
      ),
    );
  }
}
