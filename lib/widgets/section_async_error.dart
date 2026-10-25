import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

/// Prominent, theme-aware panel for async/tab errors (Firestore, network, etc.).
/// In debug mode, shows the raw Firebase error code for faster diagnosis.
class SectionAsyncError extends StatelessWidget {
  final Object error;
  final String? title;
  final VoidCallback? onRetry;

  const SectionAsyncError({super.key, required this.error, this.title, this.onRetry});

  static bool _isPermissionDenied(String message) {
    return message.contains('permission-denied') ||
        message.contains('PERMISSION_DENIED') ||
        message.contains('Missing or insufficient permissions');
  }

  static bool _isIndexError(String message) {
    return message.contains('failed-precondition') ||
        message.contains('FAILED_PRECONDITION') ||
        message.contains('requires an index') ||
        message.contains('requires a composite index');
  }

  static bool _isNetworkError(String message) {
    return message.contains('unavailable') ||
        message.contains('UNAVAILABLE') ||
        message.contains('network') ||
        message.contains('host lookup');
  }

  static String? _extractFirebaseCode(Object error) {
    if (error is FirebaseException) return error.code;
    final s = error.toString();
    final match = RegExp(r'\[([a-z-]+)\]').firstMatch(s);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final message = error.toString();
    final isPermission = _isPermissionDenied(message);
    final isIndex = _isIndexError(message);
    final isNetwork = _isNetworkError(message);
    final firebaseCode = _extractFirebaseCode(error);

    final IconData icon;
    final String heading;
    final String body;

    if (isPermission) {
      icon = Icons.lock_outline_rounded;
      heading = 'Access denied';
      body = 'The server denied access to this data. Ask a venue admin to verify '
          'your Firestore user profile\'s company id matches this venue, '
          'roleId and role fields are set (staff/owner role docs exist), '
          'and the latest firestore.rules are deployed. '
          'Signing out and back in after role or profile changes often helps.';
    } else if (isIndex) {
      icon = Icons.storage_rounded;
      heading = 'Missing database index';
      body = 'This query requires a composite index that hasn\'t been deployed yet. '
          'Check the Firebase console or run `firebase deploy --only firestore:indexes`.';
    } else if (isNetwork) {
      icon = Icons.wifi_off_rounded;
      heading = 'Connection problem';
      body = 'Could not reach the server. Check your internet connection and try again.';
    } else {
      icon = Icons.warning_amber_rounded;
      heading = AppStrings.somethingWentWrong;
      body = message;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.error.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 44, color: cs.error),
                  const SizedBox(height: 14),
                  Text(
                    title ?? heading,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onErrorContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (kDebugMode && firebaseCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                      ),
                      child: SelectableText(
                        'Firebase code: $firebaseCode',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                  if (kDebugMode && !isPermission && !isIndex && !isNetwork) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
