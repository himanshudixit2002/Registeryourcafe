import 'package:cloud_firestore/cloud_firestore.dart';

class GuestProfile {
  final String uid;
  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final List<String> favoriteVenues;
  final List<String> recentlyViewed;
  final Map<String, dynamic> preferences;
  final int loyaltyPoints;
  final String loyaltyTier;
  final String? referralCode;
  final DateTime createdAt;

  const GuestProfile({
    required this.uid,
    this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.favoriteVenues = const [],
    this.recentlyViewed = const [],
    this.preferences = const {},
    this.loyaltyPoints = 0,
    this.loyaltyTier = 'bronze',
    this.referralCode,
    required this.createdAt,
  });

  factory GuestProfile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GuestProfile(
      uid: doc.id,
      name: d['name'] as String?,
      email: d['email'] as String?,
      phone: d['phone'] as String?,
      photoUrl: d['photoUrl'] as String?,
      favoriteVenues: (d['favoriteVenues'] as List?)?.whereType<String>().toList() ?? [],
      recentlyViewed: (d['recentlyViewed'] as List?)?.whereType<String>().toList() ?? [],
      preferences: d['preferences'] as Map<String, dynamic>? ?? {},
      loyaltyPoints: (d['loyaltyPoints'] as num?)?.toInt() ?? 0,
      loyaltyTier: d['loyaltyTier'] as String? ?? 'bronze',
      referralCode: d['referralCode'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    if (name != null) 'name': name,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'favoriteVenues': favoriteVenues,
    'recentlyViewed': recentlyViewed,
    'preferences': preferences,
    'loyaltyPoints': loyaltyPoints,
    'loyaltyTier': loyaltyTier,
    if (referralCode != null) 'referralCode': referralCode,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
