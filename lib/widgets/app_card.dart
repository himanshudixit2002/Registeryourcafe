import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double? borderRadius;
  final Color? borderColor;
  final double elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.onTap,
    this.borderRadius,
    this.borderColor,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final radius = borderRadius ?? AppTheme.kBorderRadiusLarge;
    final defaultPad =
        padding ??
        EdgeInsets.all(
          isMobile ? AppTheme.kSpacingMedium : AppTheme.kSpacingLarge,
        );

    if (backgroundColor != null || elevation > 0) {
      return Container(
        margin:
            margin ??
            EdgeInsets.symmetric(
              horizontal: isMobile ? 0 : AppTheme.kSpacingXSmall,
              vertical: isMobile ? AppTheme.kSpacingXSmall : 6,
            ),
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(radius),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1.5)
              : null,
          boxShadow: AppTheme.cardShadowFor(theme.brightness),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: defaultPad, child: child),
          ),
        ),
      );
    }

    return GlassPanel(
      margin:
          margin ??
          EdgeInsets.symmetric(
            horizontal: isMobile ? 0 : AppTheme.kSpacingXSmall,
            vertical: isMobile ? AppTheme.kSpacingXSmall : 6,
          ),
      borderRadius: radius,
      padding: defaultPad,
      onTap: onTap,
      borderColor: borderColor,
      child: child,
    );
  }
}

class ListItemCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? highlightColor;
  final EdgeInsetsGeometry? margin;

  const ListItemCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.highlightColor,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return AppCard(
      margin: margin,
      borderColor: highlightColor?.withValues(alpha: 0.3),
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: isMobile ? 12 : 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: isMobile ? 8 : 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class InfoItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final Color? color;
  final bool compact;

  const InfoItem({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final effectiveColor = color ?? theme.colorScheme.primary;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 4),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: isMobile ? 20 : 24, color: effectiveColor),
          ),
          SizedBox(height: isMobile ? 6 : 8),
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: effectiveColor,
          ),
        ),
        SizedBox(height: isMobile ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool pulsing;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ] else if (pulsing) ...[
            PulsingDot(color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool showGlow;

  const PulsingDot({
    super.key,
    required this.color,
    this.size = 8,
    this.showGlow = false,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            boxShadow: widget.showGlow
                ? [
                    BoxShadow(
                      color: widget.color.withValues(
                        alpha: 0.5 * _animation.value,
                      ),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

class AppFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final bool compact;

  const AppFilterChip({
    super.key,
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final effectiveColor = selectedColor ?? cs.primary;

    // Opaque base so labels stay legible on transparent scaffolds / mesh backdrops.
    final Color baseFill = cs.surfaceContainerHighest;
    final Color fillColor = isSelected
        ? Color.alphaBlend(
            effectiveColor.withValues(alpha: selectedColor == null ? 0.30 : 0.34),
            baseFill,
          )
        : baseFill;

    // Minimum touch target size for mobile (44dp recommended, 48dp ideal)
    final minHeight = isMobile ? 36.0 : 32.0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: fillColor,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : (isMobile ? 14 : 16),
                vertical: compact ? 6 : (isMobile ? 8 : 8),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? effectiveColor.withValues(alpha: 0.62)
                      : cs.outline.withValues(alpha: 0.38),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: compact ? 14 : (isMobile ? 16 : 16),
                      color: isSelected
                          ? effectiveColor
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 12 : (isMobile ? 13 : 13),
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected
                          ? effectiveColor
                          : cs.onSurface,
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
}

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? contentPadding;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return GlassPanel(
      borderRadius: AppTheme.kBorderRadiusLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                    size: isMobile ? 16 : 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                ),
                ...[trailing].whereType<Widget>(),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          // Content
          Padding(
            padding: contentPadding ?? EdgeInsets.all(isMobile ? 12 : 16),
            child: child,
          ),
        ],
      ),
    );
  }
}
