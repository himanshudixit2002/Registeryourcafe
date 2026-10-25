import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/guest_profile.dart';

class GuestProfileService {
  final FirebaseFirestore _db;
  GuestProfileService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('guestProfiles').doc(uid);

  Future<GuestProfile?> getProfile(String uid) async {
    final doc = await _doc(uid).get();
    return doc.exists ? GuestProfile.fromFirestore(doc) : null;
  }

  Stream<GuestProfile?> watchProfile(String uid) => _doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? GuestProfile.fromFirestore(doc) : null);

  Future<void> createOrUpdate(String uid, Map<String, dynamic> data) async =>
      await _doc(uid).set(
        {...data, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  Future<void> toggleFavoriteVenue(String uid, String companyId) async {
    final doc = await _doc(uid).get();
    final favs =
        (doc.data()?['favoriteVenues'] as List?)?.cast<String>() ?? [];
    if (favs.contains(companyId)) {
      await _doc(uid)
          .update({'favoriteVenues': FieldValue.arrayRemove([companyId])});
    } else {
      await _doc(uid)
          .update({'favoriteVenues': FieldValue.arrayUnion([companyId])});
    }
  }

  Future<void> addRecentlyViewed(String uid, String companyId) async {
    await _doc(uid).set({
      'recentlyViewed': FieldValue.arrayUnion([companyId]),
    }, SetOptions(merge: true));
  }

  Future<void> addLoyaltyPoints(String uid, int points) async {
    await _doc(uid).update({'loyaltyPoints': FieldValue.increment(points)});
  }

  Future<void> updateWalletBalance(String uid, double amount) async {
    await _db.collection('guestWallets').doc(uid).set({
      'balance': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<double> watchWalletBalance(String uid) =>
      _db.collection('guestWallets').doc(uid).snapshots().map(
            (doc) => (doc.data()?['balance'] as num?)?.toDouble() ?? 0,
          );
}
