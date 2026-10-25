import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/permission_id.dart';
import '../../../navigation/shell_route_titles.dart';
import '../../../models/company_role.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/tenant_provider.dart';
import '../../../theme/app_theme.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

/// Create a custom role, or view/edit a non-system role. System roles are read-only.
class CompanyRoleEditorScreen extends ConsumerStatefulWidget {
  const CompanyRoleEditorScreen({super.key, this.roleToEdit, this.seedFrom})
    : assert(
        roleToEdit == null || seedFrom == null,
        'Provide only one of roleToEdit or seedFrom',
      );

  /// Existing role from Firestore (system roles open read-only).
  final CompanyRole? roleToEdit;

  /// When creating a role, optionally start from another role’s permissions/name.
  final CompanyRole? seedFrom;

  @override
  ConsumerState<CompanyRoleEditorScreen> createState() =>
      _CompanyRoleEditorScreenState();
}

class _CompanyRoleEditorScreenState
    extends ConsumerState<CompanyRoleEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late Set<String> _selected;

  bool get _isReadOnly =>
      widget.roleToEdit != null && widget.roleToEdit!.isSystem;

  bool get _isCreate => widget.roleToEdit == null;

  @override
  void initState() {
    super.initState();
    final r = widget.roleToEdit;
    final seed = widget.seedFrom;
    if (r != null) {
      _nameController = TextEditingController(text: r.name);
      _descController = TextEditingController(text: r.description ?? '');
      _selected = r.permissionIds.toSet();
    } else if (seed != null) {
      _nameController = TextEditingController(text: '${seed.name} (copy)');
      _descController = TextEditingController(text: seed.description ?? '');
      _selected = seed.permissionIds.toSet();
    } else {
      _nameController = TextEditingController();
      _descController = TextEditingController();
      _selected = Set<String>.from(DefaultRolePermissions.staff);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  static String _labelFor(String id) {
    switch (id) {
      case PermissionIds.navDashboard:
        return ShellRouteTitles.dashboard;
      case PermissionIds.navSales:
        return ShellRouteTitles.sales;
      case PermissionIds.navInventory:
        return ShellRouteTitles.inventory;
      case PermissionIds.navLeaderboard:
        return ShellRouteTitles.leaderboard;
      case PermissionIds.navLoyalty:
        return ShellRouteTitles.loyalty;
      case PermissionIds.navTournaments:
        return ShellRouteTitles.tournaments;
      case PermissionIds.navMerchandise:
        return ShellRouteTitles.merchandise;
      case PermissionIds.navCafe:
        return ShellRouteTitles.cafe;
      case PermissionIds.navCustomers:
        return ShellRouteTitles.customers;
      case PermissionIds.navTables:
        return ShellRouteTitles.tables;
      case PermissionIds.opsRefund:
        return 'Refunds';
      case PermissionIds.opsTableConfigure:
        return 'Configure tables & billing';
      case PermissionIds.opsTableTypesConfigure:
        return 'Table types (labels & categories)';
      case PermissionIds.opsSessionAdmin:
        return 'Session administration';
      case PermissionIds.opsSessionsHistory:
        return 'Sessions history tools';
      case PermissionIds.opsCustomersAdmin:
        return 'Customer administration';
      case PermissionIds.opsMembershipTypesConfigure:
        return 'Membership plans (tiers & pricing)';
      case PermissionIds.opsCafeAdmin:
        return 'Cafe administration (stock, etc.)';
      case PermissionIds.opsMerchandiseManage:
        return 'Merchandise management';
      case PermissionIds.opsLoyaltyConfigure:
        return 'Loyalty configuration';
      case PermissionIds.opsLoyaltyConvert:
        return 'Convert loyalty points to credits';
      case PermissionIds.opsLeaderboardManage:
        return 'Leaderboard settings & reset';
      case PermissionIds.opsTournamentManage:
        return 'Tournament management';
      case PermissionIds.settingsModules:
        return 'Venue modules (navigation)';
      case PermissionIds.settingsRoles:
        return 'Roles & permissions';
      case PermissionIds.staffInvite:
        return 'Invite staff';
      default:
        return id;
    }
  }

  static const List<String> _navPerms = [
    PermissionIds.navDashboard,
    PermissionIds.navSales,
    PermissionIds.navInventory,
    PermissionIds.navLeaderboard,
    PermissionIds.navLoyalty,
    PermissionIds.navTournaments,
    PermissionIds.navMerchandise,
    PermissionIds.navCafe,
    PermissionIds.navCustomers,
    PermissionIds.navTables,
  ];

  static const List<String> _opsPerms = [
    PermissionIds.opsRefund,
    PermissionIds.opsTableConfigure,
    PermissionIds.opsTableTypesConfigure,
    PermissionIds.opsSessionAdmin,
    PermissionIds.opsSessionsHistory,
    PermissionIds.opsCustomersAdmin,
    PermissionIds.opsMembershipTypesConfigure,
    PermissionIds.opsCafeAdmin,
    PermissionIds.opsMerchandiseManage,
    PermissionIds.opsLoyaltyConfigure,
    PermissionIds.opsLoyaltyConvert,
    PermissionIds.opsLeaderboardManage,
    PermissionIds.opsTournamentManage,
  ];

  static const List<String> _settingsPerms = [
    PermissionIds.settingsModules,
    PermissionIds.settingsRoles,
    PermissionIds.staffInvite,
  ];

  Future<void> _save() async {
    if (_isReadOnly) return;
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one permission for this role.'),
        ),
      );
      return;
    }
    final service = ref.read(companyRolesServiceProvider);
    final id = _isCreate
        ? tenant.permissionRoles().doc().id
        : widget.roleToEdit!.id;
    final role = CompanyRole(
      id: id,
      name: name,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      permissionIds: _selected.toList()..sort(),
      isSystem: false,
    );
    try {
      await service.saveRole(tenant, role);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Role saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManageRoles = ref.watchResolvedPermissions().can(
      PermissionIds.settingsRoles,
    );

    if (!canManageRoles) {
      return Scaffold(
        appBar: AppBar(title: const Text('Role')),
        body: const Center(
          child: Text('You do not have access to edit roles.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? 'New role' : widget.roleToEdit!.name),
        actions: [
          if (!_isReadOnly)
            TextButton(onPressed: _save, child: const Text(AppStrings.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
        children: [
          if (_isReadOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This is a system role. Duplicate it from the list to create a customizable copy.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            readOnly: _isReadOnly,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            readOnly: _isReadOnly,
          ),
          const SizedBox(height: 24),
          Text('Navigation', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._navPerms.map((p) => _permTile(theme, p)),
          const SizedBox(height: 16),
          Text('Operations', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._opsPerms.map((p) => _permTile(theme, p)),
          const SizedBox(height: 16),
          Text('Settings & staff', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._settingsPerms.map((p) => _permTile(theme, p)),
        ],
      ),
    );
  }

  Widget _permTile(ThemeData theme, String permissionId) {
    final checked = _selected.contains(permissionId);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_labelFor(permissionId)),
      subtitle: Text(
        permissionId,
        style: theme.textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: checked,
      onChanged: _isReadOnly
          ? null
          : (v) {
              setState(() {
                if (v) {
                  _selected.add(permissionId);
                } else {
                  _selected.remove(permissionId);
                }
              });
            },
    );
  }
}
