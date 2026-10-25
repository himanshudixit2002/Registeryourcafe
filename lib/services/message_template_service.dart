import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/message_template.dart';

class MessageTemplateService {
  final TenantRef _tenant;

  MessageTemplateService(this._tenant);

  CollectionReference<Map<String, dynamic>> _col() =>
      _tenant.messageTemplates();

  Stream<List<MessageTemplate>> watchTemplates() {
    return _col()
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(MessageTemplate.fromFirestore).toList());
  }

  Future<void> createTemplate(MessageTemplate template) async {
    await _col().add(template.toFirestore());
  }

  Future<void> updateTemplate(String id, String name, String body) async {
    await _col().doc(id).update({'name': name, 'body': body});
  }

  Future<void> deleteTemplate(String id) async {
    await _col().doc(id).delete();
  }
}
