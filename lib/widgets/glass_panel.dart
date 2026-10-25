import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How [GlassPanel] resolves backdrop blur from [LiquidGlassTheme].
enum GlassBlur {
  /// [LiquidGlassTheme.surfaceBlurSigma] (0 by default — fast).
  auto,

  /// No backdrop blur (frost gradient only).
  none,

  /// [LiquidGlassTheme.modalBlurSigma] — use once per sheet/dialog shell.
  modal,
}

/// Frosted “liquid glass” surface: optional backdrop blur + translucent gradient.
///
/// Pairs with [AppTheme.shellBackdropGradient] behind transparent scaffolds.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = AppTheme.kBorderRadiusLarge,
    this.borderRadiusGeometry,
    this.padding,
    this.margin,
    this.blur = GlassBlur.auto,
    this.blurSigma,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final double borderRadius;
  final BorderRadius? borderRadiusGeometry;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final GlassBlur blur;
  final double? blurSigma;
  final VoidCallback? onTap;
  final Color? borderColor;

  double _resolvedSigma(LiquidGlassTheme glass) {
    if (blurSigma != null) return blurSigma!;
    switch (blur) {
      case GlassBlur.none:
        return 0;
      case GlassBlur.auto:
        return glass.surfaceBlurSigma;
      case GlassBlur.modal:
        return glass.modalBlurSigma;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = LiquidGlassTheme.of(context);
    final cs = theme.colorScheme;
    final radius = borderRadiusGeometry ?? BorderRadius.circular(borderRadius);
    final sigma = _resolvedSigma(glass);
    final outline =
        borderColor ?? cs.outline.withValues(alpha: glass.outlineAlpha);

    final Widget core = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: outline),
        boxShadow: glass.panelShadows(cs, theme.brightness),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: glass.fillGradient(cs, theme.brightness),
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );

    Widget blurred = sigma > 0
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: core,
            ),
          )
        : core;

    if (margin != null) {
      blurred = Padding(padding: margin!, child: blurred);
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: radius, child: blurred),
      );
    }

    return blurred;
  }
}

/// Default scroll-friendly surface: same frost as [GlassPanel], [GlassBlur.auto].
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.borderRadius = AppTheme.kBorderRadiusLarge,
    this.borderRadiusGeometry,
    this.padding,
    this.margin,
    this.blur = GlassBlur.auto,
    this.blurSigma,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final double borderRadius;
  final BorderRadius? borderRadiusGeometry;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final GlassBlur blur;
  final double? blurSigma;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: borderRadius,
      borderRadiusGeometry: borderRadiusGeometry,
      padding: padding,
      margin: margin,
      blur: blur,
      blurSigma: blurSigma,
      onTap: onTap,
      borderColor: borderColor,
      child: child,
    );
  }
}
