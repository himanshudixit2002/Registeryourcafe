import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'tenant_provider.dart';

final notificationServiceProvider = Provider<NotificationService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return NotificationService(tenant);
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  if (service == null) return Stream.value([]);
  return service.watchRecent();
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(notificationServiceProvider);
  if (service == null) return Stream.value(0);
  return service.watchUnreadCount();
});
