import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/company_role.dart';
import '../../../providers/company_roles_provider.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/tenant_provider.dart';
import '../../../auth/permission_id.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_page_transitions.dart';
import '../../../widgets/permission_denied_scaffold.dart';
import 'company_role_editor_screen.dart';
import 'package:registeryourcafe/constants/app_strings.dart';
import '../../../utils/app_logger.dart';

/// Lists tenant roles and opens the editor.
class CompanyRolesListScreen extends ConsumerStatefulWidget {
  const CompanyRolesListScreen({super.key});

  @override
  ConsumerState<CompanyRolesListScreen> createState() =>
      _CompanyRolesListScreenState();
}

class _CompanyRolesListScreenState
    extends ConsumerState<CompanyRolesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null || !mounted) return;
      try {
        await ref.read(companyRolesServiceProvider).ensureDefaultRoles(tenant);
      } catch (e, st) {
        AppLogger.logNonFatalProviderSideEffect(
          'ensureDefaultRoles on roles list open failed',
          e,
          st,
          tag: 'CompanyRoles',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rolesAsync = ref.watch(companyRolesListProvider);
    final canManage = ref.watchResolvedPermissions().can(
      PermissionIds.settingsRoles,
    );

    if (!canManage) {
      return const PermissionDeniedScaffold(
        title: 'Roles & permissions',
        message: 'You do not have access to manage roles.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles & permissions'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Add role',
              icon: const Icon(Icons.add_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  AppMaterialPageRoute<void>(
                    builder: (_) => const CompanyRoleEditorScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: rolesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
            child: Text(
              'Could not load roles: $e',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ),
        data: (roles) {
          if (roles.isEmpty) {
            return const Center(child: Text('No roles found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
            itemCount: roles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final role = roles[index];
              return Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(role.name)),
                      if (role.isSystem)
                        Chip(
                          label: const Text('System'),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          labelStyle: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${role.permissionIds.length} permission${role.permissionIds.length == 1 ? '' : 's'}',
                  ),
                  trailing: canManage
                      ? PopupMenuButton<String>(
                          onSelected: (action) =>
                              _onRoleMenu(context, action, role),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('View / edit'),
                            ),
                            const PopupMenuItem(
                              value: 'dup',
                              child: Text('Duplicate'),
                            ),
                            if (!role.isSystem)
                              const PopupMenuItem(
                                value: 'del',
                                child: Text('Delete'),
                              ),
                          ],
                        )
                      : null,
                  onTap: canManage
                      ? () {
                          Navigator.of(context).push(
                            AppMaterialPageRoute<void>(
                              builder: (_) =>
                                  CompanyRoleEditorScreen(roleToEdit: role),
                            ),
                          );
                        }
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onRoleMenu(
    BuildContext context,
    String action,
    CompanyRole role,
  ) async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    final service = ref.read(companyRolesServiceProvider);

    switch (action) {
      case 'edit':
        if (!context.mounted) return;
        await Navigator.of(context).push(
          AppMaterialPageRoute<void>(
            builder: (_) => CompanyRoleEditorScreen(roleToEdit: role),
          ),
        );
      case 'dup':
        try {
          final id = await service.duplicateRole(tenant, role);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Duplicated role. New id: $id')),
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Duplicate failed: $e')));
        }
      case 'del':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete role'),
            content: Text('Delete "${role.name}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(AppStrings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok != true || !context.mounted) return;
        try {
          await service.deleteRole(tenant, role);
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Role deleted')));
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
    }
  }
}
