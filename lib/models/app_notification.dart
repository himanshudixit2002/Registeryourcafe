import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  order,
  session,
  booking,
  lowStock,
  tournament,
  system;

  static NotificationType parse(String? value) {
    if (value == null) return NotificationType.system;
    for (final t in NotificationType.values) {
      if (t.name == value) return t;
    }
    return NotificationType.system;
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? targetId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.targetId,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: NotificationType.parse(data['type'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      targetId: data['targetId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      if (targetId != null) 'targetId': targetId,
    };
  }
}
