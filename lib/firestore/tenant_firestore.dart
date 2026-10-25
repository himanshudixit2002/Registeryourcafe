import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_collections.dart';

/// All tenant-scoped collections live under `companies/{companyId}/…`.
///
/// [users] remain at the Firestore root: `users/{uid}` with a [companyId] field.
class TenantRef {
  final FirebaseFirestore db;
  final String companyId;

  const TenantRef(this.db, this.companyId);

  DocumentReference<Map<String, dynamic>> companyDoc() =>
      db.collection(FirestoreCollections.companies).doc(companyId);

  CollectionReference<Map<String, dynamic>> _c(String name) =>
      companyDoc().collection(name);

  CollectionReference<Map<String, dynamic>> customers() =>
      _c(FirestoreCollections.customers);
  CollectionReference<Map<String, dynamic>> tables() =>
      _c(FirestoreCollections.tables);
  CollectionReference<Map<String, dynamic>> tableTypeDefinitions() =>
      _c(FirestoreCollections.tableTypeDefinitions);
  CollectionReference<Map<String, dynamic>> sessions() =>
      _c(FirestoreCollections.sessions);
  CollectionReference<Map<String, dynamic>> cafeOrders() =>
      _c(FirestoreCollections.cafeOrders);
  CollectionReference<Map<String, dynamic>> merchandiseOrders() =>
      _c(FirestoreCollections.merchandiseOrders);
  CollectionReference<Map<String, dynamic>> stockItems() =>
      _c(FirestoreCollections.stockItems);
  CollectionReference<Map<String, dynamic>> categories() =>
      _c(FirestoreCollections.categories);
  CollectionReference<Map<String, dynamic>> orderCounters() =>
      _c(FirestoreCollections.orderCounters);
  CollectionReference<Map<String, dynamic>> membershipCounters() =>
      _c(FirestoreCollections.membershipCounters);
  CollectionReference<Map<String, dynamic>> membershipTypeDefinitions() =>
      _c(FirestoreCollections.membershipTypeDefinitions);
  CollectionReference<Map<String, dynamic>> leaderboardSettings() =>
      _c(FirestoreCollections.leaderboardSettings);
  CollectionReference<Map<String, dynamic>> gameMatches() =>
      _c(FirestoreCollections.gameMatches);
  CollectionReference<Map<String, dynamic>> salesTransactions() =>
      _c(FirestoreCollections.salesTransactions);
  CollectionReference<Map<String, dynamic>> tournaments() =>
      _c(FirestoreCollections.tournaments);
  CollectionReference<Map<String, dynamic>> tournamentParticipants() =>
      _c(FirestoreCollections.tournamentParticipants);
  CollectionReference<Map<String, dynamic>> tournamentMatches() =>
      _c(FirestoreCollections.tournamentMatches);
  CollectionReference<Map<String, dynamic>> tournamentRegistrations() =>
      _c(FirestoreCollections.tournamentRegistrations);
  CollectionReference<Map<String, dynamic>> loyaltyConversions() =>
      _c(FirestoreCollections.loyaltyConversions);
  CollectionReference<Map<String, dynamic>> loyaltySettings() =>
      _c(FirestoreCollections.loyaltySettings);
  CollectionReference<Map<String, dynamic>> vendors() =>
      _c(FirestoreCollections.vendors);
  CollectionReference<Map<String, dynamic>> stockReceipts() =>
      _c(FirestoreCollections.stockReceipts);
  CollectionReference<Map<String, dynamic>> membershipPayments() =>
      _c(FirestoreCollections.membershipPayments);
  CollectionReference<Map<String, dynamic>> transactions() =>
      _c(FirestoreCollections.transactions);
  CollectionReference<Map<String, dynamic>> pointAdjustments() =>
      _c(FirestoreCollections.pointAdjustments);
  CollectionReference<Map<String, dynamic>> leaderboardResets() =>
      _c(FirestoreCollections.leaderboardResets);

  CollectionReference<Map<String, dynamic>> permissionRoles() =>
      _c(FirestoreCollections.permissionRoles);

  CollectionReference<Map<String, dynamic>> publicFloor() =>
      _c(FirestoreCollections.publicFloor);

  CollectionReference<Map<String, dynamic>> publicMenuItems() =>
      _c(FirestoreCollections.publicMenuItems);

  CollectionReference<Map<String, dynamic>> floorBookingRequests() =>
      _c(FirestoreCollections.floorBookingRequests);

