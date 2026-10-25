import 'package:cloud_firestore/cloud_firestore.dart';

class VenueReview {
  final String id;
  final String companyId;
  final String reviewerUid;
  final String reviewerName;
  final String? reviewerPhotoUrl;
  final int rating;
  final int? foodRating;
  final int? ambianceRating;
  final int? serviceRating;
  final int? valueRating;
  final String comment;
  final List<String> photoUrls;
  final String? ownerResponse;
  final int helpfulCount;
  final bool isVerified;
  final DateTime createdAt;

  const VenueReview({
    required this.id,
    required this.companyId,
    required this.reviewerUid,
    required this.reviewerName,
    this.reviewerPhotoUrl,
    required this.rating,
    this.foodRating,
    this.ambianceRating,
    this.serviceRating,
    this.valueRating,
    required this.comment,
    this.photoUrls = const [],
    this.ownerResponse,
    this.helpfulCount = 0,
    this.isVerified = false,
    required this.createdAt,
  });

  factory VenueReview.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return VenueReview(
      id: doc.id,
      companyId: d['companyId'] as String? ?? '',
      reviewerUid: d['reviewerUid'] as String? ?? '',
      reviewerName: d['reviewerName'] as String? ?? 'Guest',
      reviewerPhotoUrl: d['reviewerPhotoUrl'] as String?,
      rating: (d['rating'] as num?)?.toInt() ?? 0,
      foodRating: (d['foodRating'] as num?)?.toInt(),
      ambianceRating: (d['ambianceRating'] as num?)?.toInt(),
      serviceRating: (d['serviceRating'] as num?)?.toInt(),
      valueRating: (d['valueRating'] as num?)?.toInt(),
      comment: d['comment'] as String? ?? '',
      photoUrls: (d['photoUrls'] as List?)?.whereType<String>().toList() ?? [],
      ownerResponse: d['ownerResponse'] as String?,
      helpfulCount: (d['helpfulCount'] as num?)?.toInt() ?? 0,
      isVerified: d['isVerified'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'companyId': companyId,
    'reviewerUid': reviewerUid,
    'reviewerName': reviewerName,
    if (reviewerPhotoUrl != null) 'reviewerPhotoUrl': reviewerPhotoUrl,
    'rating': rating,
    if (foodRating != null) 'foodRating': foodRating,
    if (ambianceRating != null) 'ambianceRating': ambianceRating,
    if (serviceRating != null) 'serviceRating': serviceRating,
    if (valueRating != null) 'valueRating': valueRating,
    'comment': comment,
    'photoUrls': photoUrls,
    if (ownerResponse != null) 'ownerResponse': ownerResponse,
    'helpfulCount': helpfulCount,
    'isVerified': isVerified,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
