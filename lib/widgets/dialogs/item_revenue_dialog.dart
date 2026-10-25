import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/stock_item.dart';
import '../../services/item_revenue_service.dart';
import '../glass_panel.dart';

class ItemRevenueDialog extends StatefulWidget {
  final StockItem item;
  const ItemRevenueDialog({super.key, required this.item});

  @override
  State<ItemRevenueDialog> createState() => _ItemRevenueDialogState();
}

class _ItemRevenueDialogState extends State<ItemRevenueDialog> {
  final ItemRevenueService _revenueService = ItemRevenueService();
  double? _revenueToday;
  double? _revenueTillDate;
  double? _revenueRange; // revenue for custom range
  // Holds the currently selected date range (normalized to full-day boundaries)
  late DateTimeRange _selectedRange;
  bool _loading = true;
  String? _error;

  // Quick-select preset ranges
  final List<_PresetRange> _presets = [];
  int? _selectedPreset; // index in presets or null

  @override
  void initState() {
    super.initState();
    // Default selection is today.
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    _selectedRange = DateTimeRange(start: startOfToday, end: endOfToday);

    _buildPresets();
    _fetchData();
  }

  void _buildPresets() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final startOfThisWeek = startOfToday.subtract(
      Duration(days: startOfToday.weekday - 1),
    );
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfPrevMonth = DateTime(now.year, now.month - 1, 1);
    final endOfPrevMonth = DateTime(
      now.year,
      now.month,
      1,
    ).subtract(const Duration(milliseconds: 1));

    _presets.addAll([
      _PresetRange(
        'Today',
        DateTimeRange(start: startOfToday, end: endOfToday),
      ),
      _PresetRange(
        'Last 7 Days',
        DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: endOfToday,
        ),
      ),
      _PresetRange(
        'This Week',
        DateTimeRange(start: startOfThisWeek, end: endOfToday),
      ),
      _PresetRange(
        'Last Week',
        DateTimeRange(
          start: startOfLastWeek,
          end: startOfThisWeek.subtract(const Duration(milliseconds: 1)),
        ),
      ),
      _PresetRange(
        'This Month',
        DateTimeRange(start: startOfMonth, end: endOfToday),
      ),
      _PresetRange(
        'Prev Month',
        DateTimeRange(start: startOfPrevMonth, end: endOfPrevMonth),
      ),
    ]);
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = startOfToday
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      final todayRange = DateTimeRange(start: startOfToday, end: endOfToday);
      // Ensure we always query inclusive of the entire day boundaries.
      final selectedRange = _expandToFullDays(_selectedRange);

      final futures = <Future<double>>[
        _revenueService.calculateRevenue(
          itemId: widget.item.id,
          dateRange: todayRange,
        ),
        _revenueService.calculateRevenue(itemId: widget.item.id),
        _revenueService.calculateRevenue(
          itemId: widget.item.id,
          dateRange: selectedRange,
        ),
      ];
      final results = await Future.wait(futures);
      setState(() {
        _revenueToday = results[0];
        _revenueTillDate = results[1];
        _revenueRange = results[2];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedRange,
      firstDate: DateTime(2000), // allow navigating to further past months
      lastDate: DateTime.now(),
      helpText: 'Select custom date range',
    );
    if (picked != null) {
      setState(() => _selectedRange = _expandToFullDays(picked));
      await _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.item.name} Revenue'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minHeight: 280),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _loading
              ? const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
              ? SizedBox(
                  height: 280,
                  child: Center(child: Text('Error: $_error')),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _metricCard(
                      label: 'Today',
                      amount: _revenueToday ?? 0.0,
                      icon: Icons.today,
                    ),
                    const SizedBox(height: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _metricCard(
                          label: _formatRange(_selectedRange),
                          amount: _revenueRange ?? 0.0,
                          icon: Icons.timeline,
                        ),
                        const SizedBox(height: 8),
                        // Preset chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Wrap(
                            spacing: 6,
                            children: List.generate(_presets.length, (index) {
                              final preset = _presets[index];
                              final selected = _selectedPreset == index;
                              return ChoiceChip(
                                label: Text(preset.label),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedPreset = index;
                                    _selectedRange = _expandToFullDays(
                                      preset.range,
                                    );
                                  });
                                  _fetchData();
                                },
                              );
                            }),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickRange,
                          icon: const Icon(Icons.date_range),
                          label: const Text('Custom'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _metricCard(
                      label: 'Total till date',
                      amount: _revenueTillDate ?? 0.0,
                      icon: Icons.all_inclusive,
                    ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required double amount,
    required IconData icon,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return AppSurface(
      margin: EdgeInsets.zero,
      borderRadius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          Text(
            currency.format(amount),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatRange(DateTimeRange range) {
    final fmt = DateFormat('dd MMM');
    if (range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day) {
      return fmt.format(range.start);
    }
    return "${fmt.format(range.start)} - ${fmt.format(range.end)}";
  }

  // --- Helpers ------------------------------------------------------------

  /// Expands the provided [range] so that its start is set to the first moment
  /// of the starting day (00:00:00) and its end is set to the very last moment
  /// of the ending day (23:59:59.999). This guarantees correct inclusivity
  /// when querying Firestore using `isLessThanOrEqualTo`.
  DateTimeRange _expandToFullDays(DateTimeRange range) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    ).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    return DateTimeRange(start: start, end: end);
  }
}

class _PresetRange {
  final String label;
  final DateTimeRange range;

  _PresetRange(this.label, this.range);
}
