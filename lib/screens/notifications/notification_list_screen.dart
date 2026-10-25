import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(notificationsProvider);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                final service = ref.read(notificationServiceProvider);
                if (service == null) return;
                await service.markAllAsRead();
                if (context.mounted) {
                  context.showSuccessSnackbar('All marked as read');
                }
              } catch (e) {
                if (context.mounted) {
                  context.showErrorSnackbar('Failed: $e');
                }
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text('No notifications', style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }
          return ListView.separated(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.fromLTRB(
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingSmall,
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingXLarge + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return _NotificationTile(notification: n);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.order:
        return Icons.receipt_long_outlined;
      case NotificationType.session:
        return Icons.table_bar_outlined;
      case NotificationType.booking:
        return Icons.event_seat_outlined;
      case NotificationType.lowStock:
        return Icons.inventory_2_outlined;
      case NotificationType.tournament:
        return Icons.emoji_events_outlined;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return Material(
      color: isUnread
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isUnread) {
            final service = ref.read(notificationServiceProvider);
            if (service == null) return;
            service.markAsRead(notification.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _icon,
                size: 24,
                color: isUnread
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notification.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
