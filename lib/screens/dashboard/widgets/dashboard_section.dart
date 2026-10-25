import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/glass_panel.dart';

/// Dashboard block: optional eyebrow + title row, then child inside [GlassPanel].
class DashboardSection extends StatelessWidget {
  const DashboardSection({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.blur = GlassBlur.auto,
    this.borderRadius = 20,
    this.panelPadding,
    this.margin,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final GlassBlur blur;
  final double borderRadius;
  final EdgeInsetsGeometry? panelPadding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                    ],
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: isMobile ? 4 : 6),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          GlassPanel(
            blur: blur,
            borderRadius: borderRadius,
            padding:
                panelPadding ??
                EdgeInsets.all(isMobile ? AppTheme.kSpacingMedium : 22),
            child: child,
          ),
        ],
      ),
    );
  }
}
