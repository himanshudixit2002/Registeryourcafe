import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderHistoryFilter extends StatelessWidget {
  final DateTimeRange? selectedDateRange;
  final String? selectedStatus;
  final List<String> statusOptions;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final ValueChanged<String?> onStatusChanged;

  const OrderHistoryFilter({
    super.key,
    this.selectedDateRange,
    this.selectedStatus,
    this.statusOptions = const [
      'all',
      'pending',
      'delivered',
      'cancelled',
      'refunded',
    ],
    required this.onDateRangeChanged,
    required this.onStatusChanged,
  });

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: selectedDateRange,
      builder: (context, child) => child!,
    );

    if (picked != null && picked != selectedDateRange) {
      onDateRangeChanged(
        DateTimeRange(
          start: picked.start,
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        ),
      );
    }
  }

  String _formatDateRange() {
    if (selectedDateRange == null) return 'Filter by Date Range';
    final formatter = DateFormat.yMd();
    return '${formatter.format(selectedDateRange!.start)} - ${formatter.format(selectedDateRange!.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(_formatDateRange()),
              onPressed: () => _pickDateRange(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          if (selectedDateRange != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear date filter',
              onPressed: () => onDateRangeChanged(null),
            ),
          ],
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                hint: const Text('Status'),
                value: selectedStatus ?? 'all',
                items: statusOptions
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  onStatusChanged(value == 'all' ? null : value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderHistoryQueryBuilder {
  final String collection;
  final DateTimeRange? dateRange;
  final String? status;
  final List<String> defaultStatuses;

  OrderHistoryQueryBuilder({
    required this.collection,
    this.dateRange,
    this.status,
    this.defaultStatuses = const [
      'pending',
      'delivered',
      'completed',
      'cancelled',
      'refunded',
    ],
  });

  /// Build query parameters as a map for easier debugging.
  Map<String, dynamic> get queryParams => {
    'collection': collection,
    'dateRange': dateRange != null
        ? '${dateRange!.start} - ${dateRange!.end}'
        : null,
    'status': status,
  };
}
