import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/app_notification.dart';

class NotificationService {
  final TenantRef _tenant;

  NotificationService(this._tenant);

  CollectionReference<Map<String, dynamic>> _col() =>
      _tenant.companyDoc().collection('notifications');

  Stream<List<AppNotification>> watchRecent({int limit = 50}) {
    return _col()
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotification.fromFirestore).toList());
  }

  Stream<int> watchUnreadCount() {
    return _col()
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  Future<void> markAsRead(String notificationId) async {
    await _col().doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final unread = await _col().where('isRead', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = _tenant.db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> createNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? targetId,
  }) async {
    final notification = AppNotification(
      id: '',
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      targetId: targetId,
    );
    await _col().add(notification.toFirestore());
  }

  Future<void> deleteNotification(String id) async {
    await _col().doc(id).delete();
  }
}
