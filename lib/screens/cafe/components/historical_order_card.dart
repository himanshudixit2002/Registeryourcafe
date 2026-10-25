import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/cafe_order.dart';
import '../../../constants/order_status.dart';
import 'order_status_chip.dart';
import '../../../utils/firestore_utils.dart';
import '../../../widgets/safe_network_avatar.dart';

class HistoricalOrderCard extends StatefulWidget {
  final CafeOrder order;
  final bool isMobile;
  final bool canRefund;
  final VoidCallback? onRefund;

  const HistoricalOrderCard({
    super.key,
    required this.order,
    required this.isMobile,
    required this.canRefund,
    this.onRefund,
  });

  @override
  State<HistoricalOrderCard> createState() => _HistoricalOrderCardState();
}

class _HistoricalOrderCardState extends State<HistoricalOrderCard> {
  bool _isExpanded = false;

  CafeOrder get order => widget.order;
  bool get isMobile => widget.isMobile;
  bool get canRefund => widget.canRefund;

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
            color: colorScheme.shadow.withValues(alpha: 0.12),
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
                  if (order.refundHistory.isNotEmpty)
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
        padding: EdgeInsets.all(isMobile ? 10 : 14),
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
                // Order ID badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 10,
                    vertical: isMobile ? 4 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: orderIdColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${order.id}',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: orderIdColor,
                      fontSize: isMobile ? 11 : 12,
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 10),
                // Date/time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.MMMd().format(order.createdAt),
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 11 : 12,
                        ),
                      ),
                      Text(
                        DateFormat.jm().format(order.createdAt),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: isMobile ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Total and status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${order.total.toStringAsFixed(0)}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        fontSize: isMobile ? 15 : 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    OrderStatusChip(
                      status: order.isRefunded ? 'refunded' : order.status,
                      chipSize: ChipSize.small,
                    ),
                  ],
                ),
                if (canRefund &&
                    !order.isRefunded &&
                    order.total > 0 &&
                    order.isBilled)
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
                    icon: Icon(Icons.more_vert, size: isMobile ? 18 : 20),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            SizedBox(height: isMobile ? 8 : 10),
            // Bottom row - customer, items count, payment
            Row(
              children: [
                // Customer
                if (order.customerName != null &&
                    order.customerName!.isNotEmpty) ...[
                  Icon(
                    Icons.person_rounded,
                    size: isMobile ? 12 : 14,
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
                  SizedBox(width: isMobile ? 10 : 12),
                ],
                // Items count
                Icon(
                  Icons.shopping_bag_rounded,
                  size: isMobile ? 12 : 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$itemCount items',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                const Spacer(),
                // Payment method
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 6 : 8,
                    vertical: isMobile ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getPaymentLabel(),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                      fontSize: isMobile ? 10 : 11,
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 8),
                // Expand indicator
                Icon(
                  _isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: isMobile ? 18 : 20,
                  color: colorScheme.onSurfaceVariant,
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
    return Padding(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performed by info
          if (order.performedByName != null) ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 10,
                vertical: isMobile ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: isMobile ? 12 : 14,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(order.performedByRole ?? 'staff').toUpperCase()}: ${order.performedByName}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.secondary,
                      fontSize: isMobile ? 10 : 11,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 10 : 12),
          ],
          // Items list
          ...order.items.map((item) {
            return Padding(
              padding: EdgeInsets.only(bottom: isMobile ? 6 : 8),
              child: Row(
                children: [
                  if (item.imageUrl != null &&
                      item.imageUrl!.trim().isNotEmpty) ...[
                    SafeNetworkAvatar(
                      imageUrl: item.imageUrl,
                      radius: isMobile ? 16 : 18,
                      fallbackIcon: Icons.local_cafe_rounded,
                    ),
                    SizedBox(width: isMobile ? 8 : 10),
                  ],
                  Container(
                    width: isMobile ? 26 : 30,
                    height: isMobile ? 26 : 30,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantity}',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                          fontSize: isMobile ? 11 : 12,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 10 : 12),
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
                      color: colorScheme.onSurfaceVariant,
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRefundHistory(BuildContext context, TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 10 : 14,
        0,
        isMobile ? 10 : 14,
        isMobile ? 10 : 14,
      ),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
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
          ...order.refundHistory.map((refund) {
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
      }
      return '${order.creditsUsed!.toStringAsFixed(0)} CR';
    }

    if (order.paymentMethod != null) {
      return order.paymentMethod!.name.toUpperCase();
    }

    return 'SESSION';
  }
}
