import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String message;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      senderUid: d['senderUid'] as String? ?? '',
      senderName: d['senderName'] as String? ?? '',
      message: d['message'] as String? ?? '',
      timestamp:
          (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'senderUid': senderUid,
        'senderName': senderName,
        'message': message,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}

class AutoReminder {
  final String id;
  final String type;
  final String message;
  final int triggerDaysBefore;
  final bool isActive;

  const AutoReminder({
    required this.id,
    required this.type,
    required this.message,
    required this.triggerDaysBefore,
    this.isActive = true,
  });

  factory AutoReminder.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AutoReminder(
      id: doc.id,
      type: d['type'] as String? ?? '',
      message: d['message'] as String? ?? '',
      triggerDaysBefore: (d['triggerDaysBefore'] as num?)?.toInt() ?? 1,
      isActive: d['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'message': message,
        'triggerDaysBefore': triggerDaysBefore,
        'isActive': isActive,
      };
}
