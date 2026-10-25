import 'package:flutter/material.dart';

/// A beautiful shimmer effect for skeleton loading states
/// Provides smooth animations that feel native and polished
class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets? margin;
  final bool isCircle;

  const ShimmerSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
    this.margin,
    this.isCircle = false,
  });

  /// Creates a card-shaped skeleton
  factory ShimmerSkeleton.card({
    double? width,
    double height = 120,
    EdgeInsets? margin,
  }) {
    return ShimmerSkeleton(
      width: width ?? double.infinity,
      height: height,
      borderRadius: 14,
      margin: margin,
    );
  }

  /// Creates a text line skeleton
  factory ShimmerSkeleton.text({
    double? width,
    double height = 14,
    EdgeInsets? margin,
  }) {
    return ShimmerSkeleton(
      width: width ?? 100,
      height: height,
      borderRadius: 4,
      margin: margin,
    );
  }

  /// Creates a circular avatar skeleton
  factory ShimmerSkeleton.avatar({double size = 48, EdgeInsets? margin}) {
    return ShimmerSkeleton(
      width: size,
      height: size,
      isCircle: true,
      margin: margin,
    );
  }

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: widget.isCircle
                ? null
                : BorderRadius.circular(widget.borderRadius),
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                cs.surfaceContainerHighest,
                cs.surfaceContainerHigh,
                cs.surfaceContainerLow,
                cs.surfaceContainerHigh,
                cs.surfaceContainerHighest,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A pre-built skeleton for list items with avatar and text
class ShimmerListTile extends StatelessWidget {
  final bool showTrailing;
  final int index;

  const ShimmerListTile({super.key, this.showTrailing = true, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ShimmerSkeleton.avatar(size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton.text(width: 140, height: 16),
                  const SizedBox(height: 8),
                  ShimmerSkeleton.text(width: 100, height: 12),
                ],
              ),
            ),
            if (showTrailing) ...[
              const SizedBox(width: 12),
              ShimmerSkeleton.text(width: 60, height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

/// A pre-built skeleton for stat cards grid
class ShimmerStatGrid extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;

  const ShimmerStatGrid({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + (index * 100)),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.9 + (0.1 * value), child: child),
        ),
        child: const ShimmerSkeleton(height: 100, borderRadius: 14),
      ),
    );
  }
}

/// A pre-built skeleton for mobile customer/item cards
class ShimmerMobileCard extends StatelessWidget {
  final int index;

  const ShimmerMobileCard({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 15 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ShimmerSkeleton.avatar(size: 50),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton.text(width: 130, height: 16),
                  const SizedBox(height: 8),
                  ShimmerSkeleton.text(width: 180, height: 12),
                  const SizedBox(height: 6),
                  ShimmerSkeleton.text(width: 90, height: 10),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const ShimmerSkeleton(width: 60, height: 24, borderRadius: 8),
                const SizedBox(height: 6),
                ShimmerSkeleton.text(width: 50, height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A pre-built skeleton for chart placeholders
class ShimmerChart extends StatelessWidget {
  final double height;

  const ShimmerChart({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerSkeleton.text(width: 140, height: 18),
            const SizedBox(height: 8),
            ShimmerSkeleton.text(width: 100, height: 12),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                (i) => ShimmerSkeleton(
                  width: 24,
                  height: 40 + (i * 12).toDouble(),
                  borderRadius: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
