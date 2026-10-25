import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/communication.dart';

class CommunicationService {
  final TenantRef _tenant;
  CommunicationService(this._tenant);

  CollectionReference<Map<String, dynamic>> _chat() =>
      _tenant.companyDoc().collection('staffChat');
  CollectionReference<Map<String, dynamic>> _reminders() =>
      _tenant.companyDoc().collection('autoReminders');
  CollectionReference<Map<String, dynamic>> _commLog() =>
      _tenant.companyDoc().collection('communicationLog');

  Future<void> sendMessage(ChatMessage msg) async =>
      await _chat().add(msg.toFirestore());

  Stream<List<ChatMessage>> watchChat({int limit = 100}) => _chat()
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());

  Future<void> saveReminder(AutoReminder reminder) async =>
      await _reminders().add(reminder.toFirestore());

  Stream<List<AutoReminder>> watchReminders() => _reminders()
      .snapshots()
      .map((s) => s.docs.map(AutoReminder.fromFirestore).toList());

  Future<void> toggleReminder(String id, bool active) async =>
      await _reminders().doc(id).update({'isActive': active});

  Future<void> logCommunication({
    required String customerName,
    required String channel,
    required String summary,
  }) async {
    await _commLog().add({
      'customerName': customerName,
      'channel': channel,
      'summary': summary,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
