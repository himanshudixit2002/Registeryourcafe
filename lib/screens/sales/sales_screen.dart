import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/permission_id.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../widgets/constrained_page_content.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/responsive_scaffold.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/shimmer_skeleton.dart';
import 'components/filters_widget.dart';
import 'components/payment_method_breakdown_widget.dart';
import 'components/revenue_type_breakdown_widget.dart';
import 'components/summary_cards_widget.dart';
import 'components/transactions_list_widget.dart';
import 'components/breakdown_table_widget.dart';
import 'components/credit_report_widget.dart';
import 'providers/sales_providers.dart';
import 'services/sales_csv_exporter.dart';
import '../../providers/tenant_provider.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  bool _showTransactions = false;

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.navSales)) {
      return const ResponsiveScaffold(
        title: 'Sales & Revenue',
        useAppBar: false,
        body: Center(
          child: EmptyStateWidget(
            icon: Icons.lock_outline_rounded,
            message: 'You do not have access to sales.',
            details: 'Contact your admin to gain access.',
          ),
        ),
      );
    }

    final salesDataAsync = ref.watch(salesDataSummaryProvider);
    final isMobile = AppTheme.isMobile(context);

    return ResponsiveScaffold(
      title: 'Sales & Revenue',
      useAppBar: false,
      body: Column(
        children: [
          const ScreenHeader(
            title: 'Sales & Revenue',
            icon: Icons.point_of_sale_rounded,
            subtitle: 'Track revenue, payments and transactions',
          ),
          Expanded(
            child: ConstrainedPageContent(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(salesDataSummaryProvider);
                },
                child: SingleChildScrollView(
                  physics: AppTheme.scrollPhysicsFor(context),
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.kSpacingMedium,
                    AppTheme.kSpacingMedium,
                    AppTheme.kSpacingMedium,
                    AppTheme.kSpacingMedium + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FiltersWidget(),
                      const SizedBox(height: AppTheme.kSpacingMedium),
                      salesDataAsync.when(
                        loading: () => _buildLoadingSkeleton(isMobile),
                        error: (err, stack) {
                          AppLogger.error(
                            'Error loading sales data',
                            error: err,
                            stackTrace: stack,
                            tag: 'SalesScreen',
                          );
                          return ErrorStateWidget(
                            message: 'Error loading sales data',
                            details: err.toString(),
                            onRetry: () => ref.invalidate(salesDataSummaryProvider),
                          );
                        },
                        data: (summary) {
                          if (summary.transactions.isEmpty && !summary.isLoading) {
                            return const EmptyStateWidget(
                              icon: Icons.receipt_long_outlined,
                              message: 'No sales data found',
                              details: 'Try adjusting your date range or filters.',
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.download, size: 18),
                                    label: Text(
                                      'Export CSV',
                                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                                    ),
                                    onPressed: () async {
                                      final tenant = ref.read(tenantRefProvider);
                                      if (tenant == null) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('No company context'),
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                      final path = await SalesCsvExporter.export(
                                        summary,
                                        tenant: tenant,
                                      );
                                      if (path == null && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to export CSV.'),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.kSpacingMedium),
                              SummaryCardsWidget(summary: summary),
                              const SizedBox(height: AppTheme.kSpacingMedium),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool useRow = constraints.maxWidth > 800;
                                  return Flex(
                                    direction: useRow ? Axis.horizontal : Axis.vertical,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        flex: useRow ? 1 : 0,
                                        child: RevenueTypeBreakdownWidget(
                                          summary: summary,
                                        ),
                                      ),
                                      if (useRow)
                                        const SizedBox(width: AppTheme.kSpacingMedium),
                                      if (!useRow)
                                        const SizedBox(height: AppTheme.kSpacingMedium),
                                      Expanded(
                                        flex: useRow ? 1 : 0,
                                        child: PaymentMethodBreakdownWidget(
                                          summary: summary,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: AppTheme.kSpacingMedium),
                              BreakdownTableWidget(summary: summary),
                              const SizedBox(height: AppTheme.kSpacingMedium),
                              CreditReportWidget(creditSummary: summary.creditSummary),
                              const SizedBox(height: AppTheme.kSpacingMedium),
                              ExpansionTile(
                                initiallyExpanded: false,
                                onExpansionChanged: (expanded) {
                                  setState(() => _showTransactions = expanded);
                                },
                                title: Text(
                                  'Recent Transactions',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                children: _showTransactions
                                    ? [
                                        const SizedBox(height: AppTheme.kSpacingSmall),
                                        TransactionsListWidget(
                                          transactions: summary.transactions,
                                        ),
                                      ]
                                    : [],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ShimmerSkeleton(
                height: isMobile ? 80 : 100,
                borderRadius: AppTheme.kBorderRadiusMedium,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ShimmerSkeleton(
                height: isMobile ? 80 : 100,
                borderRadius: AppTheme.kBorderRadiusMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ShimmerSkeleton(
                height: isMobile ? 80 : 100,
                borderRadius: AppTheme.kBorderRadiusMedium,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ShimmerSkeleton(
                height: isMobile ? 80 : 100,
                borderRadius: AppTheme.kBorderRadiusMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ShimmerSkeleton(
          height: isMobile ? 200 : 260,
          borderRadius: AppTheme.kBorderRadiusLarge,
        ),
      ],
    );
  }
}
