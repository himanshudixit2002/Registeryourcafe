import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/permission_id.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/tenant_provider.dart';
import '../../../services/refund_service.dart';
import '../../../widgets/dialogs/unified_refund_widget.dart';

import '../../../models/sales_transaction.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/sales_palette.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../widgets/glass_panel.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class TransactionsListWidget extends StatefulWidget {
  final List<SalesTransaction> transactions;
  const TransactionsListWidget({super.key, required this.transactions});

  @override
  State<TransactionsListWidget> createState() => _TransactionsListWidgetState();
}

class _TransactionsListWidgetState extends State<TransactionsListWidget> {
  static const int _initialCount = 50; // How many rows to render initially
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return Consumer(
      builder: (context, ref, _) {
        final canRefund = ref.watchResolvedPermissions().can(
          PermissionIds.opsRefund,
        );
        final List<SalesTransaction> visibleTx = _showAll
            ? widget.transactions
            : widget.transactions.take(_initialCount).toList();

        if (widget.transactions.isEmpty) {
          final cs = Theme.of(context).colorScheme;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: cs.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try adjusting your filters',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleTx.length,
              itemBuilder: (context, index) {
                final tx = visibleTx[index];
                return isMobile
                    ? _buildMobileCard(context, tx, canRefund, ref)
                    : _buildDesktopCard(context, tx, canRefund, ref);
              },
            ),
            if (!_showAll && widget.transactions.length > _initialCount)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.kSpacingSmall,
                ),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showAll = true),
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: Text(
                    'Show ${widget.transactions.length - _initialCount} more',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMobileCard(
    BuildContext context,
    SalesTransaction tx,
    bool canRefund,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final iconData = _getIconForType(tx.type);
    final bool isRefund =
        tx.total < 0 || tx.paidTotal < 0 || tx.creditsUsed < 0;
    final color = isRefund
        ? cs.error
        : SalesPalette.transactionType(context, tx.type);
    final typeLabel = _getTypeLabelForType(tx.type);

    // Amount display - compact
    String amountText = '₹${tx.paidTotal.abs().toStringAsFixed(0)}';
    if (tx.creditsUsed.abs() > 0) {
      amountText += '+${tx.creditsUsed.abs().toStringAsFixed(0)}cr';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: AppTheme.cardShadowFor(theme.brightness),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Type + Payment + Amount
                Row(
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Payment method
                    Text(
                      tx.paymentMethod.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isRefund) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'REFUND',
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Amount
                    Text(
                      isRefund ? '-$amountText' : amountText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isRefund ? cs.error : cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Row 2: Description (single line)
                Text(
                  tx.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Row 3: Customer + Date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx.customerName ?? 'Walk-in',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM, h:mm a').format(tx.date),
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.outline,
                      ),
                    ),
                    if (canRefund && tx.total > 0) ...[
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: _buildAdminMenu(context, tx, ref),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCard(
    BuildContext context,
    SalesTransaction tx,
    bool canRefund,
    WidgetRef ref,
  ) {
    final cs = Theme.of(context).colorScheme;
    final iconData = _getIconForType(tx.type);
    final bool isRefund =
        tx.total < 0 || tx.paidTotal < 0 || tx.creditsUsed < 0;
    final color = isRefund
        ? cs.error
        : SalesPalette.transactionType(context, tx.type);
    final bool isRetained = tx.total == 0 && tx.paidTotal > 0;
    final typeLabel = _getTypeLabelForType(tx.type);

    String amountText;
    if (isRetained) {
      amountText = '₹${tx.paidTotal.toStringAsFixed(2)} (retained)';
    } else if (tx.creditsUsed > 0) {
      amountText =
          '₹${tx.paidTotal.toStringAsFixed(2)} + ${tx.creditsUsed.toStringAsFixed(0)} cr';
    } else {
      amountText = '₹${tx.paidTotal.toStringAsFixed(2)}';
    }

    return AppSurface(
      borderRadius: AppTheme.kBorderRadiusSmall,
      margin: const EdgeInsets.symmetric(vertical: AppTheme.kSpacingXSmall),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badges row
                Row(
                  children: [
                    _buildBadge(typeLabel, color),
                    const SizedBox(width: 6),
                    _buildBadge(
                      tx.paymentMethod.toUpperCase(),
                      cs.onSurfaceVariant,
                      filled: true,
                    ),
                    if (isRefund) ...[
                      const SizedBox(width: 6),
                      _buildBadge('REFUND', cs.error),
                    ],
                    if (isRetained) ...[
                      const SizedBox(width: 6),
                      _buildBadge('RETAINED', cs.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Description
                Text(
                  tx.description,
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Customer + Date
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tx.customerName ?? 'Walk-in Customer',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(tx.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Amount
          Text(
            amountText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isRefund ? cs.error : cs.onSurface,
            ),
          ),
          if (canRefund && tx.total > 0) ...[
            const SizedBox(width: 8),
            _buildAdminMenu(context, tx, ref),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildAdminMenu(
    BuildContext context,
    SalesTransaction tx,
    WidgetRef ref,
  ) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      iconSize: 20,
      icon: Icon(Icons.more_vert, size: 18, color: cs.onSurfaceVariant),
      onSelected: (value) async {
        if (value == 'refund') {
          if (tx.type == TransactionType.cafe ||
              tx.type == TransactionType.merchandise) {
            await showDialog<bool>(
              context: context,
              builder: (ctx) => UnifiedRefundWidget.fullOrder(
                orderType: tx.type == TransactionType.cafe
                    ? OrderType.cafe
                    : OrderType.merchandise,
                orderId: tx.id,
              ),
            );
          } else if (tx.type == TransactionType.session) {
            final amountController = TextEditingController(
              text: tx.total.abs().toStringAsFixed(2),
            );
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Refund Session'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter refund amount (leave unchanged for full refund)',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(prefixText: '₹'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(AppStrings.cancel),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(AppStrings.confirm),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            if (!context.mounted) return;
            final amount =
                double.tryParse(amountController.text) ?? tx.total.abs();

            final appUser = ref.read(appUserProvider).value!;
            final tenant = ref.read(tenantRefProvider);
            if (tenant == null) {
              if (context.mounted) {
                context.showErrorSnackbar('No company context');
              }
              return;
            }
            final refundService = RefundService(tenant);

            SnackbarHelper.showLoading(
              context,
              'Processing session refund...',
            );
            try {
              await refundService.refundSession(
                permissions: ref.readResolvedPermissions(),
                sessionId: tx.id,
                admin: appUser,
                amount: amount,
              );
              if (context.mounted) {
                SnackbarHelper.dismiss(context);
                context.showSuccessSnackbar('Session refund successful');
              }
            } catch (e) {
              if (context.mounted) {
                SnackbarHelper.dismiss(context);
                context.showErrorSnackbar('Refund failed: $e');
              }
            }
          }
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem<String>(value: 'refund', child: Text('Refund')),
      ],
    );
  }

  IconData _getIconForType(TransactionType type) {
    switch (type) {
      case TransactionType.session:
        return Icons.pool_rounded;
      case TransactionType.cafe:
        return Icons.local_cafe_rounded;
      case TransactionType.merchandise:
        return Icons.shopping_bag_rounded;
      case TransactionType.tournamentRegistration:
        return Icons.emoji_events;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _getTypeLabelForType(TransactionType type) {
    switch (type) {
      case TransactionType.session:
        return 'SESSION';
      case TransactionType.cafe:
        return 'CAFE';
      case TransactionType.merchandise:
        return 'MERCH';
      case TransactionType.tournamentRegistration:
        return 'TOURNAMENT';
      case TransactionType.credit:
        return 'CREDIT';
    }
  }
}
