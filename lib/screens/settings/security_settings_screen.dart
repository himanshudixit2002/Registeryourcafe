import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Security & compliance')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.all(AppTheme.isDesktop(context)
            ? AppTheme.kSpacingXLarge
            : AppTheme.kSpacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tile(theme, Icons.security, 'Two-Factor Authentication',
                'Add extra security layer for admin accounts', true),
            const SizedBox(height: 12),
            _tile(theme, Icons.vpn_lock, 'IP Whitelist',
                'Restrict access to specific IP addresses', false),
            const SizedBox(height: 12),
            _tile(theme, Icons.login, 'Login Monitoring',
                'Track failed login attempts and suspicious activity', true),
            const SizedBox(height: 12),
            _tile(theme, Icons.enhanced_encryption, 'Data Encryption',
                'End-to-end encryption for sensitive data', true),
            const SizedBox(height: 12),
            _tile(theme, Icons.privacy_tip, 'Privacy Policy',
                'Manage and display privacy policy', false),
            const SizedBox(height: 12),
            _tile(theme, Icons.gavel, 'GDPR Compliance',
                'Data export, deletion, and consent management', false),
            const SizedBox(height: 12),
            _tile(theme, Icons.timer, 'Session Timeout',
                'Auto-logout after inactivity period', true),
            const SizedBox(height: 12),
            _tile(theme, Icons.password, 'Password Policy',
                'Minimum length, complexity requirements', true),
            const SizedBox(height: 12),
            _tile(theme, Icons.admin_panel_settings, 'Data Access Rules',
                'Role-based data visibility rules', false),
            const SizedBox(height: 12),
            _tile(theme, Icons.visibility_off, 'Data Masking',
                'Mask sensitive customer data for staff', false),
          ],
        ),
      ),
    );
  }

  Widget _tile(ThemeData theme, IconData icon, String title, String subtitle,
      bool enabled) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SwitchListTile(
        secondary: Icon(icon,
            color: enabled
                ? theme.colorScheme.primary
                : theme.colorScheme.outline),
        title: Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        value: enabled,
        onChanged: (_) {},
      ),
    );
  }
}
