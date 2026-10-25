import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/staff_member.dart';
import '../services/staff_service.dart';
import 'tenant_provider.dart';

final staffServiceProvider = Provider<StaffService?>((ref) {
  final cid = ref.watch(currentCompanyIdProvider);
  if (cid == null || cid.isEmpty) return null;
  return StaffService(FirebaseFirestore.instance, cid);
});

final companyStaffProvider = StreamProvider<List<StaffMember>>((ref) {
  final service = ref.watch(staffServiceProvider);
  if (service == null) return Stream.value([]);
  return service.watchStaff();
});
