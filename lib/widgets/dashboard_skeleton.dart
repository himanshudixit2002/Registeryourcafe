import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final padding = isMobile ? AppTheme.kSpacingSmall : 24.0;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero (matches [DashboardHeroHeader] glass strip)
        _SkeletonGlassPanel(
          height: isMobile ? 76 : 92,
          borderRadius: isMobile ? 18 : 22,
        ),
        SizedBox(height: isMobile ? 20 : 28),

        // Live — active sessions
        _SkeletonSectionHeader(isMobile: isMobile),
        SizedBox(height: isMobile ? 12 : 16),
        _SkeletonGlassPanel(
          height: isMobile ? 220 : 252,
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _SkeletonBox(
                    width: isMobile ? 32 : 40,
                    height: isMobile ? 32 : 40,
                    radius: 10,
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: _SkeletonBox(
                      width: double.infinity,
                      height: isMobile ? 14 : 16,
                      radius: 6,
                    ),
                  ),
                  _SkeletonBox(
                    width: isMobile ? 72 : 88,
                    height: isMobile ? 40 : 44,
                    radius: 10,
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 10 : 14),
              SizedBox(
                height: isMobile ? 120 : 132,
                child: Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                        child: _SkeletonBox(
                          width: double.infinity,
                          height: isMobile ? 120 : 132,
                          radius: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 20 : 28),

        // Kitchen
        _SkeletonSectionHeader(isMobile: isMobile),
        SizedBox(height: isMobile ? 12 : 16),
        _SkeletonGlassPanel(
          height: isMobile ? 64 : 72,
          borderRadius: 20,
          child: Row(
            children: List.generate(
              3,
              (i) => Padding(
                padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                child: _SkeletonChip(width: isMobile ? 92 : 108),
              ),
            ),
          ),
        ),
        SizedBox(height: isMobile ? 20 : 28),

        // KPI — Key metrics
        _SkeletonSectionHeader(isMobile: isMobile, wideTitle: true),
        SizedBox(height: isMobile ? 12 : 16),
        _SkeletonGlassPanel(
          height: null,
          borderRadius: 20,
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            children: List.generate(
              6,
              (i) => SizedBox(
                width: isMobile
                    ? (MediaQuery.of(context).size.width - padding * 2 - 24) / 2
                    : 160,
                child: _SkeletonBox(
                  width: double.infinity,
                  height: isMobile ? 88 : 100,
                  radius: 16,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: isMobile ? 20 : 28),

        // Chart + category (desktop row / mobile stack)
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _SkeletonGlassPanel(height: 300, borderRadius: 20),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: _SkeletonGlassPanel(height: 300, borderRadius: 20),
              ),
            ],
          )
        else ...[
          _SkeletonGlassPanel(height: 200, borderRadius: 20),
          const SizedBox(height: 16),
          _SkeletonGlassPanel(height: 200, borderRadius: 20),
        ],
        SizedBox(height: isMobile ? 20 : 28),

        // Insights: two columns + recent orders block
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _insightColumn(context, isMobile)),
              const SizedBox(width: 24),
              Expanded(child: _insightColumn(context, isMobile)),
            ],
          )
        else ...[
          _insightColumn(context, isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          _insightColumn(context, isMobile),
        ],
        SizedBox(height: isMobile ? 16 : 24),
        _SkeletonSectionHeader(isMobile: isMobile, wideTitle: true),
        SizedBox(height: isMobile ? 12 : 16),
        _SkeletonGlassPanel(
          height: null,
          borderRadius: 20,
          child: Column(
            children: List.generate(
              4,
              (i) => Padding(
                padding: EdgeInsets.only(bottom: i < 3 ? 12 : 0),
                child: _SkeletonBox(
                  width: double.infinity,
                  height: isMobile ? 52 : 56,
                  radius: 14,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: isMobile ? 24 : 32),

        // Tournaments
        _SkeletonSectionHeader(isMobile: isMobile, wideTitle: true),
        SizedBox(height: isMobile ? 12 : 16),
        _SkeletonGlassPanel(height: 180, borderRadius: 20),
        SizedBox(height: isMobile ? 24 : 32),

        // Leaderboard
        _SkeletonSectionHeader(isMobile: isMobile, wideTitle: true),
        SizedBox(height: isMobile ? 12 : 16),
        _SkeletonGlassPanel(height: 180, borderRadius: 20),
        SizedBox(height: isMobile ? 24 : 40),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportW = MediaQuery.sizeOf(context).width;
        final layoutW = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : viewportW;
        final maxW = AppTheme.shellContentMaxWidth(viewportW, layoutW);
        return SingleChildScrollView(
          physics: AppTheme.scrollPhysicsFor(context),
          padding: EdgeInsets.all(padding),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: SizedBox(width: double.infinity, child: content),
            ),
          ),
        );
      },
    );
  }

  Widget _insightColumn(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonSectionHeader(isMobile: isMobile),
        SizedBox(height: isMobile ? 12 : 16),
        _SkeletonGlassPanel(
          height: null,
          borderRadius: 20,
          child: Column(
            children: List.generate(
              4,
              (i) => Padding(
                padding: EdgeInsets.only(bottom: i < 3 ? 10 : 0),
                child: Row(
                  children: [
                    _SkeletonBox(
                      width: isMobile ? 40 : 44,
                      height: isMobile ? 40 : 44,
                      radius: 22,
                    ),
                    SizedBox(width: isMobile ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBox(
                            width: double.infinity,
                            height: 12,
                            radius: 4,
                          ),
                          const SizedBox(height: 6),
                          _SkeletonBox(
                            width: isMobile ? 100 : 120,
                            height: 10,
                            radius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Eyebrow + title + subtitle placeholders (matches [DashboardSection] header).
class _SkeletonSectionHeader extends StatelessWidget {
  const _SkeletonSectionHeader({
    required this.isMobile,
    this.wideTitle = false,
  });

  final bool isMobile;
  final bool wideTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBox(
          width: isMobile ? 48 : 56,
          height: isMobile ? 12 : 13,
          radius: 4,
        ),
        SizedBox(height: isMobile ? 4 : 6),
        _SkeletonBox(
          width: wideTitle ? (isMobile ? 160 : 220) : (isMobile ? 140 : 180),
          height: isMobile ? 20 : 22,
          radius: 6,
        ),
        SizedBox(height: isMobile ? 4 : 6),
        _SkeletonBox(
          width: isMobile ? 200 : 280,
          height: isMobile ? 12 : 14,
          radius: 4,
        ),
      ],
    );
  }
}

/// Rounded “glass” panel placeholder (gradient shimmer).
class _SkeletonGlassPanel extends StatefulWidget {
  const _SkeletonGlassPanel({
    required this.borderRadius,
    this.height,
    this.child,
  });

  final double borderRadius;
  final double? height;
  final Widget? child;

  @override
  State<_SkeletonGlassPanel> createState() => _SkeletonGlassPanelState();
}

class _SkeletonGlassPanelState extends State<_SkeletonGlassPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          height: widget.height,
          width: double.infinity,
          padding: child != null
              ? EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint
                      ? AppTheme.kSpacingMedium
                      : 22,
                )
              : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                cs.surfaceContainerHigh,
                cs.surfaceContainerLow,
                cs.surfaceContainerHigh,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.28),
            ),
          ),
          child: child,
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHigh;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHigh;
    return Container(
      width: width,
      height: 32,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
