import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore/tenant_firestore.dart';
import 'auth_provider.dart';

/// Resolves the signed-in user's company tenant. Null if not loaded or legacy user without [AppUser.companyId].
final tenantRefProvider = Provider<TenantRef?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  final cid = user?.companyId;
  if (cid == null || cid.isEmpty) return null;
  return TenantRef(FirebaseFirestore.instance, cid);
});

final currentCompanyIdProvider = Provider<String?>((ref) {
  return ref.watch(appUserProvider).valueOrNull?.companyId;
});
