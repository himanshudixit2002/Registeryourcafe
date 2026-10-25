import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tenant_provider.dart';
import '../../services/analytics_data_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class AnalyticsHubScreen extends ConsumerStatefulWidget {
  const AnalyticsHubScreen({super.key});

  @override
  ConsumerState<AnalyticsHubScreen> createState() =>
      _AnalyticsHubScreenState();
}

class _AnalyticsHubScreenState extends ConsumerState<AnalyticsHubScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  Map<String, double>? _revenueByDay;
  Map<String, int>? _tableUtil;
  Map<String, int>? _customerFreq;
  Map<int, double>? _revenueByHour;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final service = AnalyticsDataService(tenant);
    try {
      final results = await Future.wait([
        service.getRevenueByDay(start: _range.start, end: _range.end),
        service.getTableUtilization(start: _range.start, end: _range.end),
        service.getCustomerVisitFrequency(start: _range.start, end: _range.end),
        service.getRevenueByHour(start: _range.start, end: _range.end),
      ]);
      if (!mounted) return;
      setState(() {
        _revenueByDay = results[0] as Map<String, double>;
        _tableUtil = results[1] as Map<String, int>;
        _customerFreq = results[2] as Map<String, int>;
        _revenueByHour = results[3] as Map<int, double>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      _range = picked;
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);
    final pad = isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          TextButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined, size: 18),
            label: Text(
              '${_range.start.day}/${_range.start.month} - ${_range.end.day}/${_range.end.month}',
            ),
          ),
        ],
      ),
      body: _loading
          ? const ShimmerList()
          : SingleChildScrollView(
              physics: AppTheme.scrollPhysicsFor(context),
              padding: EdgeInsets.fromLTRB(
                pad,
                AppTheme.kSpacingMedium,
                pad,
                AppTheme.kSpacingXLarge +
                    MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRevenueSection(theme),
                  const SizedBox(height: 24),
                  _buildPeakHoursSection(theme),
                  const SizedBox(height: 24),
                  _buildTableUtilSection(theme),
                  const SizedBox(height: 24),
                  _buildCustomerSection(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildRevenueSection(ThemeData theme) {
    final data = _revenueByDay ?? {};
    final total = data.values.fold(0.0, (a, b) => a + b);
    final sortedKeys = data.keys.toList()..sort();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue by day',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('\u20B9${total.toStringAsFixed(0)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          if (data.isEmpty)
            Text('No revenue data for this period.',
                style: theme.textTheme.bodySmall)
          else
            SizedBox(
              height: 160,
              child: _BarChartSimple(
                labels: sortedKeys.map((k) => k.substring(5)).toList(),
                values: sortedKeys.map((k) => data[k]!).toList(),
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeakHoursSection(ThemeData theme) {
    final data = _revenueByHour ?? {};
    final hours = List.generate(24, (i) => i);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue by hour',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (data.isEmpty)
            Text('No data for this period.',
                style: theme.textTheme.bodySmall)
          else
            SizedBox(
              height: 160,
              child: _BarChartSimple(
                labels: hours.map((h) => '${h}h').toList(),
                values: hours.map((h) => (data[h] ?? 0).toDouble()).toList(),
                color: theme.colorScheme.tertiary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableUtilSection(ThemeData theme) {
    final data = _tableUtil ?? {};
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Table utilization',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            Text('No session data for this period.',
                style: theme.textTheme.bodySmall)
          else
            for (final e in sorted.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(e.key,
                            style: theme.textTheme.bodyMedium)),
                    Text('${e.value} sessions',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(ThemeData theme) {
    final data = _customerFreq ?? {};
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top customers',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            Text('No customer data for this period.',
                style: theme.textTheme.bodySmall)
          else
            for (final e in sorted.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(e.key,
                            style: theme.textTheme.bodyMedium)),
                    Text('${e.value} visits',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _BarChartSimple extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color color;

  const _BarChartSimple({
    required this.labels,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal =
        values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth =
            (constraints.maxWidth / values.length).clamp(4.0, 24.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < values.length; i++)
              Tooltip(
                message: '${labels[i]}: ${values[i].toStringAsFixed(0)}',
                child: Container(
                  width: barWidth - 2,
                  height: (values[i] / maxVal * constraints.maxHeight)
                      .clamp(2.0, constraints.maxHeight),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
