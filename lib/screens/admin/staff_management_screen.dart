import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/staff_member.dart';
import '../../providers/company_roles_provider.dart';
import '../../providers/staff_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final staffAsync = ref.watch(companyStaffProvider);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Staff management')),
      body: staffAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (staff) {
          if (staff.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No staff members yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create staff accounts from Settings.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.fromLTRB(
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingMedium,
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingXLarge + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: staff.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTheme.kSpacingSmall),
            itemBuilder: (context, index) {
              final member = staff[index];
              return _StaffCard(member: member);
            },
          );
        },
      ),
    );
  }
}

class _StaffCard extends ConsumerWidget {
  final StaffMember member;

  const _StaffCard({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rolesAsync = ref.watch(companyRolesListProvider);
    final roles = rolesAsync.valueOrNull ?? [];
    final roleName = roles
            .where((r) => r.id == member.roleId)
            .map((r) => r.name)
            .firstOrNull ??
        member.role;

    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isActive
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: member.isActive
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          member.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member.email),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    roleName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!member.isActive) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Inactive',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, ref, action),
          itemBuilder: (_) => [
            if (roles.isNotEmpty)
              const PopupMenuItem(
                  value: 'changeRole', child: Text('Change role')),
            PopupMenuItem(
              value: 'toggleActive',
              child: Text(member.isActive ? 'Deactivate' : 'Activate'),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'changeRole':
        _showChangeRoleDialog(context, ref);
      case 'toggleActive':
        _toggleActive(context, ref);
    }
  }

  Future<void> _showChangeRoleDialog(
      BuildContext context, WidgetRef ref) async {
    final roles = ref.read(companyRolesListProvider).valueOrNull ?? [];
    if (roles.isEmpty) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select role'),
        children: [
          for (final r in roles)
            RadioListTile<String>(
              value: r.id,
              groupValue: member.roleId,
              title: Text(r.name),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    try {
      final service = ref.read(staffServiceProvider);
      if (service == null) return;
      await service.updateStaffRole(member.uid, picked);
      if (context.mounted) context.showSuccessSnackbar('Role updated');
    } catch (e) {
      if (context.mounted) context.showErrorSnackbar('Failed: $e');
    }
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(staffServiceProvider);
      if (service == null) return;
      await service.toggleStaffActive(
            member.uid,
            !member.isActive,
          );
      if (context.mounted) {
        context.showSuccessSnackbar(
          member.isActive ? 'Staff deactivated' : 'Staff activated',
        );
      }
    } catch (e) {
      if (context.mounted) context.showErrorSnackbar('Failed: $e');
    }
  }
}
