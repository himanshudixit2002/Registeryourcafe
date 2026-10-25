import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/permission_id.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/permissions_provider.dart';
import '../widgets/leaderboard_card.dart';
import '../navigation/shell_route_titles.dart';
import '../providers/shell_route_title_provider.dart';
import '../screens/leaderboard/leaderboard_competition_screen.dart';
import '../theme/app_theme.dart';
import 'section_async_error.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

class DashboardLeaderboardWidget extends ConsumerWidget {
  const DashboardLeaderboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final topPerformersAsync = ref.watch(topPerformersProvider);
    final canOpenLeaderboard =
        ref.watchResolvedPermissions().can(PermissionIds.navLeaderboard);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
        boxShadow: AppTheme.cardShadowFor(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.leaderboard,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Top Performers',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: canOpenLeaderboard
                    ? () {
                        Navigator.of(context).push(
                          AppMaterialPageRoute<void>(
                            builder: (_) =>
                                const LeaderboardCompetitionScreen(),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          topPerformersAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.leaderboard,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No leaderboard data yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start awarding points to customers',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: AppTheme.subtleDividerColor(Theme.of(context)),
                ),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return CompactLeaderboardCard(
                    entry: entry,
                    onTap: canOpenLeaderboard
                        ? () {
                            navigateToShellTitleIfVisible(
                              ref,
                              ShellRouteTitles.leaderboard,
                            );
                          }
                        : null,
                  );
                },
              );
            },
            loading: () => Column(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            error: (error, stack) => SectionAsyncError(
              error: error,
              title: 'Leaderboard unavailable',
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardLeaderboardStatsWidget extends ConsumerWidget {
  const DashboardLeaderboardStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final statsAsync = ref.watch(leaderboardStatsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
        boxShadow: AppTheme.cardShadowFor(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Competition Stats',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          statsAsync.when(
            data: (stats) {
              return Column(
                children: [
                  _buildStatRow(
                    context: context,
                    icon: Icons.people,
                    label: 'Active Players',
                    value: stats.totalPlayers.toString(),
                    color: cs.primary,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    context: context,
                    icon: Icons.sports_esports,
                    label: 'Total Matches',
                    value: stats.totalMatches.toString(),
                    color: sem.warning,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Match Breakdown',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMatchTypeStat(
                                context: context,
                                label: 'PTL Sessions',
                                value: stats.totalPTLMatches.toString(),
                                points: stats.ptlPointsAwarded,
                                color: sem.success,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMatchTypeStat(
                                context: context,
                                label: 'Tournaments',
                                value: stats.totalTournamentMatches.toString(),
                                points: stats.tournamentPointsAwarded,
                                color: cs.tertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildMatchTypeStat(
                          context: context,
                          label: 'Manual Awards',
                          value: stats.totalManualMatches.toString(),
                          points: stats.manualPointsAwarded,
                          color: sem.info,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    context: context,
                    icon: Icons.stars,
                    label: 'Total Points Awarded',
                    value: stats.totalPointsAwarded.toStringAsFixed(0),
                    color: sem.warning,
                  ),
                ],
              );
            },
            loading: () => Column(
              children: List.generate(
                4,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 14,
                              width: 100,
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 20,
                              width: 60,
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            error: (error, stack) =>
                SectionAsyncError(error: error, title: 'Stats unavailable'),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTypeStat({
    required BuildContext context,
    required String label,
    required String value,
    required double points,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '${points.toStringAsFixed(0)} pts',
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
