import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/permission_id.dart';
import '../../models/loyalty_conversion.dart';
import '../../providers/loyalty_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/permission_denied_scaffold.dart';
import '../../widgets/section_async_error.dart';

class LoyaltyConversionHistoryScreen extends ConsumerStatefulWidget {
  const LoyaltyConversionHistoryScreen({super.key});

  @override
  ConsumerState<LoyaltyConversionHistoryScreen> createState() =>
      _LoyaltyConversionHistoryScreenState();
}

class _LoyaltyConversionHistoryScreenState
    extends ConsumerState<LoyaltyConversionHistoryScreen> {
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!ref.watchResolvedPermissions().can(PermissionIds.navLoyalty)) {
      return const PermissionDeniedScaffold(
        title: 'Conversion History',
        message: 'You do not have access to loyalty.',
      );
    }

    final conversionsAsync = ref.watch(loyaltyConversionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversion History'),
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: Icon(
              _dateRange != null ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _dateRange != null ? theme.colorScheme.primary : null,
            ),
            tooltip: 'Filter by date',
            onPressed: _selectDateRange,
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              tooltip: 'Clear filter',
              onPressed: () => setState(() => _dateRange = null),
            ),
        ],
      ),
      body: conversionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SectionAsyncError(error: e),
        data: (conversions) {
          final filtered = _applyDateFilter(conversions);
          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 56,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No conversions found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (_dateRange != null)
                    TextButton(
                      onPressed: () => setState(() => _dateRange = null),
                      child: const Text('Clear date filter'),
                    ),
                ],
              ),
            );
          }

          return _buildList(context, theme, filtered);
        },
      ),
    );
  }

  List<LoyaltyConversion> _applyDateFilter(List<LoyaltyConversion> all) {
    if (_dateRange == null) return all;
    final start = _dateRange!.start;
    final end = _dateRange!.end.add(const Duration(days: 1));
    return all
        .where(
          (c) => c.convertedAt.isAfter(start) && c.convertedAt.isBefore(end),
        )
        .toList();
  }

  Widget _buildList(
    BuildContext context,
    ThemeData theme,
    List<LoyaltyConversion> list,
  ) {
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final totalPoints = list.fold<double>(0, (s, c) => s + c.pointsConverted);
    final totalCredits = list.fold<double>(0, (s, c) => s + c.creditsAwarded);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Column(
      children: [
        // Summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              _summaryChip(
                context,
                'Conversions',
                list.length.toString(),
                Icons.swap_horiz,
                cs.primary,
              ),
              const SizedBox(width: 12),
              _summaryChip(
                context,
                'Points',
                totalPoints.toStringAsFixed(0),
                Icons.stars_rounded,
                sem.warning,
              ),
              const SizedBox(width: 12),
              _summaryChip(
                context,
                'Credits',
                totalCredits.toStringAsFixed(0),
                Icons.account_balance_wallet,
                sem.success,
              ),
            ],
          ),
        ),
        if (_dateRange != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: Text(
              'Filtered: ${DateFormat('dd MMM yyyy').format(_dateRange!.start)} '
              '- ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = list[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(
                    AppTheme.kBorderRadiusMedium,
                  ),
                  boxShadow: AppTheme.cardShadowFor(theme.brightness),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: sem.warningContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.swap_horiz,
                        color: sem.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.customerName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFmt.format(c.convertedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (c.performedByName != null)
                            Text(
                              'by ${c.performedByName}',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.outline,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '- ${c.pointsConverted.toStringAsFixed(0)} pts',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.error,
                          ),
                        ),
                        Text(
                          '+ ${c.creditsAwarded.toStringAsFixed(0)} cr',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sem.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusSmall),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }
}
