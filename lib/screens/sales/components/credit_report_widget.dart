import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';

import '../../../models/sales_transaction.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_panel.dart';

class CreditReportWidget extends StatelessWidget {
  final CreditSummary creditSummary;

  const CreditReportWidget({super.key, required this.creditSummary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final formatCurrency = NumberFormat.simpleCurrency(
      locale: 'en_IN',
      decimalDigits: 0,
    );
    final isMobile = AppTheme.isMobile(context);

    return AppSurface(
      borderRadius: AppTheme.kBorderRadiusLarge,
      padding: EdgeInsets.all(
        isMobile ? AppTheme.kSpacingMedium : AppTheme.kSpacingLarge,
      ),
      borderColor: cs.secondary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: isMobile ? 20 : 24,
                backgroundColor: cs.secondaryContainer,
                child: Icon(
                  UniconsLine.credit_card,
                  color: cs.onSecondaryContainer,
                  size: isMobile ? 22 : 28,
                ),
              ),
              SizedBox(
                width: isMobile
                    ? AppTheme.kSpacingSmall
                    : AppTheme.kSpacingMedium,
              ),
              Expanded(
                child: Text(
                  'Credit Topup Report',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSecondaryContainer,
                    fontSize: isMobile ? 18 : 22,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(
            height: isMobile ? AppTheme.kSpacingMedium : AppTheme.kSpacingLarge,
          ),

          // Credit stats grid
          LayoutBuilder(
            builder: (context, constraints) {
              final useGrid = constraints.maxWidth > 500;

              // Build subtitle for net spent showing refund breakdown
              String netSpentSubtitle =
                  '${creditSummary.spendCount} spend transactions';
              if (creditSummary.refundCount > 0) {
                netSpentSubtitle +=
                    ' (${creditSummary.refundCount} refunds: -${formatCurrency.format(creditSummary.totalCreditsRefunded)})';
              }

              final items = [
                _CreditStatItem(
                  icon: UniconsLine.money_bill,
                  label: 'Total Credit Sold Worth',
                  value: formatCurrency.format(creditSummary.totalCreditsSold),
                  subtitle: '${creditSummary.topUpCount} top-up transactions',
                  color: sem.success,
                ),
                _CreditStatItem(
                  icon: UniconsLine.gift,
                  label: 'Total Credits Allotted Worth',
                  value: formatCurrency.format(
                    creditSummary.totalCreditsAllotted,
                  ),
                  subtitle: 'From memberships & promotions',
                  color: sem.info,
                ),
                _CreditStatItem(
                  icon: UniconsLine.shopping_cart,
                  label: 'Net Credits Spent by Customers',
                  value: formatCurrency.format(creditSummary.totalCreditsSpent),
                  subtitle: netSpentSubtitle,
                  color: sem.warning,
                ),
                _CreditStatItem(
                  icon: UniconsLine.wallet,
                  label: 'Total Credit Balance',
                  value: formatCurrency.format(
                    creditSummary.totalCreditBalance,
                  ),
                  subtitle: 'Current balance across all customers',
                  color: cs.secondary,
                ),
              ];

              if (useGrid) {
                return Wrap(
                  spacing: AppTheme.kSpacingMedium,
                  runSpacing: AppTheme.kSpacingMedium,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width:
                              (constraints.maxWidth - AppTheme.kSpacingMedium) /
                                  2 -
                              1,
                          child: item,
                        ),
                      )
                      .toList(),
                );
              } else {
                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppTheme.kSpacingSmall,
                          ),
                          child: item,
                        ),
                      )
                      .toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _CreditStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _CreditStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);

    return Container(
      padding: EdgeInsets.all(
        isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isMobile ? 16 : 20,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: isMobile ? 18 : 22),
          ),
          SizedBox(
            width: isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.7,
                    ),
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: isMobile ? 16 : 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: isMobile ? 10 : 11,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
