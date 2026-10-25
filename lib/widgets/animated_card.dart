import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showHoverEffect;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? elevation;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.isSelected = false,
    this.showHoverEffect = true,
    this.padding,
    this.color,
    this.elevation,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (!mounted) return;
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!mounted) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);
    final defaultElevation = widget.elevation ?? 0.0;
    final hoverElevation = defaultElevation + 4.0;

    final isActive = _isHovered || _isPressed || widget.isSelected;
    final baseColor =
        widget.color ??
        theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.55);

    // Calculate scale based on state
    final double scale = _isPressed
        ? 0.96
        : (widget.showHoverEffect && _isHovered ? 1.02 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: _isPressed
                  ? Color.lerp(
                      baseColor,
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                      0.3,
                    )
                  : baseColor,
              borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
              boxShadow: [
                BoxShadow(
                  color: _isPressed
                      ? theme.colorScheme.primary.withValues(alpha: 0.25)
                      : theme.colorScheme.shadow.withValues(alpha: 0.1),
                  blurRadius: widget.showHoverEffect && isActive
                      ? hoverElevation + (_isPressed ? 4 : 0)
                      : defaultElevation,
                  offset: Offset(0, _isPressed ? 1 : 2),
                  spreadRadius: _isPressed ? 1 : -1,
                ),
                // Glow effect on press (mobile-friendly)
                if (_isPressed && isMobile)
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
              ],
              border: widget.isSelected || _isPressed
                  ? Border.all(
                      color: theme.colorScheme.primary.withValues(
                        alpha: _isPressed ? 0.6 : 1.0,
                      ),
                      width: _isPressed ? 2.5 : 2,
                    )
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding:
                    widget.padding ??
                    const EdgeInsets.all(AppTheme.kSpacingMedium),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
