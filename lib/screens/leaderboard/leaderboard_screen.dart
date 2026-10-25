import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/permission_id.dart';
import '../../models/game_category_catalog.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../widgets/leaderboard_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../providers/auth_provider.dart';
import '../../models/customer.dart';
import '../../models/tournament.dart';
import '../../screens/tournament/tournament_detail_screen.dart';
import 'leaderboard_settings_screen.dart';
import '../../widgets/glass_panel.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/theme/app_theme.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _searchQuery = '';
  LeaderboardPeriod _period = LeaderboardPeriod.allTime;
  String _categoryKey = GameCategoryCatalog.allKey;

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.navLeaderboard)) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: Text('You do not have access to the leaderboard.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
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
    final leaderboardAsync = ref.watch(
      categoryPeriodLeaderboardProvider((
        categoryKey: _categoryKey,
        period: _period,
      )),
    );
    final statsAsync = ref.watch(leaderboardStatsProvider);
    final canManageLeaderboard = ref.watchResolvedPermissions().can(
      PermissionIds.opsLeaderboardManage,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context, theme, isMobile, canManageLeaderboard),
          if (!isMobile) _buildStatsBar(context, statsAsync),
          _buildCategoryTabs(context, isMobile),
          _buildSearchAndFilter(context, theme, isMobile),
          _buildPeriodChips(context, isMobile),
          Expanded(
            child: leaderboardAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return _buildEmptyState(context);
                }

                final filteredEntries = _filterEntries(entries);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(leaderboardProvider);
                  },
                  child: ListView.builder(
                    physics: AppTheme.scrollPhysicsFor(context),
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 8 : 16,
                      isMobile ? 8 : 16,
                      isMobile ? 8 : 16,
                      (isMobile ? 8 : 16) +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return LeaderboardCard(
                        entry: entry,
                        onTap: () {
                          _showCustomerDetails(context, entry);
                        },
                        onAwardTap: null,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: LoadingIndicator(message: 'Loading leaderboard...'),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('Error loading leaderboard: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(leaderboardProvider);
                        ref.invalidate(categoryPeriodLeaderboardProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    bool isMobile,
    bool canManageLeaderboard,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(isMobile ? 14 : 20),
          bottomRight: Radius.circular(isMobile ? 14 : 20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 6 : 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
            ),
            child: Icon(
              Icons.leaderboard,
              size: isMobile ? 18 : 28,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Text(
              'Leaderboard',
              style: TextStyle(
                fontSize: isMobile ? 16 : 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          if (canManageLeaderboard)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  AppMaterialPageRoute<void>(
                    builder: (context) => const LeaderboardSettingsScreen(),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                ),
                child: Icon(
                  Icons.settings,
                  size: isMobile ? 16 : 22,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(BuildContext context, bool isMobile) {
    final tabKeys = ref.watch(visibleLeaderboardCategoryKeysProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: isMobile ? 40 : 56,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
        itemCount: tabKeys.length,
        itemBuilder: (context, index) {
          final key = tabKeys[index];
          final isSelected = _categoryKey == key;

          return Padding(
            padding: EdgeInsets.only(right: isMobile ? 6 : 10),
            child: GestureDetector(
              onTap: () => setState(() => _categoryKey = key),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 16,
                  vertical: isMobile ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                  border: Border.all(
                    color: isSelected
                        ? cs.primary
                        : cs.outline.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      GameCategoryCatalog.iconFor(key),
                      size: isMobile ? 14 : 18,
                      color: isSelected
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                    SizedBox(width: isMobile ? 4 : 8),
                    Text(
                      isMobile
                          ? GameCategoryCatalog.shortLabel(key)
                          : GameCategoryCatalog.displayName(key),
                      style: TextStyle(
                        color: isSelected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: isMobile ? 11 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsBar(
    BuildContext context,
    AsyncValue<LeaderboardStats> statsAsync,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return statsAsync.when(
      data: (stats) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
            boxShadow: AppTheme.cardShadowFor(theme.brightness),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                icon: Icons.people,
                label: 'Players',
                value: stats.totalPlayers.toString(),
                color: cs.primary,
              ),
              _buildStatItem(
                context,
                icon: Icons.sports_esports,
                label: 'Matches',
                value: stats.totalMatches.toString(),
                color: cs.tertiary,
              ),
              _buildStatItem(
                context,
                icon: Icons.stars,
                label: 'Total Points',
                value: stats.totalPointsAwarded.toStringAsFixed(0),
                color: cs.secondary,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter(
    BuildContext context,
    ThemeData theme,
    bool isMobile,
  ) {
    final cs = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      child: Container(
        height: isMobile ? 44 : 52,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.22)),
          boxShadow: AppTheme.cardShadowFor(theme.brightness),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: isMobile
                ? 'Search players...'
                : 'Search by name or phone...',
            hintStyle: TextStyle(
              fontSize: isMobile ? 14 : 15,
              color: cs.onSurfaceVariant.withValues(alpha: 0.85),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: isMobile ? 22 : 24,
              color: cs.onSurfaceVariant,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 12,
            ),
            isDense: isMobile,
          ),
          style: TextStyle(fontSize: isMobile ? 13 : 14, color: cs.onSurface),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
      ),
    );
  }

  Widget _buildPeriodChips(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = [
      (label: 'All', shortLabel: 'All', value: LeaderboardPeriod.allTime),
      (label: '30d', shortLabel: '30d', value: LeaderboardPeriod.days30),
      (label: '7d', shortLabel: '7d', value: LeaderboardPeriod.days7),
      (label: 'Today', shortLabel: '1d', value: LeaderboardPeriod.today),
    ];

    return Container(
      height: isMobile ? 32 : 42,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: isMobile ? 2 : 4,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = _period == item.value;
          return Padding(
            padding: EdgeInsets.only(right: isMobile ? 6 : 8),
            child: GestureDetector(
              onTap: () => setState(() => _period = item.value),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 14,
                  vertical: isMobile ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                  border: Border.all(
                    color: selected
                        ? cs.primary
                        : cs.outline.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  isMobile ? item.shortLabel : item.label,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: selected
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard, size: 96, color: cs.onSurfaceVariant),
          const SizedBox(height: 24),
          Text(
            'No players yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start awarding points to see the leaderboard',
            style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<LeaderboardEntry> _filterEntries(List<LeaderboardEntry> entries) {
    var filtered = entries;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entry) {
        final customer = entry.customer;
        return customer.name.toLowerCase().contains(_searchQuery) ||
            customer.phoneNumber.contains(_searchQuery);
      }).toList();
    }

    // Note: Period filtering would require date-based queries
    // which should be done at the provider level for better performance

    return filtered;
  }

  void _showCustomerDetails(BuildContext context, LeaderboardEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => _CustomerDetailsDialog(entry: entry),
    );
  }

  // Quick award removed
}

class _CustomerDetailsDialog extends ConsumerStatefulWidget {
  final LeaderboardEntry entry;

  const _CustomerDetailsDialog({required this.entry});

  @override
  ConsumerState<_CustomerDetailsDialog> createState() =>
      _CustomerDetailsDialogState();
}

class _CustomerDetailsDialogState extends ConsumerState<_CustomerDetailsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchesAsync = ref.watch(
      customerMatchHistoryProvider(widget.entry.customer.id),
    );
    final tournamentHistoryAsync = ref.watch(
      customerTournamentHistoryProvider(widget.entry.customer.id),
    );

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      widget.entry.customer.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.entry.customer.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Rank #${widget.entry.rank}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.entry.points.toStringAsFixed(0)} pts',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              color: theme.colorScheme.surfaceContainerHigh,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.emoji_events,
                    label: 'Wins',
                    value: widget.entry.wins.toString(),
                    color: theme.colorScheme.tertiary,
                  ),
                  _buildStatItem(
                    icon: Icons.close,
                    label: 'Losses',
                    value: widget.entry.losses.toString(),
                    color: theme.colorScheme.error,
                  ),
                  tournamentHistoryAsync.when(
                    data: (tournaments) => _buildStatItem(
                      icon: Icons.emoji_events_outlined,
                      label: 'Tournaments',
                      value: tournaments.length.toString(),
                      color: theme.colorScheme.secondary,
                    ),
                    loading: () => _buildStatItem(
                      icon: Icons.emoji_events_outlined,
                      label: 'Tournaments',
                      value: '...',
                      color: theme.colorScheme.secondary,
                    ),
                    error: (_, _) => _buildStatItem(
                      icon: Icons.emoji_events_outlined,
                      label: 'Tournaments',
                      value: '0',
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Match History'),
                Tab(text: 'Tournament History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Match History Tab
                  matchesAsync.when(
                    data: (matches) {
                      if (matches.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('No match history'),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final match = matches[index];
                          final isWinner =
                              match.winnerId == widget.entry.customer.id;
                          return AppSurface(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              leading: Icon(
                                isWinner ? Icons.emoji_events : Icons.close,
                                color: isWinner
                                    ? theme.colorScheme.tertiary
                                    : theme.colorScheme.error,
                              ),
                              title: Text(
                                isWinner
                                    ? 'Won vs ${match.loserName ?? "Unknown"}'
                                    : 'Lost to ${match.winnerName}',
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    match.matchDate.toString().split(' ')[0],
                                  ),
                                  if (match.notes != null &&
                                      match.notes!.contains('Tournament')) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            theme.colorScheme.tertiaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Tournament',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme
                                              .colorScheme
                                              .onTertiaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: isWinner
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '+${match.pointsAwarded.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                    loading: () => ListView.builder(
                      itemCount: 5,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    error: (_, _) =>
                        const Center(child: Text('Error loading matches')),
                  ),
                  // Tournament History Tab
                  tournamentHistoryAsync.when(
                    data: (tournaments) {
                      if (tournaments.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('No tournament history'),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: tournaments.length,
                        itemBuilder: (context, index) {
                          final participant = tournaments[index];
                          return _TournamentHistoryCard(
                            participant: participant,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                AppMaterialPageRoute<void>(
                                  builder: (_) => TournamentDetailScreen(
                                    tournamentId: participant.tournamentId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    loading: () => ListView.builder(
                      itemCount: 4,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    error: (_, _) =>
                        const Center(child: Text('Error loading tournaments')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _TournamentHistoryCard extends ConsumerWidget {
  final TournamentParticipant participant;
  final VoidCallback onTap;

  const _TournamentHistoryCard({
    required this.participant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tournamentAsync = ref.watch(
      tournamentProvider(participant.tournamentId),
    );

    return AppSurface(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: tournamentAsync.when(
              data: (tournament) {
                if (tournament == null) {
                  return const Text('Tournament not found');
                }
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          context,
                          participant.status,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(participant.status),
                        color: _getStatusColor(context, participant.status),
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
                              Text(
                                tournament.gameType.displayName,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${participant.matchesWon}W - ${participant.matchesLost}L',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              context,
                              participant.status,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            participant.status.displayName,
                            style: TextStyle(
                              color: _getStatusColor(
                                context,
                                participant.status,
                              ),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (participant.pointsEarned > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+${participant.pointsEarned.toStringAsFixed(0)} pts',
                            style: TextStyle(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
              loading: () => Column(
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              error: (_, _) => const Text('Error loading tournament'),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(ParticipantStatus status) {
    switch (status) {
      case ParticipantStatus.registered:
        return Icons.how_to_reg;
      case ParticipantStatus.active:
        return Icons.play_circle;
      case ParticipantStatus.eliminated:
        return Icons.close;
      case ParticipantStatus.winner:
        return Icons.emoji_events;
      case ParticipantStatus.withdrawn:
        return Icons.exit_to_app;
    }
  }

  Color _getStatusColor(BuildContext context, ParticipantStatus status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case ParticipantStatus.registered:
        return cs.primary;
      case ParticipantStatus.active:
        return cs.tertiary;
      case ParticipantStatus.eliminated:
        return cs.error;
      case ParticipantStatus.winner:
        return cs.secondary;
      case ParticipantStatus.withdrawn:
        return cs.onSurfaceVariant;
    }
  }
}

class _QuickAwardDialog extends ConsumerStatefulWidget {
  final Customer customer;

  const _QuickAwardDialog({required this.customer});

  @override
  ConsumerState<_QuickAwardDialog> createState() => _QuickAwardDialogState();
}

class _QuickAwardDialogState extends ConsumerState<_QuickAwardDialog> {
  bool _isAwarding = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.stars, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Quick Award'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Award 10 points to:',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    widget.customer.name[0].toUpperCase(),
                    style: TextStyle(color: theme.colorScheme.onPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.customer.phoneNumber,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.stars,
                        color: theme.colorScheme.onSecondaryContainer,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '10 pts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This will add 10 points to their leaderboard score.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isAwarding ? null : () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton.icon(
          onPressed: _isAwarding ? null : _awardPoints,
          icon: _isAwarding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 16),
          label: Text(_isAwarding ? 'Awarding...' : 'Award Points'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _awardPoints() async {
    setState(() => _isAwarding = true);

    try {
      final currentUser = ref.read(appUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final service = ref.read(leaderboardServiceProvider);
      await service.awardPointsToWinner(
        winner: widget.customer,
        points: 10.0, // Default 10 points
        awardedBy: currentUser,
        gameType: 'snooker',
        notes: 'Quick award from leaderboard',
      );

      // Refresh leaderboard-related providers immediately
      ref.invalidate(leaderboardProvider);
      ref.invalidate(topPerformersProvider);
      // Invalidate period-based leaders for all periods
      for (final p in LeaderboardPeriod.values) {
        ref.invalidate(periodLeaderboardProvider(p));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully awarded 10 points to ${widget.customer.name}!',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to award points: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAwarding = false);
      }
    }
  }
}
