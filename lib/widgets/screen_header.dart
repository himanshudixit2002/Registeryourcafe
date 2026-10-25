import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared gradient header used at the top of workspace screens (Tables, Tournaments, etc.).
///
/// Replaces per-screen `_buildModernHeader` / `_buildHeader` patterns with a
/// single reusable component that responds to [AppTheme] breakpoints.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.actions = const [],
    this.includeSafeArea = true,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final List<Widget> actions;
  final bool includeSafeArea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);

    final content = Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(isMobile ? 6 : 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
            ),
            child: Icon(
              icon,
              size: isMobile ? 18 : 28,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          SizedBox(width: isMobile ? 10 : 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final action in actions) ...[
          const SizedBox(width: 6),
          action,
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(isMobile ? 14 : 20),
          bottomRight: Radius.circular(isMobile ? 14 : 20),
        ),
      ),
      child: includeSafeArea
          ? SafeArea(bottom: false, child: content)
          : content,
    );
  }
}

/// Icon button styled for use inside [ScreenHeader].
class ScreenHeaderAction extends StatelessWidget {
  const ScreenHeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);

    Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 6 : 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
        ),
        child: Icon(
          icon,
          size: isMobile ? 16 : 20,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
