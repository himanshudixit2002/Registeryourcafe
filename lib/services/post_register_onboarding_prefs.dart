import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/firestore_collections.dart';
import '../utils/app_logger.dart';

/// Quick-start sheet per company: device-local cache plus optional Firestore
/// flag so dismissal survives reinstall / other devices (same owner account).
abstract final class PostRegisterOnboardingPrefs {
  static const String _firestoreField = 'postRegisterOnboardingDismissed';

  static String _key(String companyId) =>
      'post_register_quick_start_v1_${companyId.trim()}';

  static Future<bool> isDismissed(String companyId) async {
    if (companyId.isEmpty) return true;
    final p = await SharedPreferences.getInstance();
    final local = p.getBool(_key(companyId)) ?? false;
    if (local) return true;

    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.companies)
          .doc(companyId)
          .get();
      final remote = snap.data()?[_firestoreField] == true;
      if (remote) {
        await p.setBool(_key(companyId), true);
        return true;
      }
    } catch (e, st) {
      AppLogger.logNonFatalProviderSideEffect(
        'post-register onboarding remote dismiss check',
        e,
        st,
        tag: 'PostRegisterOnboardingPrefs',
      );
    }
    return false;
  }

  static Future<void> markDismissed(String companyId) async {
    if (companyId.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key(companyId), true);

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.companies)
          .doc(companyId)
          .set(
            {
              _firestoreField: true,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    } catch (e, st) {
      AppLogger.logNonFatalProviderSideEffect(
        'post-register onboarding Firestore dismiss',
        e,
        st,
        tag: 'PostRegisterOnboardingPrefs',
      );
    }
  }
}
