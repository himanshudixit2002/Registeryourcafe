import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// A mobile-optimized button with proper touch target sizes
/// Provides haptic feedback and loading states
class MobileButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isDestructive;
  final bool isOutlined;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? height;

  const MobileButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isDestructive = false,
    this.isOutlined = false,
    this.isFullWidth = false,
    this.backgroundColor,
    this.foregroundColor,
    this.height,
  });

  @override
  State<MobileButton> createState() => _MobileButtonState();
}

class _MobileButtonState extends State<MobileButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _handleTap() {
    if (widget.onPressed != null && !widget.isLoading) {
      HapticFeedback.lightImpact();
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);

    // Minimum touch target height for mobile (48dp ideal)
    final minHeight = widget.height ?? (isMobile ? 52.0 : 48.0);

    final effectiveBackgroundColor =
        widget.backgroundColor ??
        (widget.isDestructive
            ? theme.colorScheme.error
            : theme.colorScheme.primary);

    final effectiveForegroundColor =
        widget.foregroundColor ??
        (widget.isOutlined
            ? effectiveBackgroundColor
            : (effectiveBackgroundColor == theme.colorScheme.error
                  ? theme.colorScheme.onError
                  : theme.colorScheme.onPrimary));

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            color: widget.isOutlined
                ? Colors.transparent
                : (widget.onPressed == null || widget.isLoading
                      ? effectiveBackgroundColor.withValues(alpha: 0.5)
                      : effectiveBackgroundColor),
            borderRadius: BorderRadius.circular(
              AppTheme.kBorderRadiusMedium + 2,
            ),
            border: widget.isOutlined
                ? Border.all(
                    color: widget.onPressed == null || widget.isLoading
                        ? effectiveBackgroundColor.withValues(alpha: 0.5)
                        : effectiveBackgroundColor,
                    width: 2,
                  )
                : null,
            boxShadow:
                !widget.isOutlined &&
                    widget.onPressed != null &&
                    !widget.isLoading
                ? [
                    BoxShadow(
                      color: effectiveBackgroundColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 24,
            vertical: isMobile ? 14 : 12,
          ),
          child: Row(
            mainAxisSize: widget.isFullWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      effectiveForegroundColor,
                    ),
                  ),
                ),
              ] else ...[
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: isMobile ? 22 : 20,
                    color: effectiveForegroundColor,
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 15,
                    fontWeight: FontWeight.w600,
                    color: effectiveForegroundColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A smaller action button for inline use
class MobileActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  const MobileActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    final Widget button = Material(
      color: effectiveColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed != null
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.5,
            color: onPressed != null
                ? effectiveColor
                : effectiveColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// A floating action button optimized for mobile
class MobileFAB extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool extended;
  final Color? backgroundColor;

  /// Unique per screen when multiple FABs stay in the tree (e.g. workspace tabs).
  final Object? heroTag;

  const MobileFAB({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.extended = true,
    this.backgroundColor,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);
    final effectiveColor = backgroundColor ?? theme.colorScheme.primary;

    final resolvedHero = heroTag ?? 'mobile-fab-${icon.codePoint}-$label';

    if (!extended) {
      return FloatingActionButton(
        heroTag: resolvedHero,
        onPressed: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        backgroundColor: effectiveColor,
        elevation: 4,
        child: Icon(icon, color: theme.colorScheme.onPrimary),
      );
    }

    return FloatingActionButton.extended(
      heroTag: resolvedHero,
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      backgroundColor: effectiveColor,
      elevation: 4,
      icon: Icon(
        icon,
        color: theme.colorScheme.onPrimary,
        size: isMobile ? 22 : 20,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 15 : 14,
        ),
      ),
    );
  }
}
