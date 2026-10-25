import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Client-side guard for actions that should wait until the primary account
/// email is verified (Firebase Auth `emailVerified`).
///
/// **Full-screen gate:** `EmailVerificationGateScreen` blocks the workspace
/// until verification when [mustCompleteEmailVerification] is true.
///
/// **Gated surfaces (keep in sync when adding new flows):**
/// - [CreateStaffScreen]: creating staff sign-in accounts
/// - [PublicDiscoverySettingsScreen]: enabling public discovery, saving or
///   refreshing a live listing, uploading cover while listed
/// - [PublicMenuEditorScreen]: add, edit, delete, or image upload for public menu
///
/// This guard blocks the actions above with an in-context message. The main
/// shell may still show [EmailVerificationBanner] for edge cases.
abstract final class EmailVerificationGuard {
  /// True when the signed-in user has an email address that is not verified
  /// yet (password or social account with a pending verification).
  static bool mustCompleteEmailVerification(User? user) {
    if (user == null) return false;
    if (user.emailVerified) return false;
    final e = user.email;
    if (e == null || e.isEmpty) return false;
    return true;
  }

  static bool isPrimaryEmailVerified() {
    final u = FirebaseAuth.instance.currentUser;
    return u?.emailVerified ?? false;
  }

  /// Returns `true` if the signed-in user may proceed; otherwise shows a snackbar.
  static bool requireVerifiedForSensitiveAction(BuildContext context) {
    if (isPrimaryEmailVerified()) return true;
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Verify your email first. Check your inbox for the link, or use '
          'Resend from the banner.',
        ),
      ),
    );
    return false;
  }
}
