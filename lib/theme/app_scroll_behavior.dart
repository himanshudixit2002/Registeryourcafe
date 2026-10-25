import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Elastic scroll on iOS/Android; clamping on desktop/web for predictable
/// trackpad/mouse behavior while still allowing drag on all pointers.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  /// Matches [AppTheme.kMobileBreakpoint]: narrow viewports (phones, slim web
  /// columns) get elastic scroll even on desktop/web; wide surfaces stay clamped.
  static const double _handsetShortestSideCap = 600;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    if (shortest < _handsetShortestSideCap) {
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
    }
  }
}
