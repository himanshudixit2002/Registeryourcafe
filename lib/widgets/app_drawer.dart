import 'package:registeryourcafe/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../legal/legal_launch.dart';
import '../theme/app_theme.dart';

class AppDrawer extends ConsumerWidget {
  final int selectedIndex;
  final void Function(int) onItemSelected;
  final List<({String title, IconData icon, String? subtitle})> items;
  final String? headerTitle;
  final Widget? headerIcon;
  final bool isExtended;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
    this.headerTitle,
    this.headerIcon,
    this.isExtended = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);

    Widget buildHeader() {
      final bool showGradient = !(isExtended && headerIcon != null);
      final headerPadding = isDesktop
          ? AppTheme.kSpacingXLarge
          : (isExtended ? AppTheme.kSpacingLarge : AppTheme.kSpacingMedium);

      return DrawerHeader(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.all(headerPadding),
        decoration: showGradient
            ? BoxDecoration(
                gradient: theme.brightness == Brightness.dark
                    ? AppTheme.primaryGradient
                    : AppTheme.primaryGradientLight,
              )
            : null,
        child: isExtended
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (headerIcon != null) ...[
                    headerIcon!,
                    if (headerTitle != null) ...[
                      const SizedBox(height: AppTheme.kSpacingMedium),
                      Text(
                        headerTitle!,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ],
              )
            : Center(
                child:
                    headerIcon ??
                    Icon(Icons.menu, color: theme.colorScheme.onSurface),
              ),
      );
    }

    Widget buildItem(int index) {
      final item = items[index];
      final isSelected = selectedIndex == index;
      final verticalPadding = isDesktop
          ? AppTheme.kSpacingSmall
          : AppTheme.kSpacingXSmall;

      return AnimatedContainer(
        duration: AppTheme.kAnimationDurationShort,
        margin: EdgeInsets.symmetric(
          horizontal: AppTheme.kSpacingSmall,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop
                ? AppTheme.kSpacingLarge
                : AppTheme.kSpacingMedium,
            vertical: verticalPadding,
          ),
          selected: isSelected,
          leading: Icon(
            item.icon,
            size: isDesktop ? 28 : 24,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          title: isExtended
              ? Text(
                  item.title,
                  style:
                      (isDesktop
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.titleMedium)
                          ?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                )
              : null,
          subtitle: isExtended && item.subtitle != null
              ? Text(
                  item.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
          ),
          onTap: () => onItemSelected(index),
        ),
      );
    }

    return Material(
      color:
          theme.drawerTheme.backgroundColor ??
          theme.colorScheme.surfaceContainer.withValues(alpha: 0.88),
      child: Column(
        children: [
          buildHeader(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                vertical: isDesktop
                    ? AppTheme.kSpacingMedium
                    : AppTheme.kSpacingSmall,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => buildItem(index),
            ),
          ),
          const Divider(height: 1),
          _buildDrawerItem(
            context,
            ref: ref,
            icon: Icons.policy_outlined,
            title: 'Legal & support',
            onTap: () {
              final nav = Navigator.of(context);
              if (nav.canPop()) nav.pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  LegalLaunch.showLegalSupportSheet(context);
                }
              });
            },
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: isDesktop
                  ? AppTheme.kSpacingMedium
                  : AppTheme.kSpacingSmall,
            ),
            child: _buildDrawerItem(
              context,
              ref: ref,
              icon: Icons.logout_outlined,
              title: 'Sign Out',
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isDesktop
            ? AppTheme.kSpacingLarge
            : AppTheme.kSpacingMedium,
        vertical: isDesktop ? AppTheme.kSpacingSmall : AppTheme.kSpacingXSmall,
      ),
      leading: Icon(
        icon,
        size: isDesktop ? 28 : 24,
        color: theme.colorScheme.onSurface,
      ),
      title: Text(
        title,
        style:
            (isDesktop
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.titleMedium)
                ?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
      ),
      onTap: onTap,
    );
  }
}
