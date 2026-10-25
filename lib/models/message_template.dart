import 'package:cloud_firestore/cloud_firestore.dart';

class MessageTemplate {
  final String id;
  final String name;
  final String body;
  final String? channel;
  final DateTime createdAt;

  const MessageTemplate({
    required this.id,
    required this.name,
    required this.body,
    this.channel = 'whatsapp',
    required this.createdAt,
  });

  factory MessageTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageTemplate(
      id: doc.id,
      name: data['name'] as String? ?? '',
      body: data['body'] as String? ?? '',
      channel: data['channel'] as String? ?? 'whatsapp',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'body': body,
      'channel': channel,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String resolve(Map<String, String> vars) {
    var result = body;
    for (final entry in vars.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }
}
