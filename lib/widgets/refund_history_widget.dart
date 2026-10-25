import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_utils.dart';

class RefundHistoryWidget extends StatelessWidget {
  final List<Map<String, dynamic>> refundHistory;

  const RefundHistoryWidget({super.key, required this.refundHistory});

  @override
  Widget build(BuildContext context) {
    if (refundHistory.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.error.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reply_all_outlined,
                size: 18,
                color: cs.onErrorContainer,
              ),
              const SizedBox(width: 6),
              Text(
                'Refund History',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onErrorContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...refundHistory.map((refund) => _buildRefundEntry(context, refund)),
        ],
      ),
    );
  }

  Widget _buildRefundEntry(BuildContext context, Map<String, dynamic> refund) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final refundAmount = _extractAmount(refund);
    final creditsRefunded = parseFirestoreDouble(refund['creditsRefunded']);
    final nonCreditsRefunded = refundAmount - creditsRefunded;
    final refundedBy = refund['refundedByName'] ?? 'Staff';
    final items = refund['items'] as List<dynamic>? ?? [];
    final dateStr = _formatRefundDate(refund['refundedAt']);
    final note = refund['note'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.error.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$refundedBy · $dateStr',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),

          ...items.map((item) => _buildItemRow(theme, cs, item)),

          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Refund:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '₹${refundAmount.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.error,
                ),
              ),
            ],
          ),

          if (creditsRefunded > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 14,
                      color: cs.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'To Credits:',
                      style: TextStyle(
                        color: cs.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${creditsRefunded.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          if (nonCreditsRefunded > 0.01) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getPaymentMethodLabel(refund),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                Text(
                  '₹${nonCreditsRefunded.toStringAsFixed(2)}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ],

          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(ThemeData theme, ColorScheme cs, dynamic item) {
    final name = item['name'] ?? 'Unknown Item';
    final quantity = parseFirestoreInt(item['quantity'], fallback: 1);
    final price = parseFirestoreDouble(item['price']);
    final total = price * quantity;

    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '• $name (x$quantity)',
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: cs.error,
            ),
          ),
          Text(
            '₹${total.toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: cs.error,
            ),
          ),
        ],
      ),
    );
  }

  double _extractAmount(Map<String, dynamic> refund) {
    return parseFirestoreDoubleOrNull(refund['refundAmount']) ??
        parseFirestoreDoubleOrNull(refund['amount']) ??
        0.0;
  }

  String _formatRefundDate(dynamic refundedAt) {
    if (refundedAt == null) return '';
    final dt = (refundedAt is Timestamp) ? refundedAt.toDate() : DateTime.now();
    return DateFormat.yMd().add_jm().format(dt);
  }

  String _getPaymentMethodLabel(Map<String, dynamic> refund) {
    final paymentBreakdown =
        refund['refundPaymentBreakdown'] as Map<String, dynamic>?;

    if (paymentBreakdown != null) {
      final nonCreditKeys = paymentBreakdown.keys
          .where((k) => k.toLowerCase() != 'credits')
          .toList();
      if (nonCreditKeys.isNotEmpty) {
        return 'Via ${nonCreditKeys.first.toUpperCase()}:';
      }
    }

    if (refund['useAlternativeRefundMethod'] == true) {
      return 'Via Alternative:';
    }

    return 'Via Original Method:';
  }
}

class RefundHistoryCompact extends StatelessWidget {
  final List<Map<String, dynamic>> refundHistory;

  const RefundHistoryCompact({super.key, required this.refundHistory});

  @override
  Widget build(BuildContext context) {
    if (refundHistory.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    double totalRefunded = 0.0;
    double totalCredits = 0.0;

    for (final refund in refundHistory) {
      totalRefunded +=
          parseFirestoreDoubleOrNull(refund['refundAmount']) ??
          parseFirestoreDoubleOrNull(refund['amount']) ??
          0.0;
      totalCredits += parseFirestoreDouble(refund['creditsRefunded']);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.reply_all_outlined,
                size: 14,
                color: cs.onErrorContainer,
              ),
              const SizedBox(width: 4),
              Text(
                'Refunded: ₹${totalRefunded.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (totalCredits > 0) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 12,
                  color: cs.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Credits: ₹${totalCredits.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.secondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
