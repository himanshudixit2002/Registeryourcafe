import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/permission_id.dart';
import '../../models/game_category_catalog.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../theme/app_theme.dart';
import '../../theme/sales_palette.dart';
import '../../widgets/permission_denied_scaffold.dart';

class LeaderboardCompetitionScreen extends ConsumerStatefulWidget {
  const LeaderboardCompetitionScreen({super.key});

  @override
  ConsumerState<LeaderboardCompetitionScreen> createState() =>
      _LeaderboardCompetitionScreenState();
}

class _LeaderboardCompetitionScreenState
    extends ConsumerState<LeaderboardCompetitionScreen>
    with SingleTickerProviderStateMixin {
  String _categoryKey = GameCategoryCatalog.allKey;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canOpen = ref
        .watchResolvedPermissions()
        .can(PermissionIds.navLeaderboard);
    if (!canOpen) {
      return const PermissionDeniedScaffold(
        title: 'Leaderboard',
        message: 'You do not have access to the leaderboard.',
      );
    }

    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final tabKeys = ref.watch(visibleLeaderboardCategoryKeysProvider);
    if (!tabKeys.contains(_categoryKey)) {
      final next = tabKeys.isNotEmpty
          ? tabKeys.first
          : GameCategoryCatalog.allKey;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categoryKey != next) {
          setState(() => _categoryKey = next);
        }
      });
    }

    final leaderboardAsync = _categoryKey == GameCategoryCatalog.allKey
        ? ref.watch(leaderboardProvider)
        : ref.watch(categoryLeaderboardProvider(_categoryKey));

    return Scaffold(
      body: CustomScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        slivers: [
          // Modern SliverAppBar with gradient
          SliverAppBar(
            expandedHeight: isMobile ? 160 : 180,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 32,
                      vertical: isMobile ? 50 : 60,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onPrimary.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.emoji_events_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Top 10 Players',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: isMobile ? 22 : 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Compete for the leaderboard crown',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary
                                          .withValues(alpha: 0.85),
                                      fontSize: isMobile ? 13 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Category Tabs
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _buildCategoryTabs(context, isMobile),
            ),
          ),

          // Leaderboard content
          leaderboardAsync.when(
            data: (entries) {
              final top = entries.take(10).toList();
              if (top.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    icon: Icons.leaderboard_outlined,
                    message: 'No players yet',
                    details: 'Players will appear after matches',
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = top[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + (index * 80)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildLeaderboardItem(
                          context,
                          entry,
                          index,
                          isMobile,
                        ),
                      ),
                    );
                  }, childCount: top.length),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: $e'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tabKeys = ref.watch(visibleLeaderboardCategoryKeysProvider);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 12 : 16,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: AppTheme.scrollPhysicsFor(context),
        child: Row(
          children: tabKeys.map((key) {
            final isSelected = _categoryKey == key;
            final accent = GameCategoryCatalog.categoryAccent(key, cs);

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _categoryKey = key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 18,
                    vertical: isMobile ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primaryContainer : cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? accent
                          : cs.outline.withValues(alpha: 0.35),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.22),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        GameCategoryCatalog.iconFor(key),
                        size: isMobile ? 16 : 18,
                        color: isSelected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        GameCategoryCatalog.displayName(key),
                        style: TextStyle(
                          color: isSelected
                              ? cs.onPrimaryContainer
                              : cs.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: isMobile ? 12 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(
    BuildContext context,
    LeaderboardEntry entry,
    int index,
    bool isMobile,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isTopThree = index < 3;

    Color? rankColor;
    IconData? rankIcon;

    if (index == 0) {
      rankColor = const Color(0xFFFFB300);
      rankIcon = Icons.looks_one_rounded;
    } else if (index == 1) {
      rankColor = cs.onSurfaceVariant.withValues(alpha: 0.45);
      rankIcon = Icons.looks_two_rounded;
    } else if (index == 2) {
      rankColor = const Color(0xFFCD7F32);
      rankIcon = Icons.looks_3_rounded;
    }

    return AppCard(
      borderColor: isTopThree ? rankColor?.withValues(alpha: 0.3) : null,
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      child: Row(
        children: [
          // Rank
          if (isTopThree)
            Container(
              width: isMobile ? 40 : 48,
              height: isMobile ? 40 : 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [rankColor!, rankColor.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                rankIcon,
                color: SalesPalette.onChartSlice(context, rankColor),
                size: isMobile ? 24 : 28,
              ),
            )
          else
            Container(
              width: isMobile ? 40 : 48,
              height: isMobile ? 40 : 48,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 14),
          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.customer.name,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 12, color: cs.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.wins} wins',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: cs.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.cancel, size: 12, color: cs.error),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.losses} losses',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: cs.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Points
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 14,
              vertical: isMobile ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars_rounded,
                  size: isMobile ? 14 : 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${entry.points}',
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 17,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
