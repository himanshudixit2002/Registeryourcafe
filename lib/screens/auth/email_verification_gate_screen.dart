import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/workspace_auth_action_settings.dart';
import '../../branding/app_assets.dart';
import '../../constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

/// Full-screen step after sign-in when the account email is not verified yet.
/// Workspace modules open only after [User.emailVerified] is true.
class EmailVerificationGateScreen extends ConsumerStatefulWidget {
  const EmailVerificationGateScreen({super.key});

  @override
  ConsumerState<EmailVerificationGateScreen> createState() =>
      _EmailVerificationGateScreenState();
}

class _EmailVerificationGateScreenState
    extends ConsumerState<EmailVerificationGateScreen> {
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

  Future<void> _reloadVerified(User user) async {
    setState(() => _busy = true);
    try {
      await user.reload();
      ref.invalidate(authStateChangesProvider);
      if (mounted &&
          FirebaseAuth.instance.currentUser?.emailVerified == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified. Loading workspace…')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateChangesProvider);
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Unable to verify your email',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'No email address is associated with this session. '
                  'Please sign out and sign in again.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(AppStrings.signOut),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (user.emailVerified) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Email verified!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading your workspace…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  ref.invalidate(authStateChangesProvider);
                },
                child: const Text('Tap here if nothing happens'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Verify your email'),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    await ref.read(authServiceProvider).signOut();
                  },
            child: const Text(AppStrings.signOut),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Image.asset(
                      AppAssets.appLogo,
                      height: 72,
                      cacheWidth: 144,
                      cacheHeight: 144,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Check your inbox',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a verification link to',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    email,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Open the link to verify, then tap the button below. '
                    '${AppStrings.authEmailSentHints}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: theme.colorScheme.tertiary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Check your spam or junk folder if you don\'t see it.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _reloadVerified(user),
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: const Text("I've verified — continue"),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.kBorderRadiusMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy || !_canResend ? null : () => _resend(user),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      _canResend ? 'Resend verification email' : 'Wait to resend',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
