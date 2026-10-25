import 'company_module_visibility.dart';
import 'venue_kind.dart';
import '../utils/firestore_utils.dart';

/// Tenant-level settings parsed from `companies/{companyId}`.
class CompanyProfile {
  const CompanyProfile({
    required this.venueKind,
    required this.modules,
    this.ownerUid,
    this.name,
    this.description,
    this.address,
    this.phone,
    this.logoUrl,
    this.operatingHours = const {},
    this.socialLinks = const {},
  });

  final VenueKind venueKind;
  final CompanyModuleVisibility modules;

  /// Registered owner Firebase Auth uid (`companies/{id}.ownerUid`).
  final String? ownerUid;
  final String? name;
  final String? description;
  final String? address;
  final String? phone;
  final String? logoUrl;
  final Map<String, String> operatingHours;
  final Map<String, String> socialLinks;

  static CompanyProfile fallback() => CompanyProfile(
    venueKind: VenueKind.gamingCafe,
    modules: CompanyModuleVisibility.defaults,
  );

  static CompanyProfile fromFirestoreData(Map<String, dynamic>? data) {
    if (data == null) return fallback();
    return CompanyProfile(
      venueKind: VenueKind.parse(data['venueKind']),
      modules: CompanyModuleVisibility.fromFirestoreData(data),
      ownerUid: parseFirestoreStringOrNull(data['ownerUid']),
      name: data['name'] as String?,
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
