import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/app_logger.dart';

class GoogleAuthResult {
  final UserCredential credential;
  final bool isNewUser;

  const GoogleAuthResult({required this.credential, required this.isNewUser});
}

class GoogleAuthService {
  final FirebaseAuth _auth;

  GoogleAuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  Future<GoogleAuthResult?> signInWithGoogle() async {
    if (kIsWeb) {
      return _signInWithGoogleWeb();
    }
    return _signInWithGoogleMobile();
  }

  Future<GoogleAuthResult?> _signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');
    final userCredential = await _auth.signInWithPopup(provider);
    final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;
    return GoogleAuthResult(credential: userCredential, isNewUser: isNew);
  }

  Future<GoogleAuthResult?> _signInWithGoogleMobile() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final oauthCredential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);
    final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;
    return GoogleAuthResult(credential: userCredential, isNewUser: isNew);
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (e) {
      AppLogger.debug('GoogleSignIn.signOut: $e', tag: 'GoogleAuth');
    }
  }
}
