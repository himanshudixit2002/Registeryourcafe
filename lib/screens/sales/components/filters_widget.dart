import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_panel.dart';
import '../providers/sales_providers.dart';

class FiltersWidget extends ConsumerStatefulWidget {
  const FiltersWidget({super.key});

  @override
  ConsumerState<FiltersWidget> createState() => _FiltersWidgetState();
}

class _FiltersWidgetState extends ConsumerState<FiltersWidget>
    with SingleTickerProviderStateMixin {
  late DateTimeRange _dateRange;
  late String _revenueType;
  late String _paymentMethod;
  String _preset = 'custom';
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  // Helper: Returns the start of the given day at 00:00:00.000
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  // Helper: Returns the end of the given day at 23:59:59.999
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  @override
  void initState() {
    super.initState();
    _dateRange = ref.read(salesDateRangeProvider);
    _revenueType = ref.read(salesRevenueTypeProvider);
    _paymentMethod = ref.read(salesPaymentMethodProvider);
    _preset = _derivePreset(_dateRange);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Determine which preset (Day / Week / Year) the given range corresponds to.
  String _derivePreset(DateTimeRange range) {
    final now = DateTime.now();

    final bool isSameDay =
        range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day;

    if (isSameDay) {
      return 'daily';
    }

    // Range covers the last 7 days exactly
    final DateTime weekAgo = _startOfDay(now.subtract(const Duration(days: 7)));
    if (_startOfDay(range.start).isAtSameMomentAs(weekAgo) &&
        range.end.isAfter(weekAgo)) {
      return 'weekly';
    }

    // Range starts at Jan 1 of current year
    final DateTime startOfYear = DateTime(now.year, 1, 1);
    if (range.start.isAtSameMomentAs(startOfYear)) {
      return 'yearly';
    }

    return 'custom';
  }

  void _applyFilters() {
    HapticFeedback.mediumImpact();
    ref.read(salesDateRangeProvider.notifier).state = _dateRange;
    ref.read(salesRevenueTypeProvider.notifier).state = _revenueType;
    ref.read(salesPaymentMethodProvider.notifier).state = _paymentMethod;
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);
    final dateFormat = DateFormat('dd/MM/yy');

    if (isMobile) {
      return _buildMobileFilters(theme, dateFormat);
    }

    return _buildDesktopFilters(theme, dateFormat);
  }

  Widget _buildMobileFilters(ThemeData theme, DateFormat dateFormat) {
    final cs = theme.colorScheme;
    final hasActiveFilters = _revenueType != 'all' || _paymentMethod != 'all';

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: theme.brightness == Brightness.dark ? 0.35 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Quick date presets - always visible
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with current selection
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sales Report',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Filter toggle button
                    GestureDetector(
                      onTap: _toggleExpanded,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _isExpanded
                                  ? cs.primary
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: AnimatedRotation(
                              duration: const Duration(milliseconds: 200),
                              turns: _isExpanded ? 0.5 : 0,
                              child: Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: _isExpanded
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (hasActiveFilters)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cs.surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Quick date presets
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: AppTheme.scrollPhysicsFor(context),
                    children: [
                      _buildPresetChip('Today', 'daily', Icons.today_rounded),
                      _buildPresetChip(
                        'Week',
                        'weekly',
                        Icons.date_range_rounded,
                      ),
                      _buildPresetChip(
                        'Year',
                        'yearly',
                        Icons.calendar_today_rounded,
                      ),
                      _buildCustomDateButton(dateFormat),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Expandable filters section
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                border: Border(
                  top: BorderSide(color: AppTheme.subtleDividerColor(theme)),
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Revenue type filter
                  Text(
                    'Revenue Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: AppTheme.scrollPhysicsFor(context),
                      children: [
                        _buildFilterChip(
                          'All',
                          'all',
                          _revenueType,
                          (v) => setState(() => _revenueType = v),
                        ),
                        _buildFilterChip(
                          'Table',
                          'table_charges',
                          _revenueType,
                          (v) => setState(() => _revenueType = v),
                        ),
                        _buildFilterChip(
                          'Cafe',
                          'cafe',
                          _revenueType,
                          (v) => setState(() => _revenueType = v),
                        ),
                        _buildFilterChip(
                          'Merch',
                          'merchandise',
                          _revenueType,
                          (v) => setState(() => _revenueType = v),
                        ),
                        _buildFilterChip(
                          'Credit',
                          'credit_topup',
                          _revenueType,
                          (v) => setState(() => _revenueType = v),
                        ),
                        _buildFilterChip(
                          'Tournament',
                          'tournament',
                          _revenueType,
                          (v) => setState(() => _revenueType = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Payment method filter
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: AppTheme.scrollPhysicsFor(context),
                      children: [
                        _buildFilterChip(
                          'All',
                          'all',
                          _paymentMethod,
                          (v) => setState(() => _paymentMethod = v),
                        ),
                        _buildFilterChip(
                          'Cash',
                          'cash',
                          _paymentMethod,
                          (v) => setState(() => _paymentMethod = v),
                        ),
                        _buildFilterChip(
                          'UPI',
                          'upi',
                          _paymentMethod,
                          (v) => setState(() => _paymentMethod = v),
                        ),
                        _buildFilterChip(
                          'Credits',
                          'credit',
                          _paymentMethod,
                          (v) => setState(() => _paymentMethod = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Apply Filters'),
                      onPressed: () {
                        _applyFilters();
                        _toggleExpanded();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String preset, IconData icon) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = _preset == preset;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          final now = DateTime.now();
          setState(() {
            _preset = preset;
            switch (preset) {
              case 'daily':
                _dateRange = DateTimeRange(
                  start: _startOfDay(now),
                  end: _endOfDay(now),
                );
                break;
              case 'weekly':
                _dateRange = DateTimeRange(
                  start: _startOfDay(now.subtract(const Duration(days: 7))),
                  end: _endOfDay(now),
                );
                break;
              case 'yearly':
                _dateRange = DateTimeRange(
                  start: DateTime(now.year, 1, 1),
                  end: _endOfDay(now),
                );
                break;
            }
          });
          _applyFilters();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? cs.primary
                  : cs.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateButton(DateFormat dateFormat) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isCustom = _preset == 'custom';

    return GestureDetector(
      onTap: () async {
        await HapticFeedback.lightImpact();
        if (!mounted) return;
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: _dateRange,
          builder: (context, child) => child!,
        );
        if (picked != null) {
          setState(() {
            _dateRange = DateTimeRange(
              start: _startOfDay(picked.start),
              end: _endOfDay(picked.end),
            );
            _preset = _derivePreset(_dateRange);
          });
          _applyFilters();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isCustom
              ? cs.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCustom ? cs.primary : cs.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_calendar_rounded,
              size: 16,
              color: isCustom
                  ? cs.primary
                  : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Custom',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isCustom
                    ? cs.primary
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onChanged,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = currentValue == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? cs.primary
                  : cs.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFilters(ThemeData theme, DateFormat dateFormat) {
    return AppSurface(
      borderRadius: AppTheme.kBorderRadiusMedium,
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      child: Wrap(
        spacing: AppTheme.kSpacingMedium,
        runSpacing: AppTheme.kSpacingSmall,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Date Range Picker
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now().subtract(
                  const Duration(days: 365 * 5),
                ),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _dateRange,
              );
              if (picked != null) {
                setState(() {
                  _dateRange = DateTimeRange(
                    start: _startOfDay(picked.start),
                    end: _endOfDay(picked.end),
                  );
                  _preset = _derivePreset(_dateRange);
                });
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),

          // Date presets segmented control
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'daily', label: Text('Day')),
              ButtonSegment(value: 'weekly', label: Text('Week')),
              ButtonSegment(value: 'yearly', label: Text('Year')),
            ],
            selected: {_preset},
            onSelectionChanged: (sel) {
              final choice = sel.first;
              final now = DateTime.now();
              setState(() {
                _preset = choice;
                switch (choice) {
                  case 'daily':
                    _dateRange = DateTimeRange(
                      start: _startOfDay(now),
                      end: _endOfDay(now),
                    );
                    break;
                  case 'weekly':
                    _dateRange = DateTimeRange(
                      start: _startOfDay(now.subtract(const Duration(days: 7))),
                      end: _endOfDay(now),
                    );
                    break;
                  case 'yearly':
                    _dateRange = DateTimeRange(
                      start: DateTime(now.year, 1, 1),
                      end: _endOfDay(now),
                    );
                    break;
                }
              });
            },
          ),

          // Revenue Type Dropdown
          _buildDropdown(
            theme,
            value: _revenueType,
            items: const {
              'all': 'All Types',
              'table_charges': 'Table Charges',
              'cafe': 'Cafe',
              'merchandise': 'Merchandise',
              'credit_topup': 'Credit Top-up',
              'tournament': 'Tournament',
            },
            onChanged: (val) => setState(() => _revenueType = val!),
          ),

          // Payment Method Dropdown
          _buildDropdown(
            theme,
            value: _paymentMethod,
            items: const {
              'all': 'All Methods',
              'cash': 'Cash',
              'upi': 'UPI',
              'credit': 'Credits',
            },
            onChanged: (val) => setState(() => _paymentMethod = val!),
          ),

          // Apply Button
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Apply'),
            onPressed: _applyFilters,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    ThemeData theme, {
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButton<String>(
      value: value,
      items: items.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      onChanged: onChanged,
      underline: Container(height: 1, color: theme.dividerColor),
    );
  }
}
