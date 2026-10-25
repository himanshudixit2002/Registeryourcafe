import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_collections.dart';
import '../utils/app_logger.dart';

class SuperAdminService {
  final FirebaseFirestore _db;

  SuperAdminService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAllCompanies() {
    return _db
        .collection(FirestoreCollections.companies)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs)
        .handleError((Object e, StackTrace st) {
          AppLogger.error('watchAllCompanies failed', tag: 'SuperAdmin', error: e, stackTrace: st);
          return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAllUsers() {
    return _db
        .collection(FirestoreCollections.users)
        .snapshots()
        .map((s) => s.docs)
        .handleError((Object e, StackTrace st) {
          AppLogger.error('watchAllUsers failed', tag: 'SuperAdmin', error: e, stackTrace: st);
          return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
  }

  Future<int> getCompanyCount() async {
    final snap = await _db.collection(FirestoreCollections.companies).count().get();
    return snap.count ?? 0;
  }

  Future<int> getUserCount() async {
    final snap = await _db.collection(FirestoreCollections.users).count().get();
    return snap.count ?? 0;
  }

  Future<void> updateCompanyField(String companyId, Map<String, dynamic> data) async {
    await _db.collection(FirestoreCollections.companies).doc(companyId).update(data);
  }

  Future<void> updateUserField(String uid, Map<String, dynamic> data) async {
    await _db.collection(FirestoreCollections.users).doc(uid).update(data);
  }

  Future<void> suspendCompany(String companyId) async {
    await _db.collection(FirestoreCollections.companies).doc(companyId).update({
      'suspended': true,
      'suspendedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reactivateCompany(String companyId) async {
    await _db.collection(FirestoreCollections.companies).doc(companyId).update({
      'suspended': false,
      'suspendedAt': FieldValue.delete(),
    });
  }

  Future<void> suspendUser(String uid) async {
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'suspended': true,
    });
  }

  Future<void> reactivateUser(String uid) async {
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'suspended': false,
    });
  }

  Future<void> deleteCompany(String companyId) async {
    await _db.collection(FirestoreCollections.companies).doc(companyId).update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> getPlatformStats() async {
    final companies = await getCompanyCount();
    final users = await getUserCount();
    return {
      'totalCompanies': companies,
      'totalUsers': users,
    };
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchSupportTickets() {
    return _db
        .collectionGroup('supportTickets')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs)
        .handleError((Object e, StackTrace st) {
          AppLogger.error('watchSupportTickets failed', tag: 'SuperAdmin', error: e, stackTrace: st);
          return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
  }

  Future<void> updateFeatureFlag(String companyId, String featureId, bool enabled) async {
    await _db.collection(FirestoreCollections.companies).doc(companyId).set({
      'featureFlags': {featureId: enabled},
    }, SetOptions(merge: true));
  }

  Future<void> setGlobalFeatureFlag(String featureId, bool enabled) async {
    await _db.collection('platformConfig').doc('featureFlags').set({
      featureId: enabled,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getGlobalFeatureFlags() async {
    final doc = await _db.collection('platformConfig').doc('featureFlags').get();
    return doc.data() ?? {};
  }

  Future<void> savePlatformSettings(Map<String, dynamic> settings) async {
    await _db.collection('platformConfig').doc('settings').set(
      settings,
      SetOptions(merge: true),
    );
  }

  Future<Map<String, dynamic>> getPlatformSettings() async {
    final doc = await _db.collection('platformConfig').doc('settings').get();
    return doc.data() ?? {};
  }

  Future<void> createAnnouncement({
    required String title,
    required String body,
  }) async {
    await _db.collection('platformConfig').doc('data').collection('announcements').add({
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });
  }

  Future<void> logSuperAdminAction({
    required String action,
    required String actorEmail,
    String? details,
    String? entityType,
    String? entityId,
  }) async {
    await _db.collection('platformConfig').doc('data').collection('auditLog').add({
      'action': action,
      'actorEmail': actorEmail,
      'details': details,
      'entityType': entityType,
      'entityId': entityId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAllReviews() {
    return _db
        .collectionGroup('reviews')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs)
        .handleError((Object e, StackTrace st) {
          AppLogger.error('watchAllReviews failed', tag: 'SuperAdmin', error: e, stackTrace: st);
          return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAllGuestProfiles() {
    return _db
        .collection('guestProfiles')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs)
        .handleError((Object e, StackTrace st) {
          AppLogger.error('watchAllGuestProfiles failed', tag: 'SuperAdmin', error: e, stackTrace: st);
          return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAllGuestOrders() {
    return _db
        .collectionGroup('guest_cafe_orders')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs)
        .handleError((Object e, StackTrace st) {
          AppLogger.error('watchAllGuestOrders failed', tag: 'SuperAdmin', error: e, stackTrace: st);
          return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAllBookingRequests() {
    return _db
        .collectionGroup('floor_booking_requests')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs)
        .handleError((Object e, StackTrace st) {
          AppLogger.error('watchAllBookingRequests failed', tag: 'SuperAdmin', error: e, stackTrace: st);
          return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
  }

  Future<void> moderateReview(String companyId, String reviewId, String action) async {
    final ref = _db.collection('companies').doc(companyId).collection('reviews').doc(reviewId);
    if (action == 'delete') {
      await ref.delete();
    } else if (action == 'flag') {
      await ref.update({'flagged': true, 'flaggedAt': FieldValue.serverTimestamp()});
    }
  }

  Future<void> manageGuestAccount(String uid, String action) async {
    if (action == 'suspend') {
      await _db.collection('guestProfiles').doc(uid).update({'suspended': true});
    } else if (action == 'delete') {
      await _db.collection('guestProfiles').doc(uid).delete();
    } else if (action == 'reactivate') {
      await _db.collection('guestProfiles').doc(uid).update({'suspended': false});
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAuditLog() {
    return _db
        .collection('platformConfig')
        .doc('data')
        .collection('auditLog')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs)
        .handleError((Object e, StackTrace st) {
          AppLogger.error('watchAuditLog failed', tag: 'SuperAdmin', error: e, stackTrace: st);
          return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchAnnouncements() {
    return _db
        .collection('platformConfig')
        .doc('data')
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs)
        .handleError((Object e, StackTrace st) {
          AppLogger.error('watchAnnouncements failed', tag: 'SuperAdmin', error: e, stackTrace: st);
          return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await _db
        .collection('platformConfig')
        .doc('data')
        .collection('announcements')
        .doc(announcementId)
        .delete();
  }

  Future<void> updateBookingRequest(
    String companyId,
    String requestId,
    String status, {
    String? note,
  }) async {
    final ref = _db
        .collection('companies')
        .doc(companyId)
        .collection('floor_booking_requests')
        .doc(requestId);
    final data = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (note != null && note.isNotEmpty) {
      data['decisionNote'] = note;
    }
    await ref.update(data);
  }

  Future<void> cancelGuestOrder(String companyId, String orderId) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('guest_cafe_orders')
        .doc(orderId)
        .update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCompanyLoyaltySettings(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('loyalty_settings')
        .doc('default')
        .snapshots();
  }

  Future<void> updateCompanyLoyaltySettings(
    String companyId,
    Map<String, dynamic> settings,
  ) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('loyalty_settings')
        .doc('default')
        .set({...settings, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchCompanyLoyaltyConversions(
    String companyId, {
    int limit = 50,
  }) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('loyalty_conversions')
        .orderBy('convertedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCompanyDoc(String companyId) {
    return _db.collection(FirestoreCollections.companies).doc(companyId).snapshots();
  }

  Future<Map<String, int>> getCompanySubcollectionCounts(String companyId) async {
    final companyRef = _db.collection(FirestoreCollections.companies).doc(companyId);
    final results = await Future.wait([
      companyRef.collection(FirestoreCollections.tables).count().get(),
      companyRef.collection(FirestoreCollections.customers).count().get(),
      companyRef.collection(FirestoreCollections.cafeOrders).count().get(),
      companyRef.collection(FirestoreCollections.sessions).count().get(),
      companyRef.collection(FirestoreCollections.tournaments).count().get(),
    ]);
    return {
      'tables': results[0].count ?? 0,
      'customers': results[1].count ?? 0,
      'orders': results[2].count ?? 0,
      'sessions': results[3].count ?? 0,
      'tournaments': results[4].count ?? 0,
    };
  }

  Future<void> updateCompanyVenueKind(String companyId, String venueKind) async {
    await _db.collection(FirestoreCollections.companies).doc(companyId).update({
      'venueKind': venueKind,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection(FirestoreCollections.publicVenues).doc(companyId).update({
      'venueKind': venueKind,
      'updatedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  Future<void> updateCompanyModuleVisibility(
    String companyId,
    Map<String, dynamic> modules,
  ) async {
    await _db.collection(FirestoreCollections.companies).doc(companyId).update({
      'moduleVisibility': modules,
    });
  }

  Future<void> addTicketReply(
    String companyId,
    String ticketId, {
    required String message,
    required String authorEmail,
  }) async {
    final ref = _db
        .collection('companies')
        .doc(companyId)
        .collection('supportTickets')
        .doc(ticketId);
    await ref.update({
      'replies': FieldValue.arrayUnion([
        {
          'message': message,
          'authorEmail': authorEmail,
          'createdAt': Timestamp.now(),
        }
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
