import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/navigation/shell_route_titles.dart';
import 'package:registeryourcafe/providers/auth_provider.dart';
import 'package:registeryourcafe/providers/company_module_provider.dart';
import 'package:registeryourcafe/providers/shell_route_title_provider.dart';
import 'package:registeryourcafe/widgets/loading_indicator.dart';
import 'package:registeryourcafe/models/app_user.dart';
import 'package:registeryourcafe/auth/permission_id.dart';
import 'package:registeryourcafe/providers/permissions_provider.dart';
import 'package:registeryourcafe/screens/admin/create_staff_screen.dart';
import 'package:registeryourcafe/theme/app_theme.dart';
import 'package:registeryourcafe/widgets/glass_modal_bottom_sheet.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider);
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);

    final canInviteStaff = ref.watchResolvedPermissions().can(
      PermissionIds.staffInvite,
    );
    final companyProfile = ref.watch(companyProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: appUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No user logged in.'));
          }
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                physics: AppTheme.scrollPhysicsFor(context),
                slivers: [
                  // Profile Header
                  SliverToBoxAdapter(
                    child: _buildProfileHeader(context, theme, user, isMobile),
                  ),

                  SliverToBoxAdapter(
                    child: _buildSettingsShortcut(context, theme, isMobile),
                  ),

                  // Menu Items
                  SliverToBoxAdapter(
                    child: _buildMenuSection(context, theme, user, isMobile),
                  ),

                  // Admin Section
                  if (canInviteStaff)
                    SliverToBoxAdapter(
                      child: _buildAdminSection(
                        context,
                        theme,
                        isMobile,
                        canOwnerCreateStaffAccounts:
                            isRegisteredCompanyOwner(
                              companyProfile?.ownerUid,
                              user.uid,
                            ),
                      ),
                    ),

                  // Logout Button
                  SliverToBoxAdapter(
                    child: _buildLogoutSection(context, theme, isMobile),
                  ),

                  // Bottom padding (includes workspace hub / mobile nav via MediaQuery).
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 40 + MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const LoadingIndicator(
          showLogo: true,
          message: 'Loading profile...',
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading profile',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    ThemeData theme,
    AppUser user,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.18),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          // Avatar with gradient border
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.5),
                ],
              ),
            ),
            child: CircleAvatar(
              radius: isMobile ? 40 : 50,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                  ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                  : null,
              child: FirebaseAuth.instance.currentUser?.photoURL == null
                  ? Icon(
                      Icons.person_rounded,
                      size: isMobile ? 48 : 60,
                      color: theme.colorScheme.primary,
                    )
                  : null,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Name
          Text(
            user.name,
            style: TextStyle(
              fontSize: isMobile ? 22 : 26,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),

          // Email
          Text(
            user.email,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: isMobile ? 14 : 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getRoleColor(context, user.role).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getRoleColor(context, user.role).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getRoleIcon(user.role),
                  size: 16,
                  color: _getRoleColor(context, user.role),
                ),
                const SizedBox(width: 6),
                Text(
                  user.role.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(context, user.role),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsShortcut(
    BuildContext context,
    ThemeData theme,
    bool isMobile,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        0,
        isMobile ? 16 : 24,
        20,
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            navigateToShellTitleIfVisible(ref, ShellRouteTitles.settings);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Venue modules, display, and staff access',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    ThemeData theme,
    AppUser user,
    bool isMobile,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Account Information',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: user.email,
                  onTap: () => _copyToClipboard(context, user.email, 'Email'),
                ),
                _buildDivider(),
                if (user.phoneNumber != null &&
                    user.phoneNumber!.isNotEmpty) ...[
                  _buildMenuItem(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    subtitle: user.phoneNumber!,
                    onTap: () => _copyToClipboard(
                      context,
                      user.phoneNumber!,
                      'Phone number',
                    ),
                  ),
                  _buildDivider(),
                ],
                _buildMenuItem(
                  icon: Icons.fingerprint,
                  title: 'User ID',
                  subtitle: '${user.uid.substring(0, 12)}...',
                  onTap: () => _copyToClipboard(context, user.uid, 'User ID'),
                  trailing: Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildAdminSection(
    BuildContext context,
    ThemeData theme,
    bool isMobile, {
    required bool canOwnerCreateStaffAccounts,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Admin Tools',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canOwnerCreateStaffAccounts
                    ? () {
                        Navigator.of(context).push(
                          PageRouteBuilder<void>(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const CreateStaffScreen(),
                            transitionsBuilder:
                                (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(1.0, 0.0),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                child: child,
                              );
                            },
                          ),
                        );
                      }
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Only the company owner can create staff sign-in accounts.',
                            ),
                          ),
                        );
                      },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: canOwnerCreateStaffAccounts
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 24,
                          color: canOwnerCreateStaffAccounts
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Staff Account',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              canOwnerCreateStaffAccounts
                                  ? 'Add new staff members to the team'
                                  : 'Only the company owner can create sign-in accounts',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        canOwnerCreateStaffAccounts
                            ? Icons.chevron_right_rounded
                            : Icons.info_outline_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutSection(
    BuildContext context,
    ThemeData theme,
    bool isMobile,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showLogoutConfirmation(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sign Out',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    final theme = Theme.of(context);
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.onPrimary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text('$label copied to clipboard'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: theme.colorScheme.primary,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassModalSheetChrome(
        topRadius: 20,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 32,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sign Out?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to sign out?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(AppStrings.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await ref.read(authServiceProvider).signOut();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(BuildContext context, UserRole role) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (role) {
      case UserRole.admin:
        return cs.tertiary;
      case UserRole.staff:
        return sem.info;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.staff:
        return Icons.badge_rounded;
    }
  }
}
