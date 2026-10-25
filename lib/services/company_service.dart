import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/company_module_visibility.dart';
import '../models/venue_kind.dart';

class CompanyService {
  final TenantRef _tenant;

  CompanyService(this._tenant);

  Future<void> updateProfile({
    String? name,
    String? description,
    String? address,
    String? phone,
    Map<String, String>? operatingHours,
    Map<String, String>? socialLinks,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (address != null) updates['address'] = address;
    if (phone != null) updates['phone'] = phone;
    if (operatingHours != null) updates['operatingHours'] = operatingHours;
    if (socialLinks != null) updates['socialLinks'] = socialLinks;
    await _tenant.companyDoc().set(updates, SetOptions(merge: true));
  }

  Future<void> updateLogoUrl(String logoUrl) async {
    await _tenant.companyDoc().set({
      'logoUrl': logoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> changeVenueKind(
    VenueKind newKind, {
    bool reapplyModulePreset = false,
  }) async {
    final updates = <String, dynamic>{
      'venueKind': newKind.storageName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (reapplyModulePreset) {
      final preset = CompanyModuleVisibility.presetFor(newKind);
      updates['moduleVisibility'] = preset.toFirestoreMap();
    }
    await _tenant.companyDoc().set(updates, SetOptions(merge: true));
  }
}
