import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_provider.dart';
import '../screens/notifications/notification_list_screen.dart';
import '../theme/app_page_transitions.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadNotificationCountProvider);
    final count = countAsync.valueOrNull ?? 0;
    final theme = Theme.of(context);

    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(fontSize: 10),
        ),
        child: Icon(
          count > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_outlined,
          color: theme.colorScheme.onSurface,
        ),
      ),
      tooltip: 'Notifications',
      onPressed: () {
        Navigator.of(context).push(
          AppMaterialPageRoute<void>(
            builder: (_) => const NotificationListScreen(),
          ),
        );
      },
    );
  }
}
