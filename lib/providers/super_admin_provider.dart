import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/super_admin_service.dart';

final superAdminServiceProvider = Provider<SuperAdminService>((ref) {
  return SuperAdminService();
});

final allCompaniesProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref.watch(superAdminServiceProvider).watchAllCompanies();
});

final allUsersProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref.watch(superAdminServiceProvider).watchAllUsers();
});

final supportTicketsProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref.watch(superAdminServiceProvider).watchSupportTickets();
});

final allReviewsProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref.watch(superAdminServiceProvider).watchAllReviews();
});

final allGuestProfilesProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref.watch(superAdminServiceProvider).watchAllGuestProfiles();
});

final allGuestOrdersProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref.watch(superAdminServiceProvider).watchAllGuestOrders();
});

final allBookingRequestsProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref.watch(superAdminServiceProvider).watchAllBookingRequests();
});

final auditLogProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref.watch(superAdminServiceProvider).watchAuditLog();
});

final announcementsProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  return ref.watch(superAdminServiceProvider).watchAnnouncements();
});

final companyDetailProvider =
    StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>, String>((ref, companyId) {
  return ref.watch(superAdminServiceProvider).watchCompanyDoc(companyId);
});

final companySubcollectionCountsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, companyId) {
  return ref.watch(superAdminServiceProvider).getCompanySubcollectionCounts(companyId);
});
