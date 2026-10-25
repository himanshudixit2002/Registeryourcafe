import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/audit_entry.dart';
import '../../providers/audit_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_helpers.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _filterText = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auditAsync = ref.watch(auditLogProvider);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingSmall,
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingSmall,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filter by action, name, or entity...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _filterText = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: auditAsync.when(
              loading: () => const ShimmerList(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (entries) {
                final filtered = _filterText.isEmpty
                    ? entries
                    : entries
                        .where((e) =>
                            e.action
                                .toLowerCase()
                                .contains(_filterText) ||
                            e.actorName
                                .toLowerCase()
                                .contains(_filterText) ||
                            (e.entityType
                                    ?.toLowerCase()
                                    .contains(_filterText) ??
                                false) ||
                            (e.details
                                    ?.toLowerCase()
                                    .contains(_filterText) ??
                                false))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('No audit entries',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  physics: AppTheme.scrollPhysicsFor(context),
                  padding: EdgeInsets.fromLTRB(
                    isDesktop
                        ? AppTheme.kSpacingXLarge
                        : AppTheme.kSpacingMedium,
                    AppTheme.kSpacingSmall,
                    isDesktop
                        ? AppTheme.kSpacingXLarge
                        : AppTheme.kSpacingMedium,
                    AppTheme.kSpacingXLarge +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) =>
                      _AuditTile(entry: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditEntry entry;
  const _AuditTile({required this.entry});

  IconData get _icon {
    final a = entry.action.toLowerCase();
    if (a.contains('create') || a.contains('add')) {
      return Icons.add_circle_outline;
    }
    if (a.contains('delete') || a.contains('remove')) {
      return Icons.remove_circle_outline;
    }
    if (a.contains('update') ||
        a.contains('edit') ||
        a.contains('change')) {
      return Icons.edit_outlined;
    }
    if (a.contains('refund')) return Icons.undo_outlined;
    if (a.contains('login') || a.contains('sign')) return Icons.login;
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.action,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'by ${entry.actorName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (entry.details != null)
                    Text(entry.details!,
                        style: theme.textTheme.bodySmall),
                  if (entry.entityType != null)
                    Text(
                      '${entry.entityType}${entry.entityId != null ? ' #${entry.entityId}' : ''}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                ],
              ),
            ),
            Text(
              _formatTime(entry.timestamp),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
