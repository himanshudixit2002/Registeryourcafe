import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// User-facing title + message for a thrown [error] (technical detail stays in UI).
class BootstrapFailureCopy {
  const BootstrapFailureCopy({required this.title, required this.userMessage});

  final String title;
  final String userMessage;

  static BootstrapFailureCopy forError(Object error) {
    final d = error.toString();
    if (d.contains('duplicate-app')) {
      return const BootstrapFailureCopy(
        title: 'Reconnect issue',
        userMessage:
            'The app tried to start Firebase twice. Tap Try again, or refresh '
            'the page (web) and sign in again.',
      );
    }
    if (d.contains('isCrashlyticsCollectionEnabled') ||
        d.contains('Assertion failed')) {
      return const BootstrapFailureCopy(
        title: 'Startup error',
        userMessage:
            'A component failed during startup. On web, use an updated build; '
            'on mobile, reinstall or update the app if this persists.',
      );
    }
    if (d.contains('permission-denied') ||
        d.contains('PERMISSION_DENIED') ||
        d.contains('Missing or insufficient permissions')) {
      return const BootstrapFailureCopy(
        title: 'Access denied',
        userMessage:
            'The server refused this request. Check your account role, company '
            'assignment, or Firestore rules.',
      );
    }
    if (d.contains('unavailable') ||
        d.contains('UNAVAILABLE') ||
        d.contains('network') ||
        d.contains('Network') ||
        d.contains('host lookup') ||
        d.contains('Failed host lookup')) {
      return const BootstrapFailureCopy(
        title: 'Connection problem',
        userMessage:
            'The service could not be reached. Check your internet connection '
            'and try again.',
      );
    }
    return const BootstrapFailureCopy(
      title: 'Connection error',
      userMessage:
          'Unable to connect to the server. Please check your internet connection.',
    );
  }
}

/// Shared layout for bootstrap failures (Firebase init, profile load, etc.).
class BootstrapErrorScaffold extends ConsumerWidget {
  const BootstrapErrorScaffold({
    super.key,
    required this.title,
    required this.userMessage,
    required this.errorDetail,
    required this.onRetry,
    this.showSignOut = false,
  });

  final String title;
  final String userMessage;
  final String errorDetail;
  final VoidCallback onRetry;
  final bool showSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                userMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SelectableText(
                errorDetail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: theme.colorScheme.onPrimary,
                    ),
                    label: Text(
                      'Try again',
                      style: TextStyle(color: theme.colorScheme.onPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (showSignOut)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(authServiceProvider).signOut();
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kBorderRadiusMedium,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
