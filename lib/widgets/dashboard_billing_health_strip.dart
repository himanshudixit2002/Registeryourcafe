import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/permission_id.dart';
import '../providers/permissions_provider.dart';
import '../providers/table_provider.dart';
import '../screens/tables/all_sessions_history_screen.dart';
import '../screens/tables/table_grid_screen.dart';
import '../theme/app_page_transitions.dart';
import '../theme/app_theme.dart';

/// Compact session-admin heads-up when checkout billing locks exist.
class DashboardBillingHealthStrip extends ConsumerWidget {
  const DashboardBillingHealthStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watchResolvedPermissions();
    if (!perms.can(PermissionIds.opsSessionAdmin)) {
      return const SizedBox.shrink();
    }

    final locksAsync = ref.watch(billingLockedSessionsProvider);
    return locksAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: cs.errorContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
              onTap: () {
                if (perms.can(PermissionIds.opsSessionsHistory)) {
                  Navigator.of(context).push(
                    AppMaterialPageRoute<void>(
                      builder: (_) => const AllSessionsHistoryScreen(),
                    ),
                  );
                } else if (perms.can(PermissionIds.navTables)) {
                  Navigator.of(context).push(
                    AppMaterialPageRoute<void>(
                      builder: (_) => const TableGridScreen(),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_clock_outlined,
                      color: cs.onErrorContainer,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${sessions.length} checkout lock${sessions.length == 1 ? '' : 's'}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Open session history to review or clear billing locks.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onErrorContainer.withValues(alpha: 0.9),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onErrorContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (Object error, StackTrace stackTrace) =>
          const SizedBox.shrink(),
    );
  }
}
