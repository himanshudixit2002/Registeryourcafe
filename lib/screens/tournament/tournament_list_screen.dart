import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/tournament.dart';
import '../../auth/permission_id.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/stats_strip.dart';
import '../../widgets/filter_chip_bar.dart';
import 'tournament_detail_screen.dart';
import 'create_tournament_dialog.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class TournamentListScreen extends ConsumerStatefulWidget {
  const TournamentListScreen({super.key});

  @override
  ConsumerState<TournamentListScreen> createState() =>
      _TournamentListScreenState();
}

class _TournamentListScreenState extends ConsumerState<TournamentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.navTournaments)) {
      return const Scaffold(
        body: Center(child: Text('You do not have access to tournaments.')),
      );
    }

    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);
    final canManageTournaments = ref
        .watchResolvedPermissions()
        .can(PermissionIds.opsTournamentManage);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context, theme),
          _buildStatsBar(context),
          _buildSearchAndTabs(context, theme, isMobile),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTournamentList(
                  context,
                  ref.watch(activeTournamentsProvider),
                  'No active tournaments',
                  'Start a new tournament to see it here',
                ),
                _buildTournamentList(
                  context,
                  ref.watch(upcomingTournamentsProvider),
                  'No upcoming tournaments',
                  'Create a tournament to get started',
                ),
                _buildTournamentList(
                  context,
                  ref.watch(completedTournamentsProvider),
                  'No completed tournaments',
                  'Past tournaments will appear here',
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: canManageTournaments
          ? FloatingActionButton.extended(
              heroTag: 'fab-shell-tournaments',
              onPressed: () => _showCreateTournamentDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New Tournament'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return const ScreenHeader(
      title: 'Tournaments',
      icon: Icons.emoji_events,
    );
  }

  Widget _buildStatsBar(BuildContext context) {
    final statsAsync = ref.watch(tournamentStatsProvider);
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);

    return statsAsync.when(
      data: (stats) => StatsStrip(
        items: [
          StatStripItem(
            icon: Icons.emoji_events,
            label: 'Total',
            value: stats.totalTournaments.toString(),
            color: sem.warning,
          ),
          StatStripItem(
            icon: Icons.play_circle,
            label: 'Active',
            value: stats.activeTournaments.toString(),
            color: sem.success,
          ),
          StatStripItem(
            icon: Icons.people,
            label: 'Players',
            value: stats.totalParticipants.toString(),
            color: sem.info,
          ),
          StatStripItem(
            icon: Icons.sports,
            label: 'Games',
            value: stats.totalMatches.toString(),
            color: cs.tertiary,
          ),
        ],
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildSearchAndTabs(
    BuildContext context,
    ThemeData theme,
    bool isMobile,
  ) {
    return Column(
      children: [
        FilterChipBar(
          searchHint: 'Search tournaments...',
          onSearchChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
          height: isMobile ? 36 : 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.onPrimary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicator: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(
              fontSize: isMobile ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: isMobile ? 11 : 13,
              fontWeight: FontWeight.w500,
            ),
            padding: EdgeInsets.all(isMobile ? 2 : 4),
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Done'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTournamentList(
    BuildContext context,
    AsyncValue<List<Tournament>> tournamentsAsync,
    String emptyTitle,
    String emptySubtitle,
  ) {
    return tournamentsAsync.when(
      data: (tournaments) {
        final filtered = _filterTournaments(tournaments);

        if (filtered.isEmpty) {
          return Center(
            child: EmptyStateWidget(
              icon: Icons.emoji_events_outlined,
              message: emptyTitle,
              details: emptySubtitle,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tournamentsProvider);
          },
          child: ListView.builder(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return _TournamentCard(
                tournament: filtered[index],
                onTap: () => _navigateToDetail(context, filtered[index]),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: LoadingIndicator(message: 'Loading tournaments...'),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(tournamentsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }

  List<Tournament> _filterTournaments(List<Tournament> tournaments) {
    if (_searchQuery.isEmpty) return tournaments;
    return tournaments.where((t) {
      return t.name.toLowerCase().contains(_searchQuery) ||
          t.gameType.displayName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _navigateToDetail(BuildContext context, Tournament tournament) {
    Navigator.push(
      context,
      AppMaterialPageRoute<void>(
        builder: (_) => TournamentDetailScreen(tournamentId: tournament.id),
      ),
    );
  }

  Future<void> _showCreateTournamentDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateTournamentDialog(),
    );

    if (result == true) {
      ref.invalidate(tournamentsProvider);
      if (!context.mounted) return;
      SnackbarHelper.showSuccess(context, 'Tournament created successfully!');
    }
  }
}

class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final VoidCallback onTap;

  const _TournamentCard({required this.tournament, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppSurface(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          context,
                          tournament.status,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getGameTypeIcon(tournament.gameType),
                        color: _getStatusColor(context, tournament.status),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.category,
                                size: 14,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${tournament.gameType.displayName} • ${tournament.format.displayName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(context, tournament.status),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.people,
                      label:
                          '${tournament.currentParticipantCount}/${tournament.maxParticipantsDisplay}',
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      icon: Icons.calendar_today,
                      label: DateFormat(
                        'MMM dd, yyyy',
                      ).format(tournament.startDate),
                    ),
                    const Spacer(),
                    if (tournament.status == TournamentStatus.inProgress)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Round ${tournament.currentRound}/${tournament.totalRounds}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                if (tournament.winnerId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events, color: cs.tertiary),
                        const SizedBox(width: 8),
                        Text(
                          'Winner: ${tournament.winnerName}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, TournamentStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(context, status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(context, status),
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Builder(
      builder: (context) {
        final o = Theme.of(context).colorScheme.onSurfaceVariant;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: o),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: o)),
          ],
        );
      },
    );
  }

  Color _getStatusColor(BuildContext context, TournamentStatus status) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (status) {
      case TournamentStatus.draft:
        return cs.outline;
      case TournamentStatus.registration:
        return sem.info;
      case TournamentStatus.inProgress:
        return sem.success;
      case TournamentStatus.completed:
        return sem.warning;
      case TournamentStatus.cancelled:
        return cs.error;
    }
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
}
