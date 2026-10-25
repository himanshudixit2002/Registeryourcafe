import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmptyStateWidget extends StatefulWidget {
  final IconData icon;
  final String message;
  final String? details;
  final Widget? actionButton;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.message,
    this.details,
    this.actionButton,
    this.iconColor,
  });

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);

    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 24 : AppTheme.kSpacingLarge),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated icon with background
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 20 : 28),
                    decoration: BoxDecoration(
                      color: (widget.iconColor ?? theme.colorScheme.primary)
                          .withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      size: isMobile ? 48 : 64,
                      color: (widget.iconColor ?? theme.colorScheme.primary)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 20 : AppTheme.kSpacingLarge),

                // Message
                Text(
                  widget.message,
                  style:
                      (isMobile
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleLarge)
                          ?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                  textAlign: TextAlign.center,
                ),

                // Details
                if (widget.details != null && widget.details!.isNotEmpty) ...[
                  SizedBox(height: isMobile ? 8 : AppTheme.kSpacingSmall),
                  Text(
                    widget.details!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: isMobile ? 13 : 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Action button
                if (widget.actionButton != null) ...[
                  SizedBox(height: isMobile ? 20 : AppTheme.kSpacingLarge),
                  widget.actionButton!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorStateWidget extends StatefulWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.details,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  State<ErrorStateWidget> createState() => _ErrorStateWidgetState();
}

class _ErrorStateWidgetState extends State<ErrorStateWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile = AppTheme.isMobile(context);

    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 24 : AppTheme.kSpacingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animated error icon
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      (1 - _shakeAnimation.value) *
                          10 *
                          _shake(_controller.value),
                      0,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        size: isMobile ? 40 : 56,
                        color: cs.error,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: isMobile ? 20 : AppTheme.kSpacingLarge),

              // Error message
              Text(
                widget.message,
                style:
                    (isMobile
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                textAlign: TextAlign.center,
              ),

              // Details
              if (widget.details != null && widget.details!.isNotEmpty) ...[
                SizedBox(height: isMobile ? 8 : AppTheme.kSpacingSmall),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.details!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontSize: isMobile ? 11 : 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Retry button
              if (widget.onRetry != null) ...[
                SizedBox(height: isMobile ? 20 : AppTheme.kSpacingLarge),
                ElevatedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 28,
                      vertical: isMobile ? 12 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  double _shake(double t) {
    return (t < 0.5) ? (t * 4 - 1).abs() - 1 : (t * 4 - 3).abs() - 1;
  }
}
