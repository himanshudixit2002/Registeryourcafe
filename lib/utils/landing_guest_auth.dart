import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Auth for landing-only flows (e.g. public floor booking requests).
///
/// Requires **Anonymous** sign-in enabled in the Firebase console.
Future<User> ensureLandingGuestUser() async {
  final auth = FirebaseAuth.instance;
  final cur = auth.currentUser;
  if (cur != null) return cur;
  final cred = await auth.signInAnonymously();
  return cred.user!;
}
