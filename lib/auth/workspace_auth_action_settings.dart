import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../firebase_options.dart';

/// Where Firebase Auth redirects after the user completes the action in email
/// (verify / password reset). Must be listed under Authentication → Settings →
/// **Authorized domains**.
///
/// Email **content** (HTML, subject, sender name) is edited in Firebase Console →
/// Authentication → Templates. See [docs/firebase_auth_email_templates.md].
///
/// On **web**, use the current page origin so the link returns to the same
/// deployment (localhost, custom domain, or `*.web.app`). A fixed
/// `firebaseapp.com` URL breaks flows where the app is not hosted there.
/// On **iOS/Android**, fall back to the project default hosting domain.
String workspaceAuthEmailContinueUrl() {
  if (kIsWeb) {
    final u = Uri.base;
    if (u.host.isEmpty) {
      final host = DefaultFirebaseOptions.web.authDomain;
      return 'https://$host/';
    }
    final port =
        u.hasPort && u.port != 80 && u.port != 443 ? ':${u.port}' : '';
    return '${u.scheme}://${u.host}$port/';
  }
  final host = DefaultFirebaseOptions.web.authDomain;
  return 'https://$host/';
}

ActionCodeSettings workspaceAuthActionCodeSettings() {
  return ActionCodeSettings(
    url: workspaceAuthEmailContinueUrl(),
    handleCodeInApp: false,
  );
}
