import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message_template.dart';
import '../services/message_template_service.dart';
import 'tenant_provider.dart';

final messageTemplateServiceProvider = Provider<MessageTemplateService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return MessageTemplateService(tenant);
});

final messageTemplatesProvider = StreamProvider<List<MessageTemplate>>((ref) {
  final service = ref.watch(messageTemplateServiceProvider);
  if (service == null) return Stream.value([]);
  return service.watchTemplates();
});
