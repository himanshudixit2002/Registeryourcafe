import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseException;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/register_ops_firebase.dart';
import '../firebase_options.dart';
import '../services/recent_customers_service.dart';
import '../utils/app_logger.dart';

bool _firestoreConfigured = false;
bool _staleCacheCleared = false;

/// Disable offline persistence so every read goes to the server.
/// Purge any stale IndexedDB / SQLite cache from earlier sessions that had
/// persistence enabled -- prevents ghost docs and permission-denied loops.
Future<void> _configureFirestoreOnlineOnly() async {
  if (!_staleCacheCleared) {
    _staleCacheCleared = true;
    try {
      await FirebaseFirestore.instance.clearPersistence();
      AppLogger.info('Cleared stale Firestore persistence cache', tag: 'FirebaseInit');
    } catch (e) {
      // clearPersistence throws if any listeners are active (hot restart);
      // safe to ignore -- the cache will be stale but reads still go to server
      // once persistence is disabled below.
      AppLogger.debug('clearPersistence skipped: $e', tag: 'FirebaseInit');
    }
  }

  if (_firestoreConfigured) return;
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    _firestoreConfigured = true;
    AppLogger.info('Firestore: online-only mode (persistence disabled)', tag: 'FirebaseInit');
  } catch (e, st) {
    // Web hot-restart / second open from email links can hit "settings can no
    // longer be changed"; don't fail the whole bootstrap.
    AppLogger.warning('Firestore settings skipped: $e', tag: 'FirebaseInit');
    if (kDebugMode) {
      AppLogger.debug('$st', tag: 'FirebaseInit');
    }
    _firestoreConfigured = true;
  }
}

bool _hasFirebaseAppNamed(String name) {
  for (final app in Firebase.apps) {
    if (app.name == name) return true;
  }
  return false;
}

final firebaseInitProvider = FutureProvider<void>((ref) async {
  // [FutureProvider] may re-run when invalidated (e.g. user taps Try again).
  // Calling initializeApp again throws [duplicate-app] and was shown as
  // a misleading "Connection error" after sign-in / profile retries.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  await _configureFirestoreOnlineOnly();
  // Crashlytics is not supported on web; accessing the instance asserts there.
  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  }
  if (!_hasFirebaseAppNamed(kRegisterOpsFirebaseAppName)) {
    try {
      await Firebase.initializeApp(
        name: kRegisterOpsFirebaseAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }
  }
  try {
    await RecentCustomersService.init();
  } catch (e, st) {
    AppLogger.warning(
      'RecentCustomersService.init failed; continuing: $e',
      tag: 'FirebaseInit',
    );
    if (kDebugMode) {
      AppLogger.debug('$st', tag: 'FirebaseInit');
    }
  }
});
