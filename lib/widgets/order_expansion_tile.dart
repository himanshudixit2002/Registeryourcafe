import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/order_status.dart';
import '../theme/app_theme.dart';
import './refund_history_widget.dart';

class OrderExpansionTile<T> extends StatelessWidget {
  /// Unique identifier for the order
  final String orderId;

  /// Order total amount
  final double total;

  /// Order status (pending, preparing, ready, delivered, etc.)
  final String status;

  /// When the order was created
  final DateTime createdAt;

  /// List of order items
  final List<T> items;

  /// Function to extract item name
  final String Function(T) getItemName;

  /// Function to extract item quantity
  final int Function(T) getItemQuantity;

  /// Function to extract item price
  final double Function(T) getItemPrice;

  /// Whether the order has been refunded
  final bool isRefunded;

  /// Whether the order has been billed
  final bool isBilled;

  /// Refund history for this order
  final List<Map<String, dynamic>>? refundHistory;

  /// Icon for the leading position
  final IconData leadingIcon;

  /// Callback when refund button is pressed (null to hide button)
  final VoidCallback? onRefund;

  /// Whether to show admin controls
  final bool showAdminControls;

  const OrderExpansionTile({
    super.key,
    required this.orderId,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.items,
    required this.getItemName,
    required this.getItemQuantity,
    required this.getItemPrice,
    this.isRefunded = false,
    this.isBilled = false,
    this.refundHistory,
    this.leadingIcon = Icons.receipt_long_rounded,
    this.onRefund,
    this.showAdminControls = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayStatus = isRefunded ? 'REFUNDED' : status.toUpperCase();

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Icon(leadingIcon),
      trailing: _buildTrailing(context),
      title: Text('Order #$orderId · ₹${total.toStringAsFixed(2)}'),
      subtitle: Text(
        '$displayStatus · ${DateFormat.yMMMd().add_jm().format(createdAt)}',
        style: TextStyle(
          color: _getStatusColor(context, status, isRefunded),
        ),
      ),
      children: [
        // Current items
        ...items.map((item) => _buildItemTile(theme, item)),

        // Refund history
        if (refundHistory != null && refundHistory!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: RefundHistoryWidget(refundHistory: refundHistory!),
          ),
      ],
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    // Show refund button for admin on billed, non-refunded orders
    if (showAdminControls && !isRefunded && isBilled && onRefund != null) {
      final sem = AppSemanticColors.of(context);
      return IconButton(
        icon: Icon(Icons.reply_all_outlined, color: sem.warning),
        tooltip: 'Refund Order',
        onPressed: onRefund,
      );
    }
    return null;
  }

  Widget _buildItemTile(ThemeData theme, T item) {
    final name = getItemName(item);
    final quantity = getItemQuantity(item);
    final price = getItemPrice(item);
    final itemTotal = price * quantity;

    return ListTile(
      dense: true,
      leading: const Icon(Icons.circle, size: 6),
      title: Text('$name (x$quantity)'),
      trailing: Text('₹${itemTotal.toStringAsFixed(2)}'),
    );
  }

  Color _getStatusColor(
    BuildContext context,
    String status,
    bool isRefunded,
  ) {
    final cs = Theme.of(context).colorScheme;
    if (isRefunded) return cs.error;
    final orderStatus = OrderStatus.fromString(status);
    return orderStatus.accentColor(context);
  }
}
