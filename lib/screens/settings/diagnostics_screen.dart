import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_build_info.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

/// In-memory [AppLogger] error history for support (owners / debug builds).
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = AppLogger.recentErrorRecords;

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: ListView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(
          AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          AppTheme.kSpacingXLarge + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'Build ${AppBuildInfo.label}. '
            'Recent errors are kept in memory (up to ${AppLogger.recentErrorCapacity}). '
            'Copy the snippet to share with support. Nothing is uploaded automatically.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.kSpacingMedium),
          FilledButton.icon(
            onPressed: records.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: AppLogger.supportSnippet()),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Support snippet copied to clipboard'),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy support snippet'),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          if (records.isEmpty)
            Text(
              'No errors recorded yet.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...records.reversed.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.kSpacingMedium),
                child: Material(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.65,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: SelectableText(
                      '${r.lineSummary}\n'
                      '${r.stackTraceSnippet ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
