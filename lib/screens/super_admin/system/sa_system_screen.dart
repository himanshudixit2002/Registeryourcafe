import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

final _platformSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(superAdminServiceProvider).getPlatformSettings();
});

class SASystemScreen extends ConsumerStatefulWidget {
  const SASystemScreen({super.key});

  @override
  ConsumerState<SASystemScreen> createState() => _SASystemScreenState();
}

class _SASystemScreenState extends ConsumerState<SASystemScreen> {
  final _appNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _announcementTitleController = TextEditingController();
  final _announcementBodyController = TextEditingController();
  bool _maintenanceMode = false;
  bool _settingsLoaded = false;

  @override
  void dispose() {
    _appNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _announcementTitleController.dispose();
    _announcementBodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settingsAsync = ref.watch(_platformSettingsProvider);
    final announcementsAsync = ref.watch(announcementsProvider);
    final auditLogAsync = ref.watch(auditLogProvider);

    settingsAsync.whenData((settings) {
      if (!_settingsLoaded) {
        _appNameController.text = settings['appName'] as String? ?? 'Registeryourcafe';
        _contactEmailController.text = settings['contactEmail'] as String? ?? '';
        _contactPhoneController.text = settings['contactPhone'] as String? ?? '';
        _maintenanceMode = settings['maintenanceMode'] as bool? ?? false;
        _settingsLoaded = true;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _settingsLoaded = false;
              ref.invalidate(_platformSettingsProvider);
              ref.invalidate(announcementsProvider);
              ref.invalidate(auditLogProvider);
            },
          ),
        ],
      ),
      body: ListView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: AppTheme.getScreenPadding(context),
        children: [
          const GradientHeader(
            title: 'Platform Configuration',
            subtitle: 'Manage system settings and announcements',
          ),
          const SizedBox(height: AppTheme.kSpacingMedium),
          FadeInWidget(
            delay: const Duration(milliseconds: 100),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('General', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppTheme.kSpacingMedium),
                  TextField(
                    controller: _appNameController,
                    decoration: const InputDecoration(
                      labelText: 'App Name',
                      prefixIcon: Icon(Icons.apps),
                    ),
                  ),
                  const SizedBox(height: AppTheme.kSpacingMedium),
                  TextField(
                    controller: _contactEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppTheme.kSpacingMedium),
                  TextField(
                    controller: _contactPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppTheme.kSpacingLarge),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          FadeInWidget(
            delay: const Duration(milliseconds: 200),
            child: Text('Maintenance', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppTheme.kSpacingSmall),
          FadeInWidget(
            delay: const Duration(milliseconds: 300),
            child: AppCard(
              child: SwitchListTile(
                value: _maintenanceMode,
                onChanged: (val) async {
                  setState(() => _maintenanceMode = val);
                  try {
                    await ref.read(superAdminServiceProvider).savePlatformSettings({'maintenanceMode': val});
                    if (mounted) {
                      context.showSuccessSnackbar(val ? 'Maintenance mode enabled' : 'Maintenance mode disabled');
                    }
                  } catch (e) {
                    if (mounted) context.showErrorSnackbar('Error: $e');
                  }
                },
                title: Text('Maintenance Mode', style: theme.textTheme.titleSmall),
                subtitle: Text(
                  _maintenanceMode ? 'Platform is in maintenance' : 'Platform is live',
                  style: TextStyle(color: _maintenanceMode ? AppTheme.warningColor : AppTheme.successColor),
                ),
                secondary: Icon(
                  _maintenanceMode ? Icons.engineering : Icons.cloud_done,
                  color: _maintenanceMode ? AppTheme.warningColor : AppTheme.successColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          FadeInWidget(
            delay: const Duration(milliseconds: 400),
            child: Text('New Announcement', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppTheme.kSpacingSmall),
          FadeInWidget(
            delay: const Duration(milliseconds: 500),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Broadcast to all cafes', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: AppTheme.kSpacingMedium),
                  TextField(
                    controller: _announcementTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: AppTheme.kSpacingMedium),
                  TextField(
                    controller: _announcementBodyController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      prefixIcon: Icon(Icons.message_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: AppTheme.kSpacingMedium),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _createAnnouncement,
                      icon: const Icon(Icons.campaign, size: 18),
                      label: const Text('Send Announcement'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          Text('Past Announcements', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingSmall),
          announcementsAsync.when(
            data: (announcements) {
              if (announcements.isEmpty) {
                return AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
                    child: Center(
                      child: Text('No announcements yet', style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  ),
                );
              }
              return Column(
                children: announcements.map((doc) {
                  final d = doc.data();
                  final title = d['title'] as String? ?? 'Untitled';
                  final body = d['body'] as String? ?? '';
                  final createdAt = d['createdAt'];
                  String dateStr = '';
                  if (createdAt is Timestamp) {
                    dateStr = DateFormat.yMMMd().add_jm().format(createdAt.toDate());
                  }
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.campaign, color: cs.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                              onPressed: () => _deleteAnnouncement(doc.id),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(body, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                        const SizedBox(height: 4),
                        Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const ShimmerList(itemCount: 2, itemHeight: 80),
            error: (e, _) => Text('Error: $e', style: TextStyle(color: cs.error)),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          Text('Audit Log', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.kSpacingSmall),
          auditLogAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
                    child: Center(
                      child: Text('No audit log entries', style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  ),
                );
              }
              return Column(
                children: entries.map((doc) {
                  final d = doc.data();
                  final action = d['action'] as String? ?? '';
                  final actor = d['actorEmail'] as String? ?? '';
                  final details = d['details'] as String? ?? '';
                  final entityType = d['entityType'] as String? ?? '';
                  final entityId = d['entityId'] as String? ?? '';
                  final ts = d['timestamp'];
                  String dateStr = '';
                  if (ts is Timestamp) {
                    dateStr = DateFormat.yMMMd().add_jm().format(ts.toDate());
                  }
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.history, color: cs.primary, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(action, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                  Text(actor, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                                ],
                              ),
                            ),
                            Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                          ],
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(details, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                        if (entityType.isNotEmpty || entityId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [if (entityType.isNotEmpty) entityType, if (entityId.isNotEmpty) entityId].join(': '),
                            style: theme.textTheme.labelSmall?.copyWith(color: cs.outline, fontFamily: 'monospace'),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const ShimmerList(itemCount: 3, itemHeight: 70),
            error: (e, _) => Text('Error: $e', style: TextStyle(color: cs.error)),
          ),
          const SizedBox(height: AppTheme.kSpacingLarge),
          FadeInWidget(
            delay: const Duration(milliseconds: 600),
            child: Text('Account', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppTheme.kSpacingSmall),
          FadeInWidget(
            delay: const Duration(milliseconds: 700),
            child: AppCard(
              child: ListTile(
                leading: Icon(Icons.logout, color: cs.error),
                title: Text('Sign Out', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
                subtitle: Text('Sign out of super admin', style: TextStyle(color: cs.onSurfaceVariant)),
                onTap: () => ref.read(authServiceProvider).signOut(),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.kSpacingXLarge),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      final service = ref.read(superAdminServiceProvider);
      await service.savePlatformSettings({
        'appName': _appNameController.text.trim(),
        'contactEmail': _contactEmailController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'maintenanceMode': _maintenanceMode,
      });
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      service.logSuperAdminAction(action: 'platform_settings_saved', actorEmail: email, details: 'Saved platform settings');
      if (mounted) context.showSuccessSnackbar('Settings saved');
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _createAnnouncement() async {
    final title = _announcementTitleController.text.trim();
    final body = _announcementBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      context.showWarningSnackbar('Title and message are required');
      return;
    }
    try {
      final service = ref.read(superAdminServiceProvider);
      await service.createAnnouncement(title: title, body: body);
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      service.logSuperAdminAction(action: 'announcement_created', actorEmail: email, details: 'Created announcement: $title');
      _announcementTitleController.clear();
      _announcementBodyController.clear();
      if (mounted) context.showSuccessSnackbar('Announcement sent');
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final service = ref.read(superAdminServiceProvider);
      await service.deleteAnnouncement(id);
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      service.logSuperAdminAction(action: 'announcement_deleted', actorEmail: email, entityType: 'announcement', entityId: id);
      if (mounted) context.showSuccessSnackbar('Announcement deleted');
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Error: $e');
    }
  }
}
