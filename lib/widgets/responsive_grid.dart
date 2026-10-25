import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double? childAspectRatio;
  final double? maxCrossAxisExtent;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = AppTheme.kSpacingMedium,
    this.runSpacing = AppTheme.kSpacingMedium,
    this.childAspectRatio,
    this.maxCrossAxisExtent,
    this.padding,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = AppTheme.isDesktop(context);
        final defaultMaxExtent =
            maxCrossAxisExtent ?? (isDesktop ? 400.0 : 300.0);

        int columnCount = (width / defaultMaxExtent).floor();
        final isTablet = AppTheme.isTablet(context);
        final maxColumns = isDesktop ? 4 : (isTablet ? 3 : (width > 500 ? 3 : 2));
        columnCount = columnCount.clamp(1, maxColumns);

        return GridView.builder(
          padding:
              padding ??
              EdgeInsets.all(
                isDesktop ? AppTheme.kSpacingLarge : AppTheme.kSpacingMedium,
              ),
          shrinkWrap: !scrollable,
          physics: scrollable
              ? AppTheme.scrollPhysicsFor(context)
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            childAspectRatio: childAspectRatio ?? (isDesktop ? 1.2 : 1.0),
            crossAxisSpacing: spacing,
            mainAxisSpacing: runSpacing,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

class ResponsiveGridItem extends StatelessWidget {
  final Widget child;
  final int columnSpan;
  final int rowSpan;

  const ResponsiveGridItem({
    super.key,
    required this.child,
    this.columnSpan = 1,
    this.rowSpan = 1,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
