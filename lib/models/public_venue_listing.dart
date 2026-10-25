import 'package:cloud_firestore/cloud_firestore.dart';

import 'venue_kind.dart';

class PublicVenueListing {
  final String companyId;
  final String displayName;
  final VenueKind venueKind;
  final String? tagline;
  final bool showOnDiscovery;
  final String? address;
  final String? phone;
  final String? hoursNote;
  final String? coverImageUrl;
  final DateTime? updatedAt;

  /// Optional city for guest search / filters (public-safe).
  final String? city;

  /// Optional neighborhood or area label.
  final String? area;

  /// Optional lowercase tags for discovery (e.g. cuisine, amenities).
  final List<String> discoveryTags;

  const PublicVenueListing({
    required this.companyId,
    required this.displayName,
    required this.venueKind,
    this.tagline,
    required this.showOnDiscovery,
    this.address,
    this.phone,
    this.hoursNote,
    this.coverImageUrl,
    this.updatedAt,
    this.city,
    this.area,
    this.discoveryTags = const [],
  });

  static List<String> _parseDiscoveryTags(Object? raw) {
    if (raw == null) return [];
    if (raw is! List) return [];
    final out = <String>[];
    for (final e in raw) {
      final s = e.toString().trim().toLowerCase();
      if (s.isNotEmpty) out.add(s);
    }
    return out;
  }

  factory PublicVenueListing.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PublicVenueListing(
      companyId: doc.id,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? data['displayName'] as String
          : doc.id,
      venueKind: VenueKind.parse(data['venueKind']),
      tagline: data['tagline'] as String?,
      showOnDiscovery: data['showOnDiscovery'] == true,
      address: data['address'] as String?,
      phone: data['phone'] as String?,
      hoursNote: data['hoursNote'] as String?,
      coverImageUrl: data['coverImageUrl'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      city: data['city'] as String?,
      area: data['area'] as String?,
      discoveryTags: _parseDiscoveryTags(data['discoveryTags']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final m = <String, dynamic>{
      'displayName': displayName,
      'venueKind': venueKind.storageName,
      'showOnDiscovery': showOnDiscovery,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (tagline != null && tagline!.trim().isNotEmpty) {
      m['tagline'] = tagline!.trim();
    } else {
      m['tagline'] = FieldValue.delete();
    }
    if (address != null && address!.trim().isNotEmpty) {
      m['address'] = address!.trim();
    } else {
      m['address'] = FieldValue.delete();
    }
    if (phone != null && phone!.trim().isNotEmpty) {
      m['phone'] = phone!.trim();
    } else {
      m['phone'] = FieldValue.delete();
    }
    if (hoursNote != null && hoursNote!.trim().isNotEmpty) {
      m['hoursNote'] = hoursNote!.trim();
    } else {
      m['hoursNote'] = FieldValue.delete();
    }
    if (coverImageUrl != null && coverImageUrl!.trim().isNotEmpty) {
      m['coverImageUrl'] = coverImageUrl!.trim();
    } else {
      m['coverImageUrl'] = FieldValue.delete();
    }
    if (city != null && city!.trim().isNotEmpty) {
      m['city'] = city!.trim();
    } else {
      m['city'] = FieldValue.delete();
    }
    if (area != null && area!.trim().isNotEmpty) {
      m['area'] = area!.trim();
    } else {
      m['area'] = FieldValue.delete();
    }
    if (discoveryTags.isNotEmpty) {
      m['discoveryTags'] = discoveryTags;
    } else {
      m['discoveryTags'] = FieldValue.delete();
    }
    return m;
  }
}
