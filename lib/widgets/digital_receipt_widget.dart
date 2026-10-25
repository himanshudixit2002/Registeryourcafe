import 'package:flutter/material.dart';

import '../models/receipt.dart';

class DigitalReceiptWidget extends StatelessWidget {
  final Receipt receipt;

  const DigitalReceiptWidget({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryText = colorScheme.onSurface;
    final secondaryText = colorScheme.onSurfaceVariant;
    final dividerColor = colorScheme.outlineVariant;

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            receipt.companyName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          if (receipt.companyAddress != null)
            Text(
              receipt.companyAddress!,
              style: TextStyle(fontSize: 11, color: secondaryText),
              textAlign: TextAlign.center,
            ),
          if (receipt.companyPhone != null)
            Text(
              receipt.companyPhone!,
              style: TextStyle(fontSize: 11, color: secondaryText),
            ),
          const SizedBox(height: 8),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                receipt.formattedNumber,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: secondaryText,
                ),
              ),
              Text(
                '${receipt.createdAt.day}/${receipt.createdAt.month}/${receipt.createdAt.year}',
                style: TextStyle(fontSize: 12, color: secondaryText),
              ),
            ],
          ),
          if (receipt.customerName != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Customer: ${receipt.customerName}',
                style: TextStyle(fontSize: 12, color: primaryText),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 8),
          for (final item in receipt.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${item.quantity}x',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryText,
                      ),
                    ),
                  ),
                  Text(
                    '\u20B9${item.total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 8),
          _row(context, 'Subtotal', '\u20B9${receipt.subtotal.toStringAsFixed(0)}'),
          if (receipt.taxAmount > 0)
            _row(
              context,
              '${receipt.taxLabel} (${receipt.subtotal > 0 ? ((receipt.taxAmount / receipt.subtotal) * 100).toStringAsFixed(1) : '0.0'}%)',
              '\u20B9${receipt.taxAmount.toStringAsFixed(0)}',
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
              Text(
                '\u20B9${receipt.total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Paid via ${receipt.paymentMethod}',
              style: TextStyle(fontSize: 11, color: secondaryText),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 8),
          Text(
            'Thank you for your visit!',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
