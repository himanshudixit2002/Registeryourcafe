import 'package:flutter/material.dart';

/// Shared timing for full-screen routes, shell tab switches, and modal sheets.
const Duration kAppPageTransitionDuration = Duration(milliseconds: 250);

const Curve kAppPageTransitionCurve = Curves.easeOutCubic;

/// Unified push/pop transition (fade + short horizontal slide) on every platform.
class AppFadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const AppFadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: kAppPageTransitionCurve,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.02, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// [MaterialPageRoute] with [kAppPageTransitionDuration] so timing matches the shell.
class AppMaterialPageRoute<T> extends MaterialPageRoute<T> {
  AppMaterialPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
    super.maintainState,
    super.allowSnapshotting,
    super.barrierDismissible,
  });

  @override
  Duration get transitionDuration => kAppPageTransitionDuration;

  @override
  Duration get reverseTransitionDuration => kAppPageTransitionDuration;
}
