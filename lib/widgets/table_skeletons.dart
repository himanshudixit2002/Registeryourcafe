import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'skeleton_loader.dart';

class TableCardSkeleton extends StatelessWidget {
  const TableCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.kSpacingMedium),
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonLoader(width: 40, height: 40, isCircle: true),
              SizedBox(width: AppTheme.kSpacingSmall),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: 120, height: 24),
                    SizedBox(height: AppTheme.kSpacingXSmall),
                    SkeletonLoader(width: 80, height: 16),
                  ],
                ),
              ),
              SkeletonLoader(width: 80, height: 32),
            ],
          ),
          SizedBox(height: AppTheme.kSpacingMedium),
          Row(
            children: [
              Expanded(child: SkeletonLoader(height: 16)),
              SizedBox(width: AppTheme.kSpacingMedium),
              SkeletonLoader(width: 60, height: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class TableDetailSkeleton extends StatelessWidget {
  const TableDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 120, height: 24),
                SizedBox(height: AppTheme.kSpacingMedium),
                SkeletonLoader(),
                SizedBox(height: AppTheme.kSpacingSmall),
                SkeletonLoader(width: 180),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.kSpacingMedium),
          Container(
            padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 150, height: 24),
                SizedBox(height: AppTheme.kSpacingMedium),
                SkeletonLoader(),
                SizedBox(height: AppTheme.kSpacingSmall),
                SkeletonLoader(width: 140),
                SizedBox(height: AppTheme.kSpacingSmall),
                SkeletonLoader(width: 160),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
