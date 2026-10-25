import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Centers content and caps width on large displays (shell tabs, wide windows).
///
/// Does not add outer padding by default — [ResponsiveScaffold] and similar
/// already pad the body. Use [paddingForContext] when you need breakpoint-based
/// padding inside the constrained column.
///
/// Default width follows [AppTheme.shellContentMaxWidth]. Pass [maxWidth] to
/// override (finite value replaces the theme calculation for that instance).
class ConstrainedPageContent extends StatelessWidget {
  const ConstrainedPageContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.scrollable = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;

  /// When null, uses [AppTheme.shellContentMaxWidth] from viewport + parent constraints.
  final double? maxWidth;

  final bool scrollable;
  final EdgeInsets padding;

  static EdgeInsets paddingForContext(BuildContext context) {
    if (AppTheme.isMobile(context)) {
      return const EdgeInsets.symmetric(
        horizontal: AppTheme.kSpacingSmall,
        vertical: AppTheme.kSpacingSmall,
      );
    }
    if (AppTheme.isTablet(context)) {
      return const EdgeInsets.symmetric(
        horizontal: AppTheme.kSpacingLarge,
        vertical: AppTheme.kSpacingMedium,
      );
    }
    return const EdgeInsets.symmetric(
      horizontal: AppTheme.kSpacingLarge,
      vertical: AppTheme.kSpacingMedium,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewportW = MediaQuery.sizeOf(context).width;

    Widget buildInner(double layoutMaxWidth) {
      final effectiveMax = maxWidth != null && maxWidth!.isFinite
          ? math.min(maxWidth!, layoutMaxWidth)
          : AppTheme.shellContentMaxWidth(viewportW, layoutMaxWidth);

      final padded = padding == EdgeInsets.zero
          ? child
          : Padding(padding: padding, child: child);

      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMax),
          child: SizedBox(width: double.infinity, child: padded),
        ),
      );
    }

    final inner = LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : viewportW;
        return buildInner(w);
      },
    );

    if (scrollable) {
      return SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        child: inner,
      );
    }

    return inner;
  }
}
