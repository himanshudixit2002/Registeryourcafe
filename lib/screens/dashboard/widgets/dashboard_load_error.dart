import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/dashboard_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_panel.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class DashboardLoadError extends ConsumerWidget {
  const DashboardLoadError({super.key, required this.error});

  final Object error;

  static bool _isPermissionDenied(String message) {
    return message.contains('permission-denied') ||
        message.contains('PERMISSION_DENIED');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final message = error.toString();
    final isPermission = _isPermissionDenied(message);
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassPanel(
            blur: GlassBlur.auto,
            borderRadius: 22,
            borderColor: cs.error.withValues(alpha: 0.45),
            padding: EdgeInsets.all(isMobile ? 20 : 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.error.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.dashboard_customize_outlined,
                    size: 40,
                    color: cs.error,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isPermission ? 'Cannot load dashboard' : 'Dashboard error',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  isPermission
                      ? 'Your account may not have access to company analytics, or Firestore rules need updating. Ask an admin to verify your role and company link.'
                      : 'Something went wrong while loading dashboard data.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!isPermission) ...[
                  const SizedBox(height: 14),
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Technical details',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      children: [
                        SelectableText(
                          message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(dashboardProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(AppStrings.retry),
                  style: FilledButton.styleFrom(
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
          ),
        ),
      ),
    );
  }
}
