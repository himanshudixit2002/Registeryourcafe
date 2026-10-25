import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../models/cafe_order.dart';
import '../../models/merchandise_order.dart';
import '../../services/refund_service.dart';
import '../../auth/permission_id.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_card.dart';
import '../../widgets/permission_denied_scaffold.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

enum RefundOrderType { cafe, merchandise, session }

class RefundItem {
  final String itemId;
  final String name;
  final double price;
  final int originalQuantity;
  int refundQuantity;
  bool isSelected;

  RefundItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.originalQuantity,
    this.refundQuantity = 0,
    this.isSelected = false,
  });

  double get refundTotal => price * refundQuantity;
}

class UnifiedRefundScreen extends ConsumerStatefulWidget {
  final String orderId;
  final RefundOrderType orderType;
  final String? sessionId;

  const UnifiedRefundScreen({
    super.key,
    required this.orderId,
    required this.orderType,
    this.sessionId,
  });

  @override
  ConsumerState<UnifiedRefundScreen> createState() =>
      _UnifiedRefundScreenState();
}

class _UnifiedRefundScreenState extends ConsumerState<UnifiedRefundScreen> {
  List<RefundItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  double _orderTotal = 0.0;
  double _creditsUsed = 0.0;
  Map<String, double>? _paymentBreakdown;
  String? _primaryPaymentMethod;
  String? _customerName;
  bool _isBilled = false;
  String _refundMethod = 'original';

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.orderType == RefundOrderType.cafe) {
        await _loadCafeOrder();
      } else if (widget.orderType == RefundOrderType.merchandise) {
        await _loadMerchandiseOrder();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCafeOrder() async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) throw Exception('No company context');
    final docRef = await tenant.cafeOrders().doc(widget.orderId).get();

    if (!docRef.exists) {
      throw Exception('Order not found');
    }

    final order = CafeOrder.fromFirestore(docRef);

    setState(() {
      _items = order.items
          .map(
            (item) => RefundItem(
              itemId: item.itemId,
              name: item.name,
              price: item.price,
              originalQuantity: item.quantity,
              refundQuantity: item.quantity,
              isSelected: true,
            ),
          )
          .toList();
      _orderTotal = order.total;
      _creditsUsed = order.creditsUsed ?? 0.0;
      _paymentBreakdown = order.paymentBreakdown;
      _primaryPaymentMethod = order.paymentMethod?.name;
      _customerName = order.customerName;
      _isBilled = order.isBilled;
      _isLoading = false;
    });
  }

  Future<void> _loadMerchandiseOrder() async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) throw Exception('No company context');
    final docRef = await tenant.merchandiseOrders().doc(widget.orderId).get();

    if (!docRef.exists) {
      throw Exception('Order not found');
    }

    final order = MerchandiseOrder.fromFirestore(docRef);

    setState(() {
      _items = order.items
          .map(
            (item) => RefundItem(
              itemId: item.itemId,
              name: item.name,
              price: item.price,
              originalQuantity: item.quantity,
              refundQuantity: item.quantity,
              isSelected: true,
            ),
          )
          .toList();
      _orderTotal = order.total;
      _creditsUsed = order.creditsUsed ?? 0.0;
      _paymentBreakdown = order.paymentBreakdown;
      _primaryPaymentMethod = order.paymentMethod?.name;
      _customerName = order.customerName;
      _isBilled = order.isBilled;
      _isLoading = false;
    });
  }

  double get _selectedItemsTotal {
    return _items
        .where((item) => item.isSelected && item.refundQuantity > 0)
        .fold(0.0, (acc, item) => acc + item.refundTotal);
  }

  bool get _isFullRefund => _selectedItemsTotal >= _orderTotal;

  double get _creditsToRefund {
    if (_creditsUsed <= 0 || _orderTotal <= 0) return 0;
    final proportion = _selectedItemsTotal / _orderTotal;
    final credits = _creditsUsed * proportion;
    return math.min(credits, _creditsUsed);
  }

  double get _nonCreditsToRefund => _selectedItemsTotal - _creditsToRefund;

  String get _originalPaymentMethodDisplay {
    if (!_isBilled) return 'PENDING';

    if (_paymentBreakdown != null) {
      final nonCreditMethods = _paymentBreakdown!.keys
          .where((k) => k.toLowerCase() != 'credits')
          .toList();
      if (nonCreditMethods.isNotEmpty) {
        return nonCreditMethods.map((k) => k.toUpperCase()).join(', ');
      }
    }
    return _primaryPaymentMethod?.toUpperCase() ?? 'CASH';
  }

  Future<void> _processRefund() async {
    final user = ref.read(appUserProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    final selectedItems = _items
        .where((item) => item.isSelected && item.refundQuantity > 0)
        .toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected for refund')),
      );
      return;
    }

    final confirmed = await _showRefundConfirmationDialog(selectedItems);
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No company context')));
        return;
      }
      final refundService = RefundService(tenant);
      final permissions = ref.readResolvedPermissions();
      final bool useAlternative = _refundMethod != 'original';
      final String? altMethod = useAlternative ? _refundMethod : null;

      if (_isFullRefund) {
        if (widget.orderType == RefundOrderType.cafe) {
          await refundService.refundCafeOrder(
            permissions: permissions,
            orderId: widget.orderId,
            admin: user,
            amount: _selectedItemsTotal,
            refundRemainderToCredits: false,
            useAlternativeMethod: useAlternative,
            alternativeMethod: altMethod,
          );
        } else if (widget.orderType == RefundOrderType.merchandise) {
          await refundService.refundMerchandiseOrder(
            permissions: permissions,
            orderId: widget.orderId,
            admin: user,
            amount: _selectedItemsTotal,
            refundRemainderToCredits: false,
            useAlternativeMethod: useAlternative,
            alternativeMethod: altMethod,
          );
        }
      } else {
        final itemsToRefund = selectedItems
            .map(
              (item) => <String, dynamic>{
                'itemId': item.itemId,
                'name': item.name,
                'price': item.price,
                'quantity': item.refundQuantity,
              },
            )
            .toList();

        if (widget.orderType == RefundOrderType.cafe) {
          await refundService.refundCafeOrderItemsWithQuantities(
            permissions: permissions,
            orderId: widget.orderId,
            admin: user,
            items: itemsToRefund,
            refundRemainderToCredits: false,
            useAlternativeMethod: useAlternative,
            alternativeMethod: altMethod,
          );
        } else if (widget.orderType == RefundOrderType.merchandise) {
          await refundService.refundMerchandiseOrderItemsWithQuantities(
            permissions: permissions,
            orderId: widget.orderId,
            admin: user,
            items: itemsToRefund,
            refundRemainderToCredits: false,
            useAlternativeMethod: useAlternative,
            alternativeMethod: altMethod,
          );
        }
      }

      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Refund of ₹${_selectedItemsTotal.toStringAsFixed(2)} processed successfully',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarHelper.showError(context, 'Error: ${e.toString()}');
      }
    }
  }

  Future<bool?> _showRefundConfirmationDialog(List<RefundItem> selectedItems) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: cs.tertiary),
              const SizedBox(width: 8),
              const Text('Confirm Refund'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.error.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Refund:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cs.onErrorContainer,
                            ),
                          ),
                          Text(
                            '\u20B9${_selectedItemsTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: cs.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refund Breakdown:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_creditsToRefund > 0)
                        _buildBreakdownRow(
                          'Credits (to customer wallet)',
                          _creditsToRefund,
                          cs.tertiary,
                        ),
                      if (_nonCreditsToRefund > 0)
                        _buildBreakdownRow(
                          _refundMethod == 'original'
                              ? _originalPaymentMethodDisplay
                              : _refundMethod.toUpperCase(),
                          _nonCreditsToRefund,
                          cs.secondary,
                        ),
                      if (_creditsToRefund <= 0 && _nonCreditsToRefund <= 0)
                        const Text('No refund amount calculated'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Items to refund:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                ...selectedItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.name} \u00d7 ${item.refundQuantity}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '\u20B9${item.refundTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              child: const Text('Confirm Refund'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBreakdownRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_forward, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 13)),
            ],
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.opsRefund)) {
      return const PermissionDeniedScaffold(
        title: 'Refund',
        message: 'You do not have permission to process refunds.',
      );
    }

    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.orderType == RefundOrderType.cafe
                    ? Icons.coffee_rounded
                    : Icons.shopping_bag_rounded,
                size: isMobile ? 16 : 20,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Flexible(
              child: Text(
                'Refund ${widget.orderType == RefundOrderType.cafe ? 'Cafe' : 'Merchandise'}',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: isMobile,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : _errorMessage != null
          ? _buildErrorState()
          : Column(
              children: [
                _buildOrderHeader(theme, isMobile),
                Expanded(child: _buildItemsList(theme, isMobile)),
                _buildRefundSummary(theme, isMobile),
              ],
            ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.error,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.somethingWentWrong,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadOrderData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader(ThemeData theme, bool isMobile) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 16),
      child: AppCard(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: theme.colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Total',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                        Text(
                          '₹${_orderTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 28,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_creditsUsed > 0 || _customerName != null) ...[
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_creditsUsed > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer.withValues(
                            alpha: 0.65,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 14,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '\u20B9${_creditsUsed.toStringAsFixed(0)} credits',
                              style: TextStyle(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withValues(
                          alpha: 0.65,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payment_rounded,
                            size: 14,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _originalPaymentMethodDisplay,
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_customerName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _customerName!,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsList(ThemeData theme, bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                item.isSelected = !item.isSelected;
                item.refundQuantity = item.isSelected
                    ? item.originalQuantity
                    : 0;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Custom checkbox
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: item.isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: item.isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        child: item.isSelected
                            ? Icon(
                                Icons.check_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: 16,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 14 : 16,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\u20B9${item.price.toStringAsFixed(0)} \u00d7 ${item.originalQuantity}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: isMobile ? 12 : 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: item.isSelected
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.55,
                                )
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\u20B9${(item.price * item.originalQuantity).toStringAsFixed(0)}',
                          style: TextStyle(
                            color: item.isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.isSelected) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Refund Qty',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                          const Spacer(),
                          // Quantity controls
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildQtyButton(
                                  icon: Icons.remove_rounded,
                                  onTap: item.refundQuantity > 0
                                      ? () {
                                          HapticFeedback.lightImpact();
                                          setState(() {
                                            item.refundQuantity--;
                                            if (item.refundQuantity == 0) {
                                              item.isSelected = false;
                                            }
                                          });
                                        }
                                      : null,
                                  color: theme.colorScheme.error,
                                ),
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${item.refundQuantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _buildQtyButton(
                                  icon: Icons.add_rounded,
                                  onTap:
                                      item.refundQuantity <
                                          item.originalQuantity
                                      ? () {
                                          HapticFeedback.lightImpact();
                                          setState(() => item.refundQuantity++);
                                        }
                                      : null,
                                  color: theme.colorScheme.tertiary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Text(
                              '\u20B9${item.refundTotal.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 13 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: onTap != null
                ? color
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _buildRefundSummary(ThemeData theme, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    theme.colorScheme.tertiaryContainer.withValues(alpha: 0.25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Refund',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '₹${_selectedItemsTotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 26,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (_creditsToRefund > 0 || _nonCreditsToRefund > 0) ...[
                    const SizedBox(height: 8),
                    Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 4),
                    if (_creditsToRefund > 0)
                      _buildSummaryRow(
                        'Credits Refund',
                        '\u20B9${_creditsToRefund.toStringAsFixed(0)}',
                        theme.colorScheme.tertiary,
                        Icons.account_balance_wallet_rounded,
                      ),
                    if (_nonCreditsToRefund > 0)
                      _buildSummaryRow(
                        _originalPaymentMethodDisplay,
                        '\u20B9${_nonCreditsToRefund.toStringAsFixed(0)}',
                        theme.colorScheme.secondary,
                        Icons.payment_rounded,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildRefundMethodSelector(theme, isMobile),
            const SizedBox(height: 12),
            // Action button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: _selectedItemsTotal > 0 && !_isLoading
                    ? _processRefund
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  disabledBackgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _selectedItemsTotal > 0 ? 2 : 0,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Process Refund • ₹${_selectedItemsTotal.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: isMobile ? 15 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color accent,
    IconData icon,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: accent),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundMethodSelector(ThemeData theme, bool isMobile) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Refund Method',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildMethodChip(
                theme: theme,
                label: 'Original',
                sublabel: _originalPaymentMethodDisplay,
                icon: Icons.autorenew_rounded,
                isSelected: _refundMethod == 'original',
                accent: cs.primary,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _refundMethod = 'original');
                },
              ),
              const SizedBox(width: 8),
              _buildMethodChip(
                theme: theme,
                label: 'Cash',
                icon: Icons.money_rounded,
                isSelected: _refundMethod == 'cash',
                accent: cs.tertiary,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _refundMethod = 'cash');
                },
              ),
              const SizedBox(width: 8),
              _buildMethodChip(
                theme: theme,
                label: 'UPI',
                icon: Icons.qr_code_rounded,
                isSelected: _refundMethod == 'upi',
                accent: cs.secondary,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _refundMethod = 'upi');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMethodChip({
    required ThemeData theme,
    required String label,
    String? sublabel,
    required IconData icon,
    required bool isSelected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.16)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.45)
                : cs.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? accent : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? accent : cs.onSurface,
                  ),
                ),
                if (sublabel != null)
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? accent.withValues(alpha: 0.85)
                          : cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
