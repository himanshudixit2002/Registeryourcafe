import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final List<Widget>? actions;
  final Widget? trailing;
  final bool compact;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.actions,
    this.trailing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return Container(
      padding: EdgeInsets.all(
        compact ? (isMobile ? 12 : 16) : (isMobile ? 16 : 24),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.14),
            (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: EdgeInsets.all(
                compact ? (isMobile ? 8 : 10) : (isMobile ? 10 : 14),
              ),
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withValues(
                  alpha: 0.18,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: compact ? (isMobile ? 20 : 24) : (isMobile ? 24 : 32),
                color: iconColor ?? theme.colorScheme.primary,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      (compact
                              ? (isMobile
                                    ? theme.textTheme.titleMedium
                                    : theme.textTheme.titleLarge)
                              : (isMobile
                                    ? theme.textTheme.titleLarge
                                    : theme.textTheme.headlineSmall))
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                ),
                if (subtitle case final String s) ...[
                  const SizedBox(height: 4),
                  Text(
                    s,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...[trailing].whereType<Widget>(),
          ...?actions,
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onSeeAll;
  final String? seeAllText;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.onSeeAll,
    this.seeAllText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 8,
        vertical: isMobile ? 8 : 12,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: isMobile ? 16 : 20,
                color: iconColor ?? theme.colorScheme.primary,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 12,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seeAllText ?? 'See All',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: isMobile ? 12 : 14,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class GreetingHeader extends StatelessWidget {
  final String userName;
  final String? subtitle;
  final Widget? trailing;

  const GreetingHeader({
    super.key,
    required this.userName,
    this.subtitle,
    this.trailing,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting 👋',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle case final String s) ...[
                  const SizedBox(height: 4),
                  Text(
                    s,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...[trailing].whereType<Widget>(),
        ],
      ),
    );
  }
}
