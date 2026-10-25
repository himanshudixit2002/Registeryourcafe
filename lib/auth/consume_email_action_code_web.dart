import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';

/// If the app is opened with Firebase email-action query params (e.g. custom
/// continue URL that forwards `oobCode`), apply the code and strip params from
/// the address bar.
Future<bool> consumeEmailActionCodeFromBrowserUrl() async {
  final href = html.window.location.href;
  final uri = Uri.parse(href);
  var oobCode = uri.queryParameters['oobCode'];
  var mode = uri.queryParameters['mode'];
  if (oobCode == null || oobCode.isEmpty) {
    final frag = uri.fragment;
    if (frag.isNotEmpty) {
      final q = Uri.splitQueryString(frag);
      oobCode = q['oobCode'];
      mode = q['mode'];
    }
  }
  if (oobCode == null || oobCode.isEmpty) return false;
  if (mode != 'verifyEmail' && mode != 'recoverEmail') return false;

  try {
    await FirebaseAuth.instance.applyActionCode(oobCode);
    final newParams = Map<String, String>.from(uri.queryParameters);
    for (final k in [
      'oobCode',
      'mode',
      'apiKey',
      'continueUrl',
      'lang',
      'tenantId',
    ]) {
      newParams.remove(k);
    }
    final clean = uri.replace(
      queryParameters: newParams.isEmpty ? null : newParams,
    );
    html.window.history.replaceState(null, '', clean.toString());
    return true;
  } catch (_) {
    return false;
  }
}
