import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_entry.dart';
import '../services/audit_service.dart';
import 'tenant_provider.dart';

final auditServiceProvider = Provider<AuditService?>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return null;
  return AuditService(tenant);
});

final auditLogProvider = StreamProvider<List<AuditEntry>>((ref) {
  final service = ref.watch(auditServiceProvider);
  if (service == null) return Stream.value([]);
  return service.watchRecent();
});
