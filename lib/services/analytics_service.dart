import 'package:firebase_analytics/firebase_analytics.dart';

/// Firebase Analytics helpers (no-op safe: SDK handles disabled collection).
///
/// In the [Firebase console](https://console.firebase.google.com/), ensure
/// Google Analytics is linked and data collection is on for each Android, iOS,
/// and web app. Custom user property `venue_kind` appears after events begin
/// flowing (allow processing delay).
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Fires after a successful self-serve company registration.
  static Future<void> logWorkspaceSignUp({
    required String venueKindStorage,
  }) {
    return _analytics.logEvent(
      name: 'workspace_sign_up',
      parameters: {'venue_kind': venueKindStorage},
    );
  }

  /// Sets Analytics user properties for the signed-in workspace session.
  /// Safe to call repeatedly when [venueKindStorage] changes.
  static Future<void> setWorkspaceUserProperties({
    required String venueKindStorage,
  }) async {
    await _analytics.setUserProperty(
      name: 'venue_kind',
      value: venueKindStorage,
    );
  }
}
