import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';

import '../../../models/sales_transaction.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/sales_palette.dart';
import '../../../widgets/glass_panel.dart';

class SummaryCardsWidget extends StatelessWidget {
  final SalesDataSummary summary;
  const SummaryCardsWidget({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.simpleCurrency(
      locale: 'en_IN',
      decimalDigits: 0,
    );
    final isMobile = AppTheme.isMobile(context);

    final avgTransactionValue = summary.totalTransactions > 0
        ? summary.totalRevenue / summary.totalTransactions
        : 0.0;

    final double totalRefunds = summary.transactions
        .where((t) => t.total < 0 || t.paidTotal < 0)
        .fold(0.0, (sum, t) {
          if (t.total == 0 && t.paidTotal > 0) {
            return sum;
          }
          return sum + t.paidTotal + t.creditsUsed;
        });

    // Build breakdown data
    final revenueBreakdown = {
      'Table': summary.revenueByType['Table Charges'] ?? 0.0,
      'Cafe': summary.revenueByType['Cafe'] ?? 0.0,
      'Merch': summary.revenueByType['Merchandise'] ?? 0.0,
      'Tournament': summary.revenueByType['Tournament'] ?? 0.0,
      'Credit': summary.revenueByType['Credit Top-up'] ?? 0.0,
    };

    final txCountBreakdown = {
      'Table': summary.transactions.where((t) => t.tableCharges > 0).length,
      'Cafe': summary.transactions.where((t) => t.cafeCharges > 0).length,
      'Merch': summary.transactions
          .where((t) => t.merchandiseCharges > 0)
          .length,
      'Tournament': summary.transactions
          .where((t) => t.tournamentCharges > 0)
          .length,
      'Credit': summary.transactions
          .where((t) => t.type == TransactionType.credit)
          .length,
    };

    if (isMobile) {
      return _buildMobileLayout(
        context,
        formatCurrency,
        avgTransactionValue,
        totalRefunds,
        revenueBreakdown,
        txCountBreakdown,
      );
    }

    return _buildDesktopLayout(
      context,
      formatCurrency,
      avgTransactionValue,
      totalRefunds,
      revenueBreakdown,
      txCountBreakdown,
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    NumberFormat formatCurrency,
    double avgTransactionValue,
    double totalRefunds,
    Map<String, double> revenueBreakdown,
    Map<String, int> txCountBreakdown,
  ) {
    return Column(
      children: [
        // Main stats row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: UniconsLine.invoice,
                label: 'Revenue',
                value: formatCurrency.format(summary.totalRevenue),
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                context,
                icon: UniconsLine.transaction,
                label: 'Transactions',
                value: summary.totalTransactions.toString(),
                color: AppTheme.warningColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: UniconsLine.receipt_alt,
                label: 'Avg Value',
                value: formatCurrency.format(avgTransactionValue),
                color: AppTheme.infoColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                context,
                icon: UniconsLine.money_withdraw,
                label: 'Refunds',
                value: formatCurrency.format(totalRefunds.abs()),
                color: AppTheme.errorColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Revenue breakdown card
        _buildBreakdownCard(
          context,
          title: 'Revenue by Type',
          breakdown: revenueBreakdown,
          formatCurrency: formatCurrency,
          showCurrency: true,
        ),
        const SizedBox(height: 8),
        // Transaction count breakdown card
        _buildBreakdownCard(
          context,
          title: 'Transactions by Type',
          breakdown: txCountBreakdown.map((k, v) => MapEntry(k, v.toDouble())),
          formatCurrency: formatCurrency,
          showCurrency: false,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(
    BuildContext context, {
    required String title,
    required Map<String, double> breakdown,
    required NumberFormat formatCurrency,
    required bool showCurrency,
  }) {
    final nonZero = breakdown.entries.where((e) => e.value > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: nonZero.map((entry) {
              final color = SalesPalette.revenueKey(context, entry.key);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      showCurrency
                          ? formatCurrency.format(entry.value)
                          : entry.value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    NumberFormat formatCurrency,
    double avgTransactionValue,
    double totalRefunds,
    Map<String, double> revenueBreakdown,
    Map<String, int> txCountBreakdown,
  ) {
    return Column(
      children: [
        // Top row: 4 main stat cards
        Row(
          children: [
            Expanded(
              child: _buildDesktopStatCard(
                context,
                icon: UniconsLine.invoice,
                label: 'Total Revenue',
                value: formatCurrency.format(summary.totalRevenue),
                color: AppTheme.successColor,
                breakdown: revenueBreakdown,
                formatCurrency: formatCurrency,
                showCurrency: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDesktopStatCard(
                context,
                icon: UniconsLine.transaction,
                label: 'Total Transactions',
                value: summary.totalTransactions.toString(),
                color: AppTheme.warningColor,
                breakdown: txCountBreakdown.map(
                  (k, v) => MapEntry(k, v.toDouble()),
                ),
                formatCurrency: formatCurrency,
                showCurrency: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDesktopStatCard(
                context,
                icon: UniconsLine.receipt_alt,
                label: 'Avg. Transaction',
                value: formatCurrency.format(avgTransactionValue),
                color: AppTheme.infoColor,
                breakdown: const {},
                formatCurrency: formatCurrency,
                showCurrency: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDesktopStatCard(
                context,
                icon: UniconsLine.money_withdraw,
                label: 'Total Refunds',
                value: formatCurrency.format(totalRefunds.abs()),
                color: AppTheme.errorColor,
                breakdown: const {},
                formatCurrency: formatCurrency,
                showCurrency: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Map<String, double> breakdown,
    required NumberFormat formatCurrency,
    required bool showCurrency,
  }) {
    final nonZero = breakdown.entries.where((e) => e.value > 0).toList();

    return AppSurface(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      borderColor: color.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Breakdown
          if (nonZero.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ...nonZero.map((entry) {
              final typeColor = SalesPalette.revenueKey(context, entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      showCurrency
                          ? formatCurrency.format(entry.value)
                          : entry.value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

}
