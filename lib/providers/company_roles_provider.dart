import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/company_role.dart';
import '../services/company_roles_service.dart';
import 'tenant_provider.dart';

final companyRolesListProvider = StreamProvider<List<CompanyRole>>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value([]);
  return CompanyRolesService(FirebaseFirestore.instance).rolesStream(tenant);
});
