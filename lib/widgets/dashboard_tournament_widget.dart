import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/permission_id.dart';
import '../providers/permissions_provider.dart';
import '../providers/tournament_provider.dart';
import '../models/tournament.dart';
import '../navigation/shell_route_titles.dart';
import '../providers/shell_route_title_provider.dart';
import '../screens/tournament/tournament_detail_screen.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';
import 'section_async_error.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

class DashboardTournamentWidget extends ConsumerWidget {
  const DashboardTournamentWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canOpenTournaments = ref
        .watchResolvedPermissions()
        .can(PermissionIds.navTournaments);
    final activeTournamentsAsync = ref.watch(activeTournamentsProvider);
    final upcomingTournamentsAsync = ref.watch(upcomingTournamentsProvider);

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
                    Icons.emoji_events,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tournaments',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: canOpenTournaments
                    ? () {
                        navigateToShellTitleIfVisible(
                          ref,
                          ShellRouteTitles.tournaments,
                        );
                      }
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          activeTournamentsAsync.when(
            data: (activeTournaments) {
              if (activeTournaments.isEmpty) {
                return upcomingTournamentsAsync.when(
                  data: (upcomingTournaments) {
                    if (upcomingTournaments.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upcoming Tournaments',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...upcomingTournaments
                            .take(3)
                            .map(
                              (t) => _TournamentCard(
                                tournament: t,
                                isActive: false,
                                canOpenDetail: canOpenTournaments,
                              ),
                            ),
                      ],
                    );
                  },
                  loading: () => Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Now',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppSemanticColors.of(context).success,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...activeTournaments
                      .take(3)
                      .map(
                        (t) => _TournamentCard(
                          tournament: t,
                          isActive: true,
                          canOpenDetail: canOpenTournaments,
                        ),
                      ),
                ],
              );
            },
            loading: () => Column(
              children: List.generate(
                2,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    height: 80,
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
              title: 'Tournaments unavailable',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No active tournaments',
              style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new tournament to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentCard extends ConsumerWidget {
  final Tournament tournament;
  final bool isActive;
  final bool canOpenDetail;

  const _TournamentCard({
    required this.tournament,
    required this.isActive,
    required this.canOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);

    return AppSurface(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 12,
      borderColor: isActive
          ? sem.success.withValues(alpha: 0.55)
          : theme.colorScheme.outline.withValues(alpha: 0.25),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canOpenDetail
              ? () {
                  Navigator.of(context).push(
                    AppMaterialPageRoute<void>(
                      builder: (_) =>
                          TournamentDetailScreen(tournamentId: tournament.id),
                    ),
                  );
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _gameTypeColor(
                      context,
                      tournament.gameType,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getGameTypeIcon(tournament.gameType),
                    color: _gameTypeColor(context, tournament.gameType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${tournament.currentParticipantCount}/${tournament.maxParticipantsDisplay}',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (isActive) ...[
                            Icon(
                              Icons.play_circle_outline,
                              size: 14,
                              color: sem.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Round ${tournament.currentRound}/${tournament.totalRounds}',
                              style: TextStyle(
                                color: sem.success,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d').format(tournament.startDate),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(context, tournament.status).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tournament.status.displayName,
                    style: TextStyle(
                      color: _statusColor(context, tournament.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getGameTypeIcon(TournamentGameType type) {
    switch (type) {
      case TournamentGameType.snooker:
        return Icons.sports_baseball;
      case TournamentGameType.pool:
        return Icons.pool;
      case TournamentGameType.carrom:
        return Icons.games;
      case TournamentGameType.darts:
        return Icons.adjust;
      case TournamentGameType.ps5:
        return Icons.sports_esports;
      case TournamentGameType.mixed:
        return Icons.sports;
    }
  }

  Color _gameTypeColor(BuildContext context, TournamentGameType type) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (type) {
      case TournamentGameType.snooker:
        return sem.success;
      case TournamentGameType.pool:
        return cs.primary;
      case TournamentGameType.carrom:
        return cs.tertiary;
      case TournamentGameType.darts:
        return cs.error;
      case TournamentGameType.ps5:
        return cs.secondary;
      case TournamentGameType.mixed:
        return sem.info;
    }
  }

  Color _statusColor(BuildContext context, TournamentStatus status) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (status) {
      case TournamentStatus.draft:
        return cs.outline;
      case TournamentStatus.registration:
        return cs.primary;
      case TournamentStatus.inProgress:
        return sem.success;
      case TournamentStatus.completed:
        return cs.tertiary;
      case TournamentStatus.cancelled:
        return cs.error;
    }
  }
}

class DashboardTournamentStatsWidget extends ConsumerWidget {
  const DashboardTournamentStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final statsAsync = ref.watch(tournamentStatsProvider);

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
            'Tournament Stats',
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
                    icon: Icons.emoji_events,
                    label: 'Total Tournaments',
                    value: stats.totalTournaments.toString(),
                    color: sem.warning,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    context: context,
                    icon: Icons.play_circle,
                    label: 'Active Tournaments',
                    value: stats.activeTournaments.toString(),
                    color: sem.success,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    context: context,
                    icon: Icons.check_circle,
                    label: 'Completed',
                    value: stats.completedTournaments.toString(),
                    color: cs.primary,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    context: context,
                    icon: Icons.people,
                    label: 'Total Participants',
                    value: stats.totalParticipants.toString(),
                    color: cs.tertiary,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    context: context,
                    icon: Icons.sports,
                    label: 'Tournament Matches',
                    value: stats.totalMatches.toString(),
                    color: sem.info,
                  ),
                ],
              );
            },
            loading: () => Column(
              children: List.generate(
                5,
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

  Widget _buildStatRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
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
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
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