  CollectionReference<Map<String, dynamic>> publicBookingSlots() =>
      _c(FirestoreCollections.publicBookingSlots);

  CollectionReference<Map<String, dynamic>> guestCafeOrders() =>
      _c(FirestoreCollections.guestCafeOrders);

  CollectionReference<Map<String, dynamic>> notifications() =>
      _c(FirestoreCollections.notifications);

  CollectionReference<Map<String, dynamic>> expenses() =>
      _c(FirestoreCollections.expenses);
  CollectionReference<Map<String, dynamic>> reservations() =>
      _c(FirestoreCollections.reservations);

  CollectionReference<Map<String, dynamic>> feedback() =>
      _c(FirestoreCollections.feedback);
  CollectionReference<Map<String, dynamic>> promotions() =>
      _c(FirestoreCollections.promotions);

  CollectionReference<Map<String, dynamic>> invoices() =>
      _c(FirestoreCollections.invoices);
  CollectionReference<Map<String, dynamic>> auditLog() =>
      _c(FirestoreCollections.auditLog);

  CollectionReference<Map<String, dynamic>> messageTemplates() =>
      _c(FirestoreCollections.messageTemplates);

  CollectionReference<Map<String, dynamic>> receipts() =>
      _c(FirestoreCollections.receipts);
  CollectionReference<Map<String, dynamic>> shifts() =>
      _c(FirestoreCollections.shifts);

  CollectionReference<Map<String, dynamic>> preOrders() =>
      _c(FirestoreCollections.preOrders);
  CollectionReference<Map<String, dynamic>> tips() =>
      _c(FirestoreCollections.tips);
  CollectionReference<Map<String, dynamic>> orderModifications() =>
      _c(FirestoreCollections.orderModifications);
  CollectionReference<Map<String, dynamic>> splitBills() =>
      _c(FirestoreCollections.splitBills);
  CollectionReference<Map<String, dynamic>> customerPreferences() =>
      _c(FirestoreCollections.customerPreferences);
  CollectionReference<Map<String, dynamic>> referrals() =>
      _c(FirestoreCollections.referrals);
  CollectionReference<Map<String, dynamic>> waitlist() =>
      _c(FirestoreCollections.waitlist);
  CollectionReference<Map<String, dynamic>> customerSegments() =>
      _c(FirestoreCollections.customerSegments);
  CollectionReference<Map<String, dynamic>> campaigns() =>
      _c(FirestoreCollections.campaigns);

  CollectionReference<Map<String, dynamic>> creditTransactions(
    String customerId,
  ) => customers()
      .doc(customerId)
      .collection(FirestoreCollections.creditTransactions);

  CollectionReference<Map<String, dynamic>> commissions() =>
      _c(FirestoreCollections.commissions);
  CollectionReference<Map<String, dynamic>> trainingModules() =>
      _c(FirestoreCollections.trainingModules);
  CollectionReference<Map<String, dynamic>> leaveRequests() =>
      _c(FirestoreCollections.leaveRequests);
  CollectionReference<Map<String, dynamic>> staffGoals() =>
      _c(FirestoreCollections.staffGoals);
  CollectionReference<Map<String, dynamic>> staffDocuments() =>
      _c(FirestoreCollections.staffDocuments);
  CollectionReference<Map<String, dynamic>> cashRegister() =>
      _c(FirestoreCollections.cashRegister);
  CollectionReference<Map<String, dynamic>> pettyCash() =>
      _c(FirestoreCollections.pettyCash);
  CollectionReference<Map<String, dynamic>> budgets() =>
      _c(FirestoreCollections.budgets);
  CollectionReference<Map<String, dynamic>> vendorPayments() =>
      _c(FirestoreCollections.vendorPayments);

  CollectionReference<Map<String, dynamic>> giftCards() =>
      _c(FirestoreCollections.giftCards);
  CollectionReference<Map<String, dynamic>> marketingCampaigns() =>
      _c(FirestoreCollections.marketingCampaigns);
  CollectionReference<Map<String, dynamic>> marketingBudgets() =>
      _c(FirestoreCollections.marketingBudgets);
  CollectionReference<Map<String, dynamic>> staffChat() =>
      _c(FirestoreCollections.staffChat);
  CollectionReference<Map<String, dynamic>> autoReminders() =>
      _c(FirestoreCollections.autoReminders);
  CollectionReference<Map<String, dynamic>> communicationLog() =>
      _c(FirestoreCollections.communicationLog);
}
