import 'package:flutter/material.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

import 'glass_panel.dart';

export 'glass_panel.dart' show GlassBlur, GlassPanel;

/// Drag handle aligned with other modal sheets.
class GlassModalSheetDragHandle extends StatelessWidget {
  const GlassModalSheetDragHandle({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        margin: margin ?? const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Modal frosted shell for [showModalBottomSheet].
/// Use with `backgroundColor: Colors.transparent` (and often
/// `isScrollControlled: true` when the keyboard may open).
class GlassModalSheetChrome extends StatelessWidget {
  const GlassModalSheetChrome({
    super.key,
    required this.child,
    this.showHandle = true,
    this.topRadius = 24,
  });

  final Widget child;
  final bool showHandle;
  final double topRadius;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: GlassBlur.modal,
      borderRadiusGeometry: BorderRadius.vertical(
        top: Radius.circular(topRadius),
      ),
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [if (showHandle) const GlassModalSheetDragHandle(), child],
        ),
      ),
    );
  }
}

/// Opens a bottom sheet with keyboard-aware padding and glass chrome.
Future<T?> showGlassModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool isScrollControlled = true,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showHandle = true,
  double topRadius = 24,
}) {
  return showModalBottomSheet<T>(
    context: context,
    sheetAnimationStyle: const AnimationStyle(
      duration: kAppPageTransitionDuration,
      reverseDuration: kAppPageTransitionDuration,
    ),
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: GlassModalSheetChrome(
        showHandle: showHandle,
        topRadius: topRadius,
        child: builder(ctx),
      ),
    ),
  );
}
