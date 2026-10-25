import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// A wrapper widget that adds pull-to-refresh functionality
/// Optimized for mobile with haptic feedback and smooth animations
class PullToRefreshWrapper extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? indicatorColor;
  final Color? backgroundColor;
  final bool enabled;

  const PullToRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.indicatorColor,
    this.backgroundColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final theme = Theme.of(context);
    final effectiveColor = indicatorColor ?? theme.colorScheme.primary;
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.surface;

    return RefreshIndicator(
      onRefresh: () async {
        await HapticFeedback.mediumImpact();
        await onRefresh();
      },
      color: effectiveColor,
      backgroundColor: effectiveBackgroundColor,
      strokeWidth: 2.5,
      displacement: 60,
      edgeOffset: AppTheme.isMobile(context) ? 0 : 20,
      child: child,
    );
  }
}

/// A scrollable list with built-in pull-to-refresh
class RefreshableScrollView extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function() onRefresh;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const RefreshableScrollView({
    super.key,
    required this.children,
    required this.onRefresh,
    this.controller,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return PullToRefreshWrapper(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: controller,
        physics: physics ?? AppTheme.scrollPhysicsFor(context),
        shrinkWrap: shrinkWrap,
        slivers: [
          SliverPadding(
            padding: padding ?? EdgeInsets.zero,
            sliver: SliverList(delegate: SliverChildListDelegate(children)),
          ),
        ],
      ),
    );
  }
}

/// A sliver-based refreshable list for use with CustomScrollView
class RefreshableSliverList extends StatelessWidget {
  final Widget sliver;
  final Future<void> Function() onRefresh;

  const RefreshableSliverList({
    super.key,
    required this.sliver,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        await HapticFeedback.mediumImpact();
        await onRefresh();
      },
      color: cs.primary,
      backgroundColor: cs.surface,
      child: CustomScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        slivers: [sliver],
      ),
    );
  }
}
