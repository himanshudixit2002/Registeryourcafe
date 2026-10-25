import 'package:cloud_firestore/cloud_firestore.dart';

import 'venue_kind.dart';

class Company {
  final String id;
  final String name;
  final String ownerUid;
  final DateTime createdAt;
  final VenueKind venueKind;
  final String? description;
  final String? address;
  final String? phone;
  final String? logoUrl;
  final Map<String, String> operatingHours;
  final Map<String, String> socialLinks;

  Company({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.createdAt,
    this.venueKind = VenueKind.gamingCafe,
    this.description,
    this.address,
    this.phone,
    this.logoUrl,
    this.operatingHours = const {},
    this.socialLinks = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'venueKind': venueKind.storageName,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (operatingHours.isNotEmpty) 'operatingHours': operatingHours,
      if (socialLinks.isNotEmpty) 'socialLinks': socialLinks,
    };
  }

  factory Company.fromFirestore(Map<String, dynamic> data, String docId) {
    return Company(
      id: docId,
      name: data['name'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      venueKind: VenueKind.parse(data['venueKind']),
      description: data['description'] as String?,
      address: data['address'] as String?,
      phone: data['phone'] as String?,
      logoUrl: data['logoUrl'] as String?,
      operatingHours: data['operatingHours'] is Map
          ? (data['operatingHours'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      socialLinks: data['socialLinks'] is Map
          ? (data['socialLinks'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }
}
