import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/vendor.dart';
import '../utils/app_logger.dart';
import '../utils/business_validators.dart';

class VendorService {
  VendorService._();

  static Stream<List<Vendor>> watchVendors(
    TenantRef tenant, {
    bool activeOnly = false,
  }) {
    final Query<Map<String, dynamic>> q = tenant.vendors().orderBy('name');
    return q.snapshots().map((snap) {
      var list = snap.docs.map(Vendor.fromFirestore).toList();
      if (activeOnly) {
        list = list.where((v) => v.isActive).toList();
      }
      return list;
    });
  }

  static Future<Vendor?> getById(TenantRef tenant, String id) async {
    if (id.isEmpty) return null;
    final doc = await tenant.vendors().doc(id).get();
    if (!doc.exists) return null;
    return Vendor.fromFirestore(doc);
  }

  static Future<String> createVendor(
    TenantRef tenant, {
    required String name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    BusinessValidators.validateNotEmpty(name, 'Vendor name');
    final doc = tenant.vendors().doc();
    try {
      await doc.set({
        'name': name.trim(),
        'phone': phone?.trim(),
        'email': email?.trim(),
        'notes': notes?.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      AppLogger.error(
        'createVendor failed name=$name',
        tag: 'Vendor',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    AppLogger.success('Vendor created id=${doc.id}', tag: 'Vendor');
    return doc.id;
  }

  static Future<void> updateVendor(
    TenantRef tenant, {
    required String id,
    required String name,
    String? phone,
    String? email,
    String? notes,
    bool? isActive,
  }) async {
    BusinessValidators.validateIdExists(id, 'Vendor');
    BusinessValidators.validateNotEmpty(name, 'Vendor name');
    try {
      await tenant.vendors().doc(id).update({
        'name': name.trim(),
        'phone': phone?.trim(),
        'email': email?.trim(),
        'notes': notes?.trim(),
        'isActive': ?isActive,
      });
    } catch (e, st) {
      AppLogger.error(
        'updateVendor failed id=$id',
        tag: 'Vendor',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    AppLogger.success('Vendor updated id=$id', tag: 'Vendor');
  }
}
