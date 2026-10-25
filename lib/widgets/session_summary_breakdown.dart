import 'package:flutter/material.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';

class SessionSummaryBreakdown extends StatelessWidget {
  final TableSession session;

  const SessionSummaryBreakdown({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use resilient subtotal when stored fields were cleared or inconsistent.
    final tableCharges = session.tableChargesAtCheckout ?? session.tableCharges;
    final cafeCharges = session.totalCafeAmount ?? 0.0;
    final merchCharges = session.totalMerchandiseAmount ?? 0.0;
    final total = session.effectiveBillSubtotal;

    final creditsUsed = session.creditsUsed ?? 0.0;
    final finalPaid = (total - creditsUsed).clamp(0, double.infinity);
    final sumParts = tableCharges + cafeCharges + merchCharges;
    final bool useSingleChargeLine = sumParts <= 0.0001 && total > 0.0001;

    return AppSurface(
      borderRadius: 12,
      padding: const EdgeInsets.all(16.0),
      borderColor: theme.colorScheme.outline.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Bill Breakdown',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Charges section
          _buildSectionTitle(theme, 'Charges'),
          const SizedBox(height: 8),
          if (useSingleChargeLine)
            _buildLineItem(context, theme, 'Billable total', total,
                isSubitem: true)
          else ...[
            _buildLineItem(context, theme, 'Table Time', tableCharges,
                isSubitem: true),
            if (cafeCharges > 0)
              _buildLineItem(
                context,
                theme,
                'Cafe Orders',
                cafeCharges,
                isSubitem: true,
              ),
            if (merchCharges > 0)
              _buildLineItem(
                context,
                theme,
                'Merchandise',
                merchCharges,
                isSubitem: true,
              ),
          ],
          const SizedBox(height: 8),
          _buildLineItem(context, theme, 'Subtotal', total, isBold: true),

          // Payment section
          const SizedBox(height: 16),
          _buildSectionTitle(theme, 'Payment'),
          const SizedBox(height: 8),
          if (creditsUsed > 0)
            _buildLineItem(
              context,
              theme,
              'Credits Used',
              creditsUsed,
              isSubitem: true,
              isDiscount: true,
            ),
          _buildLineItem(
            context,
            theme,
            '${session.paymentMode.name.toUpperCase()} Paid',
            finalPaid.toDouble(),
            isSubitem: true,
          ),

          // Total
          const Divider(height: 24),
          _buildLineItem(
            context,
            theme,
            'Total Bill',
            session.effectiveDisplayTotalBillAmount,
            isBold: true,
            isTotal: true,
          ),

          // Session metadata
          if (session.status == SessionStatus.completed) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildMetadataRow(
                    theme,
                    Icons.access_time,
                    'Duration',
                    session.formattedDuration,
                  ),
                  const SizedBox(height: 6),
                  _buildMetadataRow(
                    theme,
                    Icons.timer_outlined,
                    'Hourly Rate',
                    '₹${session.hourlyRate.toStringAsFixed(0)}/hr',
                  ),
                  if (session.isPTL) ...[
                    const SizedBox(height: 6),
                    _buildMetadataRow(
                      theme,
                      Icons.sports_esports,
                      'PTL Mode',
                      '${session.playerCount ?? 0} players',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary.withValues(alpha: 0.8),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildLineItem(
    BuildContext context,
    ThemeData theme,
    String label,
    double amount, {
    bool isSubitem = false,
    bool isBold = false,
    bool isDiscount = false,
    bool isTotal = false,
  }) {
    final discountColor = AppSemanticColors.of(context).success;
    return Padding(
      padding: EdgeInsets.only(left: isSubitem ? 16.0 : 0, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: (isBold || isTotal)
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: isTotal ? 16 : null,
              color: isDiscount
                  ? discountColor
                  : (isTotal ? theme.colorScheme.primary : null),
            ),
          ),
          Text(
            '${isDiscount ? '- ' : ''}₹${amount.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: (isBold || isTotal)
                  ? FontWeight.bold
                  : FontWeight.w500,
              fontSize: isTotal ? 16 : null,
              color: isDiscount
                  ? discountColor
                  : (isTotal ? theme.colorScheme.primary : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
