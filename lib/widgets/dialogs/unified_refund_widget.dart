import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/permission_id.dart';
import '../../firestore/tenant_firestore.dart';
import '../../models/cafe_order.dart';
import '../../models/merchandise_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/refund_service.dart';
import '../../theme/app_theme.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

enum RefundType { fullOrder, selectedItems, sessionOrders }

enum OrderType { cafe, merchandise }

class UnifiedRefundWidget extends ConsumerStatefulWidget {
  final RefundType refundType;
  final OrderType? orderType;
  final String? orderId;
  final String? sessionId;

  const UnifiedRefundWidget.fullOrder({
    super.key,
    required this.orderType,
    required this.orderId,
  }) : refundType = RefundType.fullOrder,
       sessionId = null;

  const UnifiedRefundWidget.selectedItems({
    super.key,
    required this.orderType,
    required this.orderId,
  }) : refundType = RefundType.selectedItems,
       sessionId = null;

  const UnifiedRefundWidget.sessionOrders({
    super.key,
    required this.sessionId,
  }) : refundType = RefundType.sessionOrders,
       orderType = null,
       orderId = null;

  @override
  ConsumerState<UnifiedRefundWidget> createState() =>
      _UnifiedRefundWidgetState();
}

class _UnifiedRefundWidgetState extends ConsumerState<UnifiedRefundWidget> {
  final Map<String, bool> _selectedOrders = {};
  final Map<int, bool> _selectedItemIndexes = {};
  bool _selectAll = false;
  String _refundMethod = 'original';
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.opsRefund)) {
      return AlertDialog(
        title: const Text('Refund'),
        content: const Text(
          'You do not have permission to process refunds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.ok),
          ),
        ],
      );
    }

    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_getTitle()),
      content: SizedBox(width: 520, child: _buildContent()),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _processRefund,
          icon: _submitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onError,
                  ),
                )
              : const Icon(Icons.reply_all_outlined),
          label: Text(_submitting ? 'Processing...' : 'Refund'),
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
        ),
      ],
    );
  }

  String _getTitle() {
    switch (widget.refundType) {
      case RefundType.fullOrder:
        return 'Refund Full Order';
      case RefundType.selectedItems:
        return 'Refund Selected Items';
      case RefundType.sessionOrders:
        return 'Refund Session Orders';
    }
  }

  Widget _buildContent() {
    switch (widget.refundType) {
      case RefundType.fullOrder:
        return _buildFullOrderContent();
      case RefundType.selectedItems:
        return _buildSelectedItemsContent();
      case RefundType.sessionOrders:
        return _buildSessionOrdersContent();
    }
  }

  Widget _buildFullOrderContent() {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) {
      return const Text('No company context. Sign in again.');
    }
    final orderRef = widget.orderType == OrderType.cafe
        ? tenant.cafeOrders().doc(widget.orderId)
        : tenant.merchandiseOrders().doc(widget.orderId);
    return StreamBuilder<DocumentSnapshot>(
      stream: orderRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sem = AppSemanticColors.of(context);
        final cs = Theme.of(context).colorScheme;

        final order = widget.orderType == OrderType.cafe
            ? CafeOrder.fromFirestore(snapshot.data!)
            : MerchandiseOrder.fromFirestore(snapshot.data!);

        final total = widget.orderType == OrderType.cafe
            ? (order as CafeOrder).total
            : (order as MerchandiseOrder).total;

        final paymentBreakdown = widget.orderType == OrderType.cafe
            ? (order as CafeOrder).paymentBreakdown
            : (order as MerchandiseOrder).paymentBreakdown;

        final paymentMethod = widget.orderType == OrderType.cafe
            ? (order as CafeOrder).paymentMethod
            : (order as MerchandiseOrder).paymentMethod;

        final creditsUsed = widget.orderType == OrderType.cafe
            ? (order as CafeOrder).creditsUsed ?? 0.0
            : (order as MerchandiseOrder).creditsUsed ?? 0.0;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (paymentBreakdown != null && paymentBreakdown.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sem.infoContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sem.info.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: sem.onInfoContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Original Payment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: sem.onInfoContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...paymentBreakdown.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${e.key.toUpperCase()}:',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                '₹${e.value.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (paymentMethod != null || creditsUsed > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sem.infoContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sem.info.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: sem.onInfoContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Original Payment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: sem.onInfoContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (creditsUsed > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'CREDITS:',
                                style: TextStyle(fontSize: 13),
                              ),
                              Text(
                                '₹${creditsUsed.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (total > creditsUsed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(paymentMethod?.name ?? 'CASH').toUpperCase()}:',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                '₹${(total - creditsUsed).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildRefundMethodSelector(context),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: cs.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Refund Amount:',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          '₹${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedItemsContent() {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) {
      return const Text('No company context. Sign in again.');
    }
    final orderRef = widget.orderType == OrderType.cafe
        ? tenant.cafeOrders().doc(widget.orderId)
        : tenant.merchandiseOrders().doc(widget.orderId);
    return StreamBuilder<DocumentSnapshot>(
      stream: orderRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sem = AppSemanticColors.of(context);

        final items = widget.orderType == OrderType.cafe
            ? CafeOrder.fromFirestore(snapshot.data!).items
            : MerchandiseOrder.fromFirestore(snapshot.data!).items;

        for (int i = 0; i < items.length; i++) {
          _selectedItemIndexes.putIfAbsent(i, () => false);
        }

        final totalSelected = _computeSelectedItemsTotal(items);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRefundMethodSelector(context),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: (v) {
                      setState(() {
                        _selectAll = v ?? false;
                        for (int i = 0; i < items.length; i++) {
                          _selectedItemIndexes[i] = _selectAll;
                        }
                      });
                    },
                  ),
                  const Text('Select all items'),
                ],
              ),
              const Divider(),
              ...List.generate(items.length, (index) {
                final item = items[index];
                final name = widget.orderType == OrderType.cafe
                    ? (item as CafeOrderItem).name
                    : (item as MerchandiseOrderItem).name;
                final qty = widget.orderType == OrderType.cafe
                    ? (item as CafeOrderItem).quantity
                    : (item as MerchandiseOrderItem).quantity;
                final price = widget.orderType == OrderType.cafe
                    ? (item as CafeOrderItem).price
                    : (item as MerchandiseOrderItem).price;
                final selected = _selectedItemIndexes[index] ?? false;

                return CheckboxListTile(
                  value: selected,
                  onChanged: (v) =>
                      setState(() => _selectedItemIndexes[index] = v ?? false),
                  title: Text(
                    name,
                    style: TextStyle(
                      decoration: selected ? TextDecoration.lineThrough : null,
                      color: selected
                          ? Theme.of(context).colorScheme.error
                          : null,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                  subtitle: Text('x$qty · ₹${price.toStringAsFixed(2)}'),
                  secondary: Text(
                    '₹${(qty * price).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sem.warningContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Refund Total:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${totalSelected.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionOrdersContent() {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) {
      return const Text('No company context. Sign in again.');
    }
    return StreamBuilder<List<dynamic>>(
      stream: _combinedSessionStream(tenant, widget.sessionId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sem = AppSemanticColors.of(context);

        final cafeOrders = snapshot.data![0] as List<CafeOrder>;
        final merchOrders = snapshot.data![1] as List<MerchandiseOrder>;

        for (final o in cafeOrders) {
          _selectedOrders.putIfAbsent('cafe_${o.id}', () => false);
        }
        for (final o in merchOrders) {
          _selectedOrders.putIfAbsent('merch_${o.id}', () => false);
        }

        final totalSelected = _computeSelectedOrdersTotal(
          cafeOrders,
          merchOrders,
        );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRefundMethodSelector(context),
              const SizedBox(height: 16),
              if (cafeOrders.isNotEmpty) ...[
                const Text(
                  'Cafe Orders:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...cafeOrders.map(
                  (o) => CheckboxListTile(
                    value: _selectedOrders['cafe_${o.id}'] ?? false,
                    onChanged: o.isRefunded
                        ? null
                        : (v) => setState(
                            () => _selectedOrders['cafe_${o.id}'] = v ?? false,
                          ),
                    title: Text(
                      'Order #${o.id.substring(0, 8)} · ₹${o.total.toStringAsFixed(2)}',
                    ),
                    subtitle: Text(
                      o.isRefunded ? 'REFUNDED' : o.status.toUpperCase(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (merchOrders.isNotEmpty) ...[
                const Text(
                  'Merchandise Orders:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...merchOrders.map(
                  (o) => CheckboxListTile(
                    value: _selectedOrders['merch_${o.id}'] ?? false,
                    onChanged: o.isRefunded
                        ? null
                        : (v) => setState(
                            () => _selectedOrders['merch_${o.id}'] = v ?? false,
                          ),
                    title: Text(
                      'Order #${o.id.substring(0, 8)} · ₹${o.total.toStringAsFixed(2)}',
                    ),
                    subtitle: Text(
                      o.isRefunded ? 'REFUNDED' : o.status.toUpperCase(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sem.warningContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Refund Total:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${totalSelected.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRefundMethodSelector(BuildContext context) {
    final sem = AppSemanticColors.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sem.successContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: sem.success.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: sem.onSuccessContainer),
              const SizedBox(width: 8),
              const Text(
                'Refund Method',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.history, size: 16),
                    SizedBox(width: 4),
                    Text('Original'),
                  ],
                ),
                selected: _refundMethod == 'original',
                onSelected: (v) {
                  if (v) setState(() => _refundMethod = 'original');
                },
                selectedColor: cs.primaryContainer,
              ),
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.money, size: 16),
                    SizedBox(width: 4),
                    Text('Cash'),
                  ],
                ),
                selected: _refundMethod == 'cash',
                onSelected: (v) {
                  if (v) setState(() => _refundMethod = 'cash');
                },
                selectedColor: sem.successContainer,
              ),
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.qr_code_scanner, size: 16),
                    SizedBox(width: 4),
                    Text('UPI'),
                  ],
                ),
                selected: _refundMethod == 'upi',
                onSelected: (v) {
                  if (v) setState(() => _refundMethod = 'upi');
                },
                selectedColor: sem.infoContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _computeSelectedItemsTotal(List<dynamic> items) {
    double total = 0.0;
    for (int i = 0; i < items.length; i++) {
      if (!(_selectedItemIndexes[i] ?? false)) continue;
      final item = items[i];
      if (item is CafeOrderItem) {
        total += item.price * item.quantity;
      } else if (item is MerchandiseOrderItem) {
        total += item.price * item.quantity;
      }
    }
    return total;
  }

  double _computeSelectedOrdersTotal(
    List<CafeOrder> cafe,
    List<MerchandiseOrder> merch,
  ) {
    double total = 0.0;
    for (final o in cafe) {
      if ((_selectedOrders['cafe_${o.id}'] ?? false) && !o.isRefunded) {
        total += o.total;
      }
    }
    for (final o in merch) {
      if ((_selectedOrders['merch_${o.id}'] ?? false) && !o.isRefunded) {
        total += o.total;
      }
    }
    return total;
  }

  Stream<List<dynamic>> _combinedSessionStream(
    TenantRef tenant,
    String sessionId,
  ) async* {
    final cafeStream = tenant
        .cafeOrders()
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((s) => s.docs.map((d) => CafeOrder.fromFirestore(d)).toList());
    final merchStream = tenant
        .merchandiseOrders()
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map(
          (s) => s.docs.map((d) => MerchandiseOrder.fromFirestore(d)).toList(),
        );

    await for (final cafe in cafeStream) {
      final merch = await merchStream.first;
      yield [cafe, merch];
    }
  }

  Future<void> _processRefund() async {
    setState(() => _submitting = true);
    try {
      final appUser = ref.read(appUserProvider).value;
      if (appUser == null) throw Exception('User not authenticated');

      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) throw Exception('No company context');
      final refundService = RefundService(tenant);
      final permissions = ref.readResolvedPermissions();
      final useAlternative = _refundMethod != 'original';
      final altMethod = useAlternative ? _refundMethod : null;

      switch (widget.refundType) {
        case RefundType.fullOrder:
          if (widget.orderType == OrderType.cafe) {
            await refundService.refundCafeOrder(
              permissions: permissions,
              orderId: widget.orderId!,
              admin: appUser,
              refundRemainderToCredits: false,
              useAlternativeMethod: useAlternative,
              alternativeMethod: altMethod,
            );
          } else {
            await refundService.refundMerchandiseOrder(
              permissions: permissions,
              orderId: widget.orderId!,
              admin: appUser,
              refundRemainderToCredits: false,
              useAlternativeMethod: useAlternative,
              alternativeMethod: altMethod,
            );
          }
          break;

        case RefundType.selectedItems:
          final indexes = _selectedItemIndexes.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toList();
          if (indexes.isEmpty) throw Exception('No items selected');

          if (widget.orderType == OrderType.cafe) {
            await refundService.refundCafeOrderItems(
              permissions: permissions,
              orderId: widget.orderId!,
              itemIndexesToRefund: indexes,
              admin: appUser,
              refundRemainderToCredits: false,
              useAlternativeMethod: useAlternative,
              alternativeMethod: altMethod,
            );
          } else {
            await refundService.refundMerchandiseOrderItems(
              permissions: permissions,
              orderId: widget.orderId!,
              itemIndexesToRefund: indexes,
              admin: appUser,
              refundRemainderToCredits: false,
              useAlternativeMethod: useAlternative,
              alternativeMethod: altMethod,
            );
          }
          break;

        case RefundType.sessionOrders:
          final cafeSnap = await tenant
              .cafeOrders()
              .where('sessionId', isEqualTo: widget.sessionId)
              .get();
          for (final d in cafeSnap.docs) {
            final o = CafeOrder.fromFirestore(d);
            if ((_selectedOrders['cafe_${o.id}'] ?? false) && !o.isRefunded) {
              await refundService.refundCafeOrder(
                permissions: permissions,
                orderId: o.id,
                admin: appUser,
                refundRemainderToCredits: false,
                useAlternativeMethod: useAlternative,
                alternativeMethod: altMethod,
              );
            }
          }

          final merchSnap = await tenant
              .merchandiseOrders()
              .where('sessionId', isEqualTo: widget.sessionId)
              .get();
          for (final d in merchSnap.docs) {
            final o = MerchandiseOrder.fromFirestore(d);
            if ((_selectedOrders['merch_${o.id}'] ?? false) && !o.isRefunded) {
              await refundService.refundMerchandiseOrder(
                permissions: permissions,
                orderId: o.id,
                admin: appUser,
                refundRemainderToCredits: false,
                useAlternativeMethod: useAlternative,
                alternativeMethod: altMethod,
              );
            }
          }
          break;
      }

      if (mounted) {
        final sem = AppSemanticColors.of(context);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Refund processed successfully'),
            backgroundColor: sem.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refund failed: $e'),
            backgroundColor: cs.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
