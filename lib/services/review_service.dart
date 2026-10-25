import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/venue_review.dart';

class ReviewService {
  final FirebaseFirestore _db;
  ReviewService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reviews(String companyId) =>
      _db.collection('companies').doc(companyId).collection('reviews');

  Future<void> submitReview(VenueReview review) async =>
      await _reviews(review.companyId).add(review.toFirestore());

  Stream<List<VenueReview>> watchReviews(String companyId,
          {int limit = 50}) =>
      _reviews(companyId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(VenueReview.fromFirestore).toList());

  Future<void> markHelpful(String companyId, String reviewId) async =>
      await _reviews(companyId)
          .doc(reviewId)
          .update({'helpfulCount': FieldValue.increment(1)});

  Future<void> respondToReview(
          String companyId, String reviewId, String response) async =>
      await _reviews(companyId)
          .doc(reviewId)
          .update({'ownerResponse': response});

  Future<Map<String, dynamic>> getReviewStats(String companyId) async {
    final snap = await _reviews(companyId).get();
    if (snap.docs.isEmpty) {
      return {'avg': 0.0, 'count': 0, 'distribution': <int, int>{}};
    }
    final reviews = snap.docs.map(VenueReview.fromFirestore).toList();
    final avg = reviews.fold(0, (s, r) => s + r.rating) / reviews.length;
    final dist = <int, int>{};
    for (final r in reviews) {
      dist[r.rating] = (dist[r.rating] ?? 0) + 1;
    }
    return {'avg': avg, 'count': reviews.length, 'distribution': dist};
  }
}
