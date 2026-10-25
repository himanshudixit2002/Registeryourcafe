import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/workspace_auth_action_settings.dart';
import '../constants/app_strings.dart';
import '../providers/auth_provider.dart';

/// Prompts password sign-ups to verify email; hides when verified or non-password user.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  DateTime? _lastResend;
  bool _busy = false;

  bool get _canResend {
    if (_lastResend == null) return true;
    return DateTime.now().difference(_lastResend!) >
        const Duration(seconds: 45);
  }

  Future<void> _resend(User user) async {
    setState(() => _busy = true);
    try {
      await user.sendEmailVerification(workspaceAuthActionCodeSettings());
      if (mounted) {
        setState(() => _lastResend = DateTime.now());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification email sent. ${AppStrings.authEmailSentHints}',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send email: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload(User user) async {
    setState(() => _busy = true);
    try {
      await user.reload();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateChangesProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.emailVerified) {
      return const SizedBox.shrink();
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.secondaryContainer.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.mark_email_unread_outlined, color: cs.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verify your email',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'We sent a link to $email. Verify to secure your account '
                    'and recover access if you forget your password. '
                    '${AppStrings.authEmailSentHints}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSecondaryContainer,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy || !_canResend
                            ? null
                            : () => _resend(user),
                        child: Text(_canResend ? 'Resend email' : 'Wait to resend'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _reload(user),
                        child: const Text("I've verified"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
