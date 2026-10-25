import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/merchandise_order.dart';
import '../../../constants/order_status.dart';
import '../../cafe/components/order_status_chip.dart';
import '../../../utils/firestore_utils.dart';

class MerchandiseOrderCard extends StatefulWidget {
  final MerchandiseOrder order;
  final bool isMobile;
  final VoidCallback? onRefund;

  const MerchandiseOrderCard({
    super.key,
    required this.order,
    required this.isMobile,
    this.onRefund,
  });

  @override
  State<MerchandiseOrderCard> createState() => _MerchandiseOrderCardState();
}

class _MerchandiseOrderCardState extends State<MerchandiseOrderCard> {
  bool _isExpanded = false;

  MerchandiseOrder get order => widget.order;
  bool get isMobile => widget.isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final orderStatus = OrderStatus.fromString(
      order.isRefunded ? 'refunded' : order.status,
    );
    final orderIdColor = orderStatus.accentColor(context);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact header - always visible
            _buildCompactHeader(context, textTheme, colorScheme, orderIdColor),

            // Expandable content
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    height: 1,
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  _buildItemsSummary(context, textTheme, colorScheme),
                  if (order.refundHistory != null &&
                      order.refundHistory!.isNotEmpty)
                    _buildRefundHistory(context, textTheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
    Color orderIdColor,
  ) {
    final itemCount = order.items.fold<int>(
      0,
      (totalQty, item) => totalQty + item.quantity,
    );

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [orderIdColor.withValues(alpha: 0.08), Colors.transparent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Order number and date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: isMobile ? 28 : 32,
                            decoration: BoxDecoration(
                              color: orderIdColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${order.id}',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: orderIdColor,
                                    fontSize: isMobile ? 14 : 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat.MMMd().add_jm().format(
                                    order.createdAt,
                                  ),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: isMobile ? 11 : 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status chip
                OrderStatusChip(
                  status: order.isRefunded ? 'refunded' : order.status,
                  chipSize: isMobile ? ChipSize.small : ChipSize.large,
                ),

                // Refund menu (only if eligible)
                if (!order.isRefunded &&
                    order.total > 0 &&
                    order.isBilled &&
                    widget.onRefund != null) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'refund' && widget.onRefund != null) {
                        widget.onRefund!();
                      }
                    },
                    itemBuilder: (c) => [
                      const PopupMenuItem(
                        value: 'refund',
                        child: Text('Refund Order'),
                      ),
                    ],
                    icon: Icon(Icons.more_vert, size: isMobile ? 20 : 24),
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                  ),
                ],
              ],
            ),

            // Second row: customer, items count, total
            const SizedBox(height: 10),
            Row(
              children: [
                // Customer info
                if (order.customerName != null) ...[
                  Icon(
                    Icons.person_outline_rounded,
                    size: isMobile ? 14 : 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      order.customerName!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: isMobile ? 11 : 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Items count
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 6 : 8,
                    vertical: isMobile ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 10 : 11,
                    ),
                  ),
                ),

                const Spacer(),

                // Total
                Text(
                  '₹${order.total.toStringAsFixed(0)}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontSize: isMobile ? 15 : 17,
                  ),
                ),

                // Expand indicator
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: isMobile ? 20 : 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSummary(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items list
          ...order.items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: isMobile ? 6 : 8),
              child: Row(
                children: [
                  Container(
                    width: isMobile ? 24 : 28,
                    height: isMobile ? 24 : 28,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantity}',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                          fontSize: isMobile ? 11 : 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: isMobile ? 13 : 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Divider(
            height: isMobile ? 16 : 20,
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),

          // Footer with total and payment info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
              Text(
                '₹${order.total.toStringAsFixed(0)}',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  fontSize: isMobile ? 14 : 15,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 4 : 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isMobile ? 11 : 12,
                ),
              ),
              Text(
                _getPaymentLabel(),
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isMobile ? 11 : 12,
                ),
              ),
            ],
          ),

          // Staff info if available
          if (order.performedByName != null) ...[
            SizedBox(height: isMobile ? 4 : 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: isMobile ? 12 : 14,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '${order.performedByRole?.toUpperCase() ?? 'STAFF'}: ${order.performedByName}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: isMobile ? 10 : 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRefundHistory(BuildContext context, TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 12 : 14,
        0,
        isMobile ? 12 : 14,
        isMobile ? 12 : 14,
      ),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reply_all_rounded,
                size: isMobile ? 16 : 18,
                color: colorScheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                'Refund History',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                  fontSize: isMobile ? 12 : 13,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 10),
          ...order.refundHistory!.map((refund) {
            final items = refund['items'] as List<dynamic>? ?? [];
            final amount =
                parseFirestoreDoubleOrNull(refund['refundAmount']) ??
                parseFirestoreDoubleOrNull(refund['amount']) ??
                0.0;
            final refundedAt = refund['refundedAt'];
            String dateStr = '';
            if (refundedAt != null) {
              final dt = (refundedAt is Timestamp)
                  ? refundedAt.toDate()
                  : DateTime.now();
              dateStr = DateFormat.MMMd().add_jm().format(dt);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: isMobile ? 10 : 11,
                  ),
                ),
                SizedBox(height: isMobile ? 4 : 6),
                ...items.map((it) {
                  final row = Map<String, dynamic>.from(it as Map);
                  final name = '${row['name'] ?? ''}';
                  final qty = parseFirestoreInt(row['quantity'], fallback: 0);
                  final price = parseFirestoreDouble(row['price']);
                  return Padding(
                    padding: EdgeInsets.only(bottom: isMobile ? 2 : 3),
                    child: Row(
                      children: [
                        Text(
                          '${qty}x ',
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error,
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            name,
                            style: textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: colorScheme.error.withValues(alpha: 0.8),
                              fontSize: isMobile ? 11 : 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '-₹${(price * qty).toStringAsFixed(0)}',
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.error,
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  'Refunded: ₹${amount.toStringAsFixed(0)}',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _getPaymentLabel() {
    if (!order.isBilled) {
      return 'PENDING';
    }

    if (order.creditsUsed != null && order.creditsUsed! > 0) {
      double nonCreditPaid;
      if (order.paymentBreakdown != null) {
        nonCreditPaid = order.paymentBreakdown!.entries
            .where((e) => e.key.toLowerCase() != 'credits')
            .fold(0.0, (running, e) => running + e.value);
        if (nonCreditPaid == 0.0) {
          nonCreditPaid = order.total - order.creditsUsed!;
        }
      } else {
        nonCreditPaid = order.total - order.creditsUsed!;
      }

      String nonCreditPm;
      if (order.paymentBreakdown != null) {
        final keys = order.paymentBreakdown!.keys
            .where((k) => k.toLowerCase() != 'credits')
            .toList();
        nonCreditPm = keys.isNotEmpty
            ? keys.first.toUpperCase()
            : (order.paymentMethod?.name.toUpperCase() ?? 'CASH');
      } else {
        nonCreditPm = order.paymentMethod?.name.toUpperCase() ?? 'CASH';
      }

      if (nonCreditPaid > 0) {
        return '$nonCreditPm ₹${nonCreditPaid.toStringAsFixed(0)} + ${order.creditsUsed!.toStringAsFixed(0)} CR';
      } else {
        return '${order.creditsUsed!.toStringAsFixed(0)} CR';
      }
    }

    if (order.paymentMethod != null) {
      return order.paymentMethod!.name.toUpperCase();
    }

    return 'SESSION';
  }
}
