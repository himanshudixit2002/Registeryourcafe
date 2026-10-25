import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

class SessionActivityTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> activityLog;

  const SessionActivityTimeline({super.key, required this.activityLog});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (activityLog.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timeline, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                'No activity recorded',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by timestamp descending (newest first)
    final sorted = List<Map<String, dynamic>>.from(activityLog);
    sorted.sort((a, b) {
      final aTime = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bTime = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final activity = sorted[index];
        final isLast = index == sorted.length - 1;
        return _buildActivityItem(context, activity, isLast);
      },
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    Map<String, dynamic> activity,
    bool isLast,
  ) {
    final theme = Theme.of(context);
    final type = activity['type'] as String? ?? 'unknown';
    final description = activity['description'] as String? ?? 'Activity';
    final timestamp = (activity['timestamp'] as Timestamp?)?.toDate();
    final performedByName = activity['performedByName'] as String?;
    final performedByRole = activity['performedByRole'] as String?;
    final metadata = activity['metadata'] as Map<String, dynamic>?;

    final icon = _getIconForType(type);
    final color = _getColorForType(type, context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator column
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (timestamp != null)
                    Text(
                      DateFormat('MMM dd, yyyy · hh:mm a').format(timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  if (performedByName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$performedByName${performedByRole != null ? ' ($performedByRole)' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (metadata != null && metadata.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: metadata.entries
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  '${_formatKey(e.key)}: ${_formatValue(e.value)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'session_started':
        return Icons.play_circle_outline;
      case 'cafe_order_added':
        return Icons.restaurant_outlined;
      case 'merch_order_added':
        return Icons.shopping_bag_outlined;
      case 'order_refunded':
        return Icons.reply_all_outlined;
      case 'session_completed':
        return Icons.check_circle_outline;
      case 'session_cancelled':
        return Icons.cancel_outlined;
      case 'discount_applied':
        return Icons.discount_outlined;
      case 'payment_received':
        return Icons.payment_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getColorForType(String type, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (type) {
      case 'session_started':
        return sem.success;
      case 'cafe_order_added':
      case 'merch_order_added':
        return sem.info;
      case 'order_refunded':
        return cs.error;
      case 'session_completed':
        return cs.tertiary;
      case 'session_cancelled':
        return sem.warning;
      case 'discount_applied':
        return cs.secondary;
      case 'payment_received':
        return cs.primary;
      default:
        return cs.outline;
    }
  }

  String _formatKey(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .trim()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatValue(dynamic value) {
    if (value is num) {
      return value is double
          ? '₹${value.toStringAsFixed(2)}'
          : value.toString();
    }
    if (value is Timestamp) {
      return DateFormat('MMM dd, hh:mm a').format(value.toDate());
    }
    return value.toString();
  }
}
