import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class SAUsersScreen extends ConsumerStatefulWidget {
  const SAUsersScreen({super.key});

  @override
  ConsumerState<SAUsersScreen> createState() => _SAUsersScreenState();
}

class _SAUsersScreenState extends ConsumerState<SAUsersScreen> {
  String _search = '';
  String _roleFilter = 'all';
  String? _userTypeFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allUsersProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.kSpacingMedium,
              AppTheme.kSpacingSmall,
              AppTheme.kSpacingMedium,
              AppTheme.kSpacingSmall,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users by name, email, company...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          usersAsync.when(
            data: (users) {
              final roles = <String>{'all'};
              for (final doc in users) {
                final role = doc.data()['role'] as String?;
                if (role != null && role.isNotEmpty) roles.add(role);
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.kSpacingMedium),
                child: Row(
                  children: roles.map((role) {
                    final selected = _roleFilter == role;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(role == 'all' ? 'All Roles' : _capitalize(role)),
                        selected: selected,
                        onSelected: (_) => setState(() => _roleFilter = role),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.kSpacingMedium),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All users'),
                  selected: _userTypeFilter == null,
                  onSelected: (_) => setState(() => _userTypeFilter = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Business'),
                  selected: _userTypeFilter == 'business',
                  onSelected: (_) => setState(() => _userTypeFilter = _userTypeFilter == 'business' ? null : 'business'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Customers'),
                  selected: _userTypeFilter == 'customer',
                  onSelected: (_) => setState(() => _userTypeFilter = _userTypeFilter == 'customer' ? null : 'customer'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.kSpacingSmall),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                var filtered = users.where((doc) {
                  final data = doc.data();
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final email = (data['email'] as String? ?? '').toLowerCase();
                  final companyId = (data['companyId'] as String? ?? '').toLowerCase();
                  final role = data['role'] as String? ?? '';
                  final matchesSearch = _search.isEmpty ||
                      name.contains(_search) ||
                      email.contains(_search) ||
                      companyId.contains(_search) ||
                      doc.id.toLowerCase().contains(_search);
                  final matchesRole = _roleFilter == 'all' || role == _roleFilter;
                  final matchesUserType = _userTypeFilter == null ||
                      (_userTypeFilter == 'business' && companyId.isNotEmpty) ||
                      (_userTypeFilter == 'customer' && companyId.isEmpty && role == 'customer');
                  return matchesSearch && matchesRole && matchesUserType;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 48, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('No users found', style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  physics: AppTheme.scrollPhysicsFor(context),
                  padding: AppTheme.getScreenPadding(context),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => FadeInWidget(
                    delay: Duration(milliseconds: 50 * index),
                    child: _UserCard(doc: filtered[index]),
                  ),
                );
              },
              loading: () => const ShimmerList(),
              error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _UserCard extends ConsumerWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _UserCard({required this.doc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final data = doc.data();
    final name = data['name'] as String? ?? 'Unknown';
    final email = data['email'] as String? ?? '';
    final role = data['role'] as String? ?? 'unknown';
    final companyId = data['companyId'] as String? ?? '';
    final suspended = data['suspended'] == true;

    Color roleColor;
    switch (role) {
      case 'admin':
        roleColor = cs.primary;
      case 'manager':
        roleColor = AppTheme.infoColor;
      case 'staff':
        roleColor = AppTheme.successColor;
      default:
        roleColor = cs.onSurfaceVariant;
    }

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: suspended
                ? AppTheme.warningColor.withValues(alpha: 0.15)
                : roleColor.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: suspended ? AppTheme.warningColor : roleColor,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.kSpacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(label: role.toUpperCase(), color: roleColor),
                    if (suspended) ...[
                      const SizedBox(width: 6),
                      StatusBadge(label: 'SUSPENDED', color: AppTheme.warningColor),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(email, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                if (companyId.isNotEmpty)
                  Text(
                    'Company: $companyId',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (ctx) => [
              if (!suspended)
                const PopupMenuItem(value: 'suspend', child: Text('Suspend'))
              else
                const PopupMenuItem(value: 'reactivate', child: Text('Reactivate')),
              const PopupMenuItem(value: 'changeRole', child: Text('Change Role')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final service = ref.read(superAdminServiceProvider);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    try {
      switch (action) {
        case 'suspend':
          await service.suspendUser(doc.id);
          service.logSuperAdminAction(action: 'user_suspended', actorEmail: email, entityType: 'user', entityId: doc.id, details: 'Suspended user ${doc.data()['name'] ?? doc.id}');
          if (context.mounted) context.showSuccessSnackbar('User suspended');
        case 'reactivate':
          await service.reactivateUser(doc.id);
          service.logSuperAdminAction(action: 'user_reactivated', actorEmail: email, entityType: 'user', entityId: doc.id, details: 'Reactivated user ${doc.data()['name'] ?? doc.id}');
          if (context.mounted) context.showSuccessSnackbar('User reactivated');
        case 'changeRole':
          if (!context.mounted) return;
          final newRole = await showDialog<String>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Select Role'),
              children: ['admin', 'manager', 'staff'].map((role) {
                return SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, role),
                  child: Text(role[0].toUpperCase() + role.substring(1)),
                );
              }).toList(),
            ),
          );
          if (newRole != null) {
            await service.updateUserField(doc.id, {'role': newRole});
            service.logSuperAdminAction(action: 'user_role_changed', actorEmail: email, entityType: 'user', entityId: doc.id, details: 'Changed role to $newRole for ${doc.data()['name'] ?? doc.id}');
            if (context.mounted) context.showSuccessSnackbar('Role changed to $newRole');
          }
      }
    } catch (e) {
      if (context.mounted) context.showErrorSnackbar('Error: $e');
    }
  }
}
