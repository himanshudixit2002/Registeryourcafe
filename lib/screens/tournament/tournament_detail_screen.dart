import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/permission_id.dart';
import '../../models/tournament.dart';
import '../../models/tournament_registration.dart';
import '../../constants/payment_mode.dart';
import '../../providers/tournament_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/app_card.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/section_async_error.dart';
import 'create_tournament_dialog.dart';
import 'tournament_bracket_widget.dart';
import 'approve_registration_dialog.dart';
import 'refund_registration_dialog.dart';
import 'add_participant_dialog.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class TournamentDetailScreen extends ConsumerStatefulWidget {
  final String tournamentId;

  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getTournamentStatusColor(
    BuildContext context,
    TournamentStatus status,
  ) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (status) {
      case TournamentStatus.draft:
        return cs.onSurfaceVariant;
      case TournamentStatus.registration:
        return sem.info;
      case TournamentStatus.inProgress:
        return sem.success;
      case TournamentStatus.completed:
        return AppTheme.warningColor;
      case TournamentStatus.cancelled:
        return cs.error;
    }
  }

  /// Readable foreground on a saturated accent fill (badges, pills).
  Color _onAccentFg(Color accent, ThemeData theme) {
    return accent.computeLuminance() > 0.55
        ? theme.colorScheme.onSurface
        : theme.colorScheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.navTournaments)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: const Center(
          child: Text('You do not have access to tournaments.'),
        ),
      );
    }

    final tournamentAsync = ref.watch(tournamentProvider(widget.tournamentId));
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final canManageTournaments = ref
        .watchResolvedPermissions()
        .can(PermissionIds.opsTournamentManage);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.4 : 0.12,
                  ),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: theme.colorScheme.onSurface,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: tournamentAsync.when(
          data: (t) => Text(
            t?.name ?? 'Tournament',
            style: TextStyle(fontSize: isMobile ? 18 : 20),
          ),
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Tournament'),
        ),
        centerTitle: true,
        actions: [
          tournamentAsync.maybeWhen(
            data: (tournament) {
              if (tournament == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onSelected: (value) => _handleMenuAction(value, tournament),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    if (tournament.isEditable && canManageTournaments)
                      _buildPopupItem(
                        'edit',
                        Icons.edit_rounded,
                        'Edit',
                        theme.colorScheme.primary,
                      ),
                    if (tournament.status == TournamentStatus.draft &&
                        canManageTournaments)
                      _buildPopupItem(
                        'open_registration',
                        Icons.how_to_reg_rounded,
                        'Open Registration',
                        AppSemanticColors.of(context).success,
                      ),
                    if (tournament.canAddParticipants &&
                        tournament.canStart &&
                        canManageTournaments)
                      _buildPopupItem(
                        'start',
                        Icons.play_arrow_rounded,
                        'Start',
                        AppSemanticColors.of(context).success,
                      ),
                    if (tournament.status != TournamentStatus.completed &&
                        tournament.status != TournamentStatus.cancelled &&
                        canManageTournaments)
                      _buildPopupItem(
                        'cancel',
                        Icons.cancel_rounded,
                        AppStrings.cancel,
                        AppSemanticColors.of(context).warning,
                      ),
                    if (tournament.isEditable && canManageTournaments)
                      _buildPopupItem(
                        'delete',
                        Icons.delete_rounded,
                        'Delete',
                        theme.colorScheme.error,
                      ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isMobile ? 46 : 52),
          child: tournamentAsync.maybeWhen(
            data: (t) => _buildCustomTabs(context, t, isMobile),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator(message: 'Processing...'))
          : tournamentAsync.when(
              data: (tournament) {
                if (tournament == null) {
                  return const Center(child: Text('Tournament not found'));
                }
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, tournament),
                    _buildRegistrationsTab(context, tournament),
                    _buildBracketTab(context, tournament),
                    _buildParticipantsTab(context, tournament),
                  ],
                );
              },
              loading: () => const Center(
                child: LoadingIndicator(message: 'Loading tournament...'),
              ),
              error: (error, _) => SectionAsyncError(error: error),
            ),
      floatingActionButton: tournamentAsync.maybeWhen(
        data: (tournament) {
          if (tournament == null) return null;
          if (canManageTournaments && tournament.canAddParticipants) {
            return FloatingActionButton.extended(
              heroTag: 'fab-tournament-detail',
              onPressed: () {
                HapticFeedback.mediumImpact();
                _addParticipant(context, tournament);
              },
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Participant'),
            );
          }
          return null;
        },
        orElse: () => null,
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    IconData icon,
    String text,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTabs(
    BuildContext context,
    Tournament? tournament,
    bool isMobile,
  ) {
    final theme = Theme.of(context);
    final pendingCountAsync = tournament != null
        ? ref.watch(pendingRegistrationCountProvider(tournament.id))
        : null;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium - 2),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 10 : 12,
        ),
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab,
        padding: const EdgeInsets.all(4),
        isScrollable: isMobile,
        tabAlignment: isMobile ? TabAlignment.start : null,
        tabs: [
          Tab(
            height: isMobile ? 36 : 42,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: isMobile ? 14 : 16),
                  const SizedBox(width: 4),
                  Text(isMobile ? 'Info' : 'Overview'),
                ],
              ),
            ),
          ),
          Tab(
            height: isMobile ? 36 : 42,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.how_to_reg_rounded, size: isMobile ? 14 : 16),
                  const SizedBox(width: 4),
                  Text(isMobile ? 'Requests' : 'Registrations'),
                  // Show pending count badge
                  if (pendingCountAsync != null)
                    pendingCountAsync.when(
                      data: (count) => count > 0
                          ? Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                count.toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onError,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
          Tab(
            height: isMobile ? 36 : 42,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_tree_rounded, size: isMobile ? 14 : 16),
                  const SizedBox(width: 4),
                  const Text('Bracket'),
                ],
              ),
            ),
          ),
          Tab(
            height: isMobile ? 36 : 42,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline_rounded, size: isMobile ? 14 : 16),
                  const SizedBox(width: 4),
                  const Text('Players'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Overview Tab
  // ============================================================

  Widget _buildOverviewTab(BuildContext context, Tournament tournament) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return SingleChildScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildStatusCard(context, tournament),
          const SizedBox(height: 16),

          // Details Card
          _buildSectionCard(
            context: context,
            title: 'Tournament Details',
            icon: Icons.info_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  context: context,
                  icon: Icons.sports_rounded,
                  label: 'Game Type',
                  value: tournament.gameType.displayName,
                  isMobile: isMobile,
                ),
                _buildInfoRow(
                  context: context,
                  icon: Icons.account_tree_rounded,
                  label: 'Format',
                  value: tournament.format.displayName,
                  isMobile: isMobile,
                ),
                _buildInfoRow(
                  context: context,
                  icon: Icons.calendar_today_rounded,
                  label: 'Start Date',
                  value: DateFormat(
                    'EEE, MMM d, y',
                  ).format(tournament.startDate),
                  isMobile: isMobile,
                ),
                _buildInfoRow(
                  context: context,
                  icon: Icons.people_rounded,
                  label: 'Participants',
                  value:
                      '${tournament.currentParticipantCount}/${tournament.maxParticipantsDisplay}',
                  isMobile: isMobile,
                  valueColor: theme.colorScheme.primary,
                ),
                if (tournament.currentParticipantCount > 0)
                  _buildInfoRow(
                    context: context,
                    icon: Icons.skip_next_rounded,
                    label: 'Byes Needed',
                    value: '${tournament.byesNeeded}',
                    isMobile: isMobile,
                    subtitle:
                        'Bracket size: ${Tournament.getNextPowerOfTwo(tournament.currentParticipantCount)}',
                  ),
                if (tournament.preferredTableName != null)
                  _buildInfoRow(
                    context: context,
                    icon: Icons.table_bar_rounded,
                    label: 'Preferred Table',
                    value: tournament.preferredTableName!,
                    isMobile: isMobile,
                  ),
                if (tournament.description != null &&
                    tournament.description!.isNotEmpty)
                  _buildInfoRow(
                    context: context,
                    icon: Icons.description_rounded,
                    label: 'Description',
                    value: tournament.description!,
                    isMobile: isMobile,
                    isMultiline: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Points & Prizes Card
          _buildSectionCard(
            context: context,
            title: 'Points & Prizes',
            icon: Icons.emoji_events_rounded,
            child: Column(
              children: [
                // Entry Fee & Prize Pool - Top Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        context: context,
                        icon: Icons.currency_rupee_rounded,
                        label: 'Entry Fee',
                        value: '₹${tournament.entryFee.toStringAsFixed(0)}',
                        color: cs.primary,
                        isMobile: isMobile,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: _buildStatBox(
                        context: context,
                        icon: Icons.card_giftcard_rounded,
                        label: 'Prize Pool',
                        value: '₹${tournament.prizePool.toStringAsFixed(0)}',
                        color: sem.success,
                        isMobile: isMobile,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 8 : 12),
                // Points - Bottom Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        context: context,
                        icon: Icons.emoji_events_rounded,
                        label: 'Winner',
                        value:
                            '${tournament.pointsForWinner.toStringAsFixed(0)} pts',
                        color: sem.warning,
                        isMobile: isMobile,
                      ),
                    ),
                    SizedBox(width: isMobile ? 6 : 12),
                    Expanded(
                      child: _buildStatBox(
                        context: context,
                        icon: Icons.workspace_premium_rounded,
                        label: 'Runner-up',
                        value:
                            '${tournament.pointsForRunnerUp.toStringAsFixed(0)} pts',
                        color: cs.onSurfaceVariant,
                        isMobile: isMobile,
                      ),
                    ),
                    SizedBox(width: isMobile ? 6 : 12),
                    Expanded(
                      child: _buildStatBox(
                        context: context,
                        icon: Icons.stars_rounded,
                        label: 'Per Win',
                        value:
                            '${tournament.pointsPerWin.toStringAsFixed(0)} pts',
                        color: cs.tertiary,
                        isMobile: isMobile,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Winner display if completed
          if (tournament.winnerId != null)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    sem.warningContainer,
                    sem.warningContainer.withValues(alpha: 0.65),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sem.warning.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: sem.warning.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 10 : 14),
                      decoration: BoxDecoration(
                        color: sem.warning.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: sem.onWarningContainer,
                        size: isMobile ? 28 : 36,
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: sem.warning,
                                size: isMobile ? 14 : 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tournament Winner',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: sem.onWarningContainer,
                                  fontSize: isMobile ? 11 : 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tournament.winnerName ?? 'Unknown',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 16 : 20,
                            ),
                          ),
                          if (tournament.runnerUpName != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  color: cs.onSurfaceVariant,
                                  size: isMobile ? 14 : 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Runner-up: ${tournament.runnerUpName}',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Progress for in-progress tournaments
          if (tournament.status == TournamentStatus.inProgress) ...[
            const SizedBox(height: 16),
            _buildProgressCard(context, tournament),
          ],

          // Created by info
          const SizedBox(height: 16),
          Text(
            'Created by ${tournament.createdByName} on ${DateFormat('MMM d, y').format(tournament.createdAt)}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, Tournament tournament) {
    final statusColor = _getTournamentStatusColor(context, tournament.status);
    IconData statusIcon;
    String statusMessage;
    bool showPulsingDot = false;

    switch (tournament.status) {
      case TournamentStatus.draft:
        statusIcon = Icons.edit_note_rounded;
        statusMessage =
            'Tournament is in draft mode. Add participants to begin.';
        break;
      case TournamentStatus.registration:
        statusIcon = Icons.how_to_reg_rounded;
        if (tournament.hasNoMaxLimit || tournament.maxParticipants == 0) {
          statusMessage =
              'Registration is open. ${tournament.currentParticipantCount} participants registered.';
        } else {
          final spotsRemaining =
              tournament.maxParticipants - tournament.currentParticipantCount;
          statusMessage =
              'Registration is open. $spotsRemaining spot${spotsRemaining == 1 ? '' : 's'} remaining.';
        }
        break;
      case TournamentStatus.inProgress:
        statusIcon = Icons.play_circle_rounded;
        statusMessage =
            'Tournament is in progress. Round ${tournament.currentRound} of ${tournament.totalRounds}.';
        showPulsingDot = true;
        break;
      case TournamentStatus.completed:
        statusIcon = Icons.emoji_events_rounded;
        statusMessage = 'Tournament completed!';
        break;
      case TournamentStatus.cancelled:
        statusIcon = Icons.cancel_rounded;
        statusMessage = 'Tournament has been cancelled.';
        break;
    }

    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.15),
            statusColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: isMobile ? 24 : 28,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tournament.status.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                      if (showPulsingDot) ...[
                        const SizedBox(width: 8),
                        PulsingDot(color: statusColor, showGlow: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusMessage,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.35 : 0.08,
            ),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                    size: isMobile ? 16 : 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.subtleDividerColor(theme)),
          // Content
          Padding(padding: EdgeInsets.all(isMobile ? 12 : 16), child: child),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required bool isMobile,
    Color? valueColor,
    String? subtitle,
    bool isMultiline = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: isMobile ? 14 : 16,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 13 : 14,
                    color: valueColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: isMobile ? 10 : 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isMobile = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isMobile ? 18 : 24),
          SizedBox(height: isMobile ? 4 : 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: isMobile ? 12 : 16,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 9 : 12,
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, Tournament tournament) {
    final theme = Theme.of(context);
    final matchesAsync = ref.watch(tournamentMatchesProvider(tournament.id));

    return matchesAsync.when(
      data: (matches) {
        final completed = matches
            .where(
              (m) =>
                  m.status == MatchStatus.completed ||
                  m.status == MatchStatus.walkover,
            )
            .length;
        final total = matches.where((m) => !m.isBye).length;
        final progress = total > 0 ? completed / total : 0.0;

        return AppSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tournament Progress',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '$completed of $total matches completed',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  // ============================================================
  // Registrations Tab
  // ============================================================

  Widget _buildRegistrationsTab(BuildContext context, Tournament tournament) {
    final registrationsAsync = ref.watch(
      allRegistrationsProvider(tournament.id),
    );
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return registrationsAsync.when(
      data: (registrations) {
        final perms = ref.watchResolvedPermissions();
        final canManage = perms.can(PermissionIds.opsTournamentManage);
        final canRefundReg =
            canManage && perms.can(PermissionIds.opsRefund);

        if (registrations.isEmpty) {
          final cs = Theme.of(context).colorScheme;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.how_to_reg_outlined,
                  size: 64,
                  color: cs.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Registration Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Registration requests will appear here',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                if (tournament.status == TournamentStatus.draft && canManage)
                  ElevatedButton.icon(
                    onPressed: () => _openRegistration(tournament),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Open Registration'),
                  ),
              ],
            ),
          );
        }

        // Group registrations by status
        final pending = registrations
            .where((r) => r.status == RegistrationStatus.pending)
            .toList();
        final approved = registrations
            .where(
              (r) => r.status == RegistrationStatus.approved && !r.isRefunded,
            )
            .toList();
        final rejected = registrations
            .where((r) => r.status == RegistrationStatus.rejected)
            .toList();
        final refunded = registrations.where((r) => r.isRefunded).toList();

        // Calculate stats
        final totalCollected = approved.fold<double>(
          0,
          (sum, r) => sum + (r.amountPaid ?? 0),
        );
        final totalRefunded = refunded.fold<double>(
          0,
          (sum, r) => sum + (r.refundAmount ?? 0),
        );
        final creditsRefunded = refunded.fold<double>(
          0,
          (sum, r) => sum + (r.creditsRefunded ?? 0),
        );
        final cs = Theme.of(context).colorScheme;
        final sem = AppSemanticColors.of(context);

        return ListView(
          physics: AppTheme.scrollPhysicsFor(context),
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          children: [
            // Stats Summary Card at top
            _buildRegistrationStatsCard(
              context,
              pending: pending.length,
              approved: approved.length,
              rejected: rejected.length,
              refunded: refunded.length,
              totalCollected: totalCollected,
              totalRefunded: totalRefunded,
              creditsRefunded: creditsRefunded,
              entryFee: tournament.entryFee,
            ),
            const SizedBox(height: 16),

            // Pending Section (most important)
            if (pending.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                icon: Icons.pending_actions,
                title: 'Pending Approval',
                count: pending.length,
                color: sem.warning,
              ),
              const SizedBox(height: 8),
              ...pending.map(
                (r) => _RegistrationRequestCard(
                  registration: r,
                  tournament: tournament,
                  onApprove: canManage
                      ? () => _showApproveDialog(r, tournament)
                      : null,
                  onReject:
                      canManage ? () => _rejectRegistration(r) : null,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Approved Section
            if (approved.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                icon: Icons.check_circle,
                title: 'Approved',
                count: approved.length,
                color: sem.success,
              ),
              const SizedBox(height: 8),
              ...approved.map(
                (r) => _RegistrationRequestCard(
                  registration: r,
                  tournament: tournament,
                  onRefund: canRefundReg
                      ? () => _showRefundDialog(r, tournament)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Refunded Section
            if (refunded.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                icon: Icons.undo,
                title: 'Refunded',
                count: refunded.length,
                color: cs.tertiary,
              ),
              const SizedBox(height: 8),
              ...refunded.map(
                (r) => _RegistrationRequestCard(
                  registration: r,
                  tournament: tournament,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Rejected Section
            if (rejected.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                icon: Icons.cancel,
                title: 'Rejected',
                count: rejected.length,
                color: cs.error,
              ),
              const SizedBox(height: 8),
              ...rejected.map(
                (r) => _RegistrationRequestCard(
                  registration: r,
                  tournament: tournament,
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: LoadingIndicator(message: 'Loading registrations...'),
      ),
      error: (error, _) => SectionAsyncError(error: error),
    );
  }

  Widget _buildRegistrationStatsCard(
    BuildContext context, {
    required int pending,
    required int approved,
    required int rejected,
    required int refunded,
    required double totalCollected,
    required double totalRefunded,
    required double creditsRefunded,
    required double entryFee,
  }) {
    final netRevenue = totalCollected - totalRefunded;
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);

    return AppSurface(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      borderColor: cs.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 20,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Registration Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status counts row
          Wrap(
            spacing: isMobile ? 8 : 16,
            runSpacing: 8,
            children: [
              _buildStatChip(
                icon: Icons.pending_actions,
                label: 'Pending',
                value: pending.toString(),
                color: sem.warning,
              ),
              _buildStatChip(
                icon: Icons.check_circle,
                label: 'Approved',
                value: approved.toString(),
                color: sem.success,
              ),
              _buildStatChip(
                icon: Icons.cancel,
                label: 'Rejected',
                value: rejected.toString(),
                color: cs.error,
              ),
              _buildStatChip(
                icon: Icons.undo,
                label: 'Refunded',
                value: refunded.toString(),
                color: cs.tertiary,
              ),
            ],
          ),

          Divider(height: 24, color: AppTheme.subtleDividerColor(theme)),

          // Financial summary
          Row(
            children: [
              Expanded(
                child: _buildFinancialTile(
                  label: 'Collected',
                  amount: totalCollected,
                  icon: Icons.savings_outlined,
                  color: sem.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialTile(
                  label: 'Refunded',
                  amount: totalRefunded,
                  icon: Icons.arrow_upward,
                  color: cs.error,
                  subtitle: creditsRefunded > 0
                      ? '(₹${creditsRefunded.toStringAsFixed(0)} to credits)'
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialTile(
                  label: 'Net Revenue',
                  amount: netRevenue,
                  icon: Icons.account_balance_wallet_outlined,
                  color: cs.primary,
                  isBold: true,
                ),
              ),
            ],
          ),

          if (entryFee > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sem.infoContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sem.info.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.45 : 0.35,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: sem.onInfoContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Entry Fee: ₹${entryFee.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: sem.onInfoContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12, color: color)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialTile({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    String? subtitle,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: _onAccentFg(color, theme),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showApproveDialog(
    TournamentRegistration registration,
    Tournament tournament,
  ) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ApproveRegistrationDialog(
        registration: registration,
        tournament: tournament,
      ),
    );

    if (result == true) {
      ref.invalidate(allRegistrationsProvider(tournament.id));
      ref.invalidate(tournamentParticipantsProvider(tournament.id));
    }
  }

  Future<void> _showRefundDialog(
    TournamentRegistration registration,
    Tournament tournament,
  ) async {
    final perms = ref.readResolvedPermissions();
    if (!perms.can(PermissionIds.opsTournamentManage) ||
        !perms.can(PermissionIds.opsRefund)) {
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => RefundRegistrationDialog(
        registration: registration,
        tournament: tournament,
      ),
    );

    if (result == true) {
      ref.invalidate(allRegistrationsProvider(tournament.id));
      ref.invalidate(tournamentParticipantsProvider(tournament.id));
    }
  }

  Future<void> _rejectRegistration(TournamentRegistration registration) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Registration?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject ${registration.customerName}\'s registration?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Why is this being rejected?',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final currentUser = ref.read(appUserProvider).value;
      if (currentUser == null) throw Exception('User not authenticated');

      await ref
          .read(tournamentServiceProvider)
          .rejectRegistrationRequest(
            registrationId: registration.id,
            rejectedBy: currentUser,
            reason: reasonController.text.trim().isNotEmpty
                ? reasonController.text.trim()
                : null,
          );

      if (mounted) {
        context.showWarningSnackbar(
          '${registration.customerName}\'s registration rejected',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Bracket Tab
  // ============================================================

  Widget _buildBracketTab(BuildContext context, Tournament tournament) {
    final canManage =
        ref.watchResolvedPermissions().can(PermissionIds.opsTournamentManage);
    final cs = Theme.of(context).colorScheme;
    if (tournament.status == TournamentStatus.draft ||
        tournament.status == TournamentStatus.registration) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'Bracket Not Generated',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the tournament to generate the bracket',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (tournament.currentParticipantCount >= 2 && canManage) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _startTournament(tournament),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Tournament'),
              ),
            ],
          ],
        ),
      );
    }

    return TournamentBracketWidget(
      tournamentId: tournament.id,
      onMatchTap: (match) =>
          _showMatchDetailsDialog(context, match, tournament),
    );
  }

  // ============================================================
  // Participants Tab
  // ============================================================

  Widget _buildParticipantsTab(BuildContext context, Tournament tournament) {
    final participantsAsync = ref.watch(
      tournamentParticipantsProvider(tournament.id),
    );
    final canManage =
        ref.watchResolvedPermissions().can(PermissionIds.opsTournamentManage);

    return participantsAsync.when(
      data: (participants) {
        if (participants.isEmpty) {
          final cs = Theme.of(context).colorScheme;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: cs.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Participants Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add participants to get started',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: AppTheme.scrollPhysicsFor(context),
          padding: const EdgeInsets.all(16),
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final participant = participants[index];
            return _ParticipantCard(
              participant: participant,
              tournament: tournament,
              onRemove: tournament.canAddParticipants && canManage
                  ? () => _removeParticipant(participant, tournament)
                  : null,
            );
          },
        );
      },
      loading: () => const Center(
        child: LoadingIndicator(message: 'Loading participants...'),
      ),
      error: (error, _) => SectionAsyncError(error: error),
    );
  }

  // ============================================================
  // Actions
  // ============================================================

  void _handleMenuAction(String action, Tournament tournament) {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }
    switch (action) {
      case 'edit':
        _editTournament(tournament);
        break;
      case 'open_registration':
        _openRegistration(tournament);
        break;
      case 'start':
        _startTournament(tournament);
        break;
      case 'cancel':
        _cancelTournament(tournament);
        break;
      case 'delete':
        _deleteTournament(tournament);
        break;
    }
  }

  Future<void> _editTournament(Tournament tournament) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateTournamentDialog(existingTournament: tournament),
    );

    if (result == true) {
      ref.invalidate(tournamentProvider(tournament.id));
    }
  }

  Future<void> _openRegistration(Tournament tournament) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(tournamentServiceProvider).openRegistration(tournament.id);
      if (mounted) {
        context.showSuccessSnackbar('Registration is now open!');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startTournament(Tournament tournament) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Tournament?'),
        content: Text(
          'This will generate the bracket with ${tournament.currentParticipantCount} participants. '
          'You cannot add more participants after starting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final currentUser = ref.read(appUserProvider).value;
      if (currentUser == null) throw Exception('User not authenticated');

      await ref
          .read(tournamentServiceProvider)
          .startTournament(tournamentId: tournament.id, startedBy: currentUser);

      if (mounted) {
        context.showSuccessSnackbar('Tournament started! Bracket generated.');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelTournament(Tournament tournament) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Tournament?'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final currentUser = ref.read(appUserProvider).value;
      if (currentUser == null) throw Exception('User not authenticated');

      await ref
          .read(tournamentServiceProvider)
          .cancelTournament(
            tournamentId: tournament.id,
            cancelledBy: currentUser,
          );

      if (mounted) {
        context.showWarningSnackbar('Tournament cancelled');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTournament(Tournament tournament) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tournament?'),
        content: const Text(
          'This will permanently delete the tournament and all its data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(tournamentServiceProvider).deleteTournament(tournament.id);

      if (mounted) {
        context.showSuccessSnackbar('Tournament deleted');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addParticipant(
    BuildContext context,
    Tournament tournament,
  ) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }
    // Use the new dialog with payment recording
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AddParticipantDialog(tournament: tournament),
    );

    // Success is handled by the dialog itself with SnackBar
    if (result == true && mounted) {
      setState(() {}); // Refresh UI
    }
  }

  Future<void> _removeParticipant(
    TournamentParticipant participant,
    Tournament tournament,
  ) async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Participant?'),
        content: Text(
          'Are you sure you want to remove ${participant.customerName} from the tournament?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(tournamentServiceProvider)
          .removeParticipant(
            tournamentId: tournament.id,
            participantId: participant.id,
            customerId: participant.customerId,
          );

      if (mounted) {
        context.showWarningSnackbar('${participant.customerName} removed');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMatchDetailsDialog(
    BuildContext context,
    TournamentMatch match,
    Tournament tournament,
  ) {
    final canManage = ref.readResolvedPermissions().can(
      PermissionIds.opsTournamentManage,
    );
    showDialog<void>(
      context: context,
      builder: (_) => _MatchDetailsDialog(
        match: match,
        tournament: tournament,
        canManageMutations: canManage,
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final TournamentParticipant participant;
  final Tournament tournament;
  final VoidCallback? onRemove;

  const _ParticipantCard({
    required this.participant,
    required this.tournament,
    this.onRemove,
  });

   @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    late Color statusColor;
    late IconData statusIcon;

    switch (participant.status) {
      case ParticipantStatus.registered:
        statusColor = cs.onSurfaceVariant;
        statusIcon = Icons.pending;
        break;
      case ParticipantStatus.active:
        statusColor = sem.success;
        statusIcon = Icons.play_arrow;
        break;
      case ParticipantStatus.eliminated:
        statusColor = cs.error;
        statusIcon = Icons.close;
        break;
      case ParticipantStatus.winner:
        statusColor = sem.warning;
        statusIcon = Icons.emoji_events;
        break;
      case ParticipantStatus.withdrawn:
        statusColor = sem.warning;
        statusIcon = Icons.exit_to_app;
        break;
    }

    return AppSurface(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: tournament.isSeeded
                ? Text(
                    '#${participant.seed}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  )
                : Icon(statusIcon, color: statusColor, size: 20),
          ),
        ),
        title: Text(
          participant.customerName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                participant.status.displayName,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (participant.matchesPlayed > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${participant.matchesPlayed} matches',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
        trailing: onRemove != null
            ? IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: cs.error,
                ),
                onPressed: onRemove,
              )
            : null,
      ),
    );
  }
}

class _MatchDetailsDialog extends ConsumerStatefulWidget {
  final TournamentMatch match;
  final Tournament tournament;
  final bool canManageMutations;

  const _MatchDetailsDialog({
    required this.match,
    required this.tournament,
    required this.canManageMutations,
  });

  @override
  ConsumerState<_MatchDetailsDialog> createState() =>
      _MatchDetailsDialogState();
}

class _MatchDetailsDialogState extends ConsumerState<_MatchDetailsDialog> {
  final _score1Controller = TextEditingController();
  final _score2Controller = TextEditingController();
  String? _selectedWinnerId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.match.participant1Score != null) {
      _score1Controller.text = widget.match.participant1Score.toString();
    }
    if (widget.match.participant2Score != null) {
      _score2Controller.text = widget.match.participant2Score.toString();
    }
    _selectedWinnerId = widget.match.winnerId;
  }

  @override
  void dispose() {
    _score1Controller.dispose();
    _score2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = widget.match;
    final matchAllowsEdit =
        match.status == MatchStatus.pending ||
        match.status == MatchStatus.scheduled ||
        match.status == MatchStatus.inProgress;
    final isEditable = matchAllowsEdit && widget.canManageMutations;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.tournament.getRoundName(match.round),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Player 1
            _buildPlayerRow(
              name: match.participant1Name ?? 'TBD',
              isWinner: _selectedWinnerId == match.participant1Id,
              canSelect: isEditable && match.participant1Id != null,
              onSelect: () {
                setState(() => _selectedWinnerId = match.participant1Id);
              },
              scoreController: _score1Controller,
              isEditable: isEditable,
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            // Player 2
            _buildPlayerRow(
              name: match.isBye ? 'BYE' : (match.participant2Name ?? 'TBD'),
              isWinner: _selectedWinnerId == match.participant2Id,
              canSelect:
                  isEditable && match.participant2Id != null && !match.isBye,
              onSelect: () {
                setState(() => _selectedWinnerId = match.participant2Id);
              },
              scoreController: _score2Controller,
              isEditable: isEditable && !match.isBye,
            ),

            const SizedBox(height: 24),

            // Status
            Row(
              children: [
                Icon(
                  _getStatusIcon(match.status),
                  color: _getStatusColor(context, match.status),
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: ${match.status.displayName}',
                  style: TextStyle(
                    color: _getStatusColor(context, match.status),
                  ),
                ),
              ],
            ),

            if (isEditable && match.isReady) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedWinnerId != null && !_isLoading
                      ? _recordResult
                      : null,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Record Result'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppSemanticColors.of(context).success,
                    foregroundColor: AppSemanticColors.of(context).onSuccess,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerRow({
    required String name,
    required bool isWinner,
    required bool canSelect,
    required VoidCallback onSelect,
    required TextEditingController scoreController,
    required bool isEditable,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    return InkWell(
      onTap: canSelect ? onSelect : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isWinner
              ? sem.success.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isWinner ? sem.success : cs.outlineVariant,
            width: isWinner ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (canSelect)
              Icon(
                isWinner
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isWinner ? sem.success : cs.outline,
                size: 22,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                  color: name == 'TBD' || name == 'BYE'
                      ? cs.onSurfaceVariant
                      : cs.onSurface,
                ),
              ),
            ),
            if (isEditable && name != 'BYE')
              SizedBox(
                width: 60,
                child: TextField(
                  controller: scoreController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'Score',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(MatchStatus status) {
    switch (status) {
      case MatchStatus.pending:
        return Icons.hourglass_empty;
      case MatchStatus.scheduled:
        return Icons.schedule;
      case MatchStatus.inProgress:
        return Icons.play_circle;
      case MatchStatus.completed:
        return Icons.check_circle;
      case MatchStatus.cancelled:
        return Icons.cancel;
      case MatchStatus.walkover:
        return Icons.arrow_forward;
    }
  }
  Color _getStatusColor(BuildContext context, MatchStatus status) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    switch (status) {
      case MatchStatus.pending:
        return cs.onSurfaceVariant;
      case MatchStatus.scheduled:
        return sem.info;
      case MatchStatus.inProgress:
        return sem.warning;
      case MatchStatus.completed:
        return sem.success;
      case MatchStatus.cancelled:
        return cs.error;
      case MatchStatus.walkover:
        return sem.warning;
    }
  }

  Future<void> _recordResult() async {
    if (_selectedWinnerId == null) return;
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(appUserProvider).value;
      if (currentUser == null) throw Exception('User not authenticated');

      final winnerName = _selectedWinnerId == widget.match.participant1Id
          ? widget.match.participant1Name
          : widget.match.participant2Name;

      await ref
          .read(tournamentServiceProvider)
          .recordMatchResult(
            matchId: widget.match.id,
            winnerId: _selectedWinnerId!,
            winnerName: winnerName ?? 'Unknown',
            participant1Score: int.tryParse(_score1Controller.text),
            participant2Score: int.tryParse(_score2Controller.text),
            completedBy: currentUser,
          );

      if (mounted) {
        context.showSuccessSnackbar('Match result recorded: $winnerName wins!');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _RegistrationRequestCard extends StatelessWidget {
  final TournamentRegistration registration;
  final Tournament tournament;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRefund;

  const _RegistrationRequestCard({
    required this.registration,
    required this.tournament,
    this.onApprove,
    this.onReject,
    this.onRefund,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = registration.status == RegistrationStatus.pending;
    final isApproved = registration.status == RegistrationStatus.approved;
    final isRejected = registration.status == RegistrationStatus.rejected;
    final isRefunded = registration.isRefunded;
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    Color statusColor;
    IconData statusIcon;

    if (isRefunded) {
      statusColor = cs.tertiary;
      statusIcon = Icons.undo;
    } else if (isPending) {
      statusColor = sem.warning;
      statusIcon = Icons.pending_actions;
    } else if (isApproved) {
      statusColor = sem.success;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = cs.error;
      statusIcon = Icons.cancel;
    }

    return AppSurface(
      margin: const EdgeInsets.only(bottom: 8),
      borderRadius: 12,
      padding: const EdgeInsets.all(12),
      borderColor: statusColor.withValues(alpha: isPending ? 0.4 : 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    registration.customerName.isNotEmpty
                        ? registration.customerName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registration.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (registration.customerPhone != null)
                      Text(
                        registration.customerPhone!,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      isRefunded ? 'Refunded' : registration.status.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Request note
          if (registration.requestNote != null &&
              registration.requestNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      registration.requestNote!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Payment info (for approved)
          if (isApproved && registration.amountPaid != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sem.successContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: sem.success.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, size: 14, color: sem.onSuccessContainer),
                  const SizedBox(width: 6),
                  Text(
                    'Paid ₹${registration.amountPaid!.toStringAsFixed(0)} via ${registration.paymentMethod?.displayName ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: sem.onSuccessContainer,
                    ),
                  ),
                  if (registration.approvedByName != null) ...[
                    const Spacer(),
                    Text(
                      'by ${registration.approvedByName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Refund info
          if (isRefunded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: cs.tertiary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.undo, size: 14, color: cs.onTertiaryContainer),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refunded ₹${(registration.refundAmount ?? 0).toStringAsFixed(0)}'
                          ' via ${registration.refundPaymentMethod ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Credits returned: ${(registration.creditsRefunded ?? 0).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (registration.refundedAt != null)
                          Text(
                            'On ${DateFormat('MMM d, y • h:mm a').format(registration.refundedAt!)}'
                            ' by ${registration.refundedByName ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        if (registration.refundNote != null &&
                            registration.refundNote!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Note: ${registration.refundNote}',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Rejection reason
          if (isRejected && registration.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: cs.error.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: cs.onErrorContainer,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reason: ${registration.rejectionReason}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Date info
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: cs.outline),
              const SizedBox(width: 4),
              Text(
                'Requested: ${DateFormat('MMM d, y • h:mm a').format(registration.requestedAt)}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),

          // Action buttons (for pending)
          if (isPending && (onApprove != null || onReject != null)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Entry fee reminder
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sem.infoContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.currency_rupee,
                          size: 14,
                          color: sem.onInfoContainer,
                        ),
                        Text(
                          'Entry: ${tournament.entryFee > 0 ? '₹${tournament.entryFee.toStringAsFixed(0)}' : 'FREE'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: sem.onInfoContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (onReject != null)
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (onApprove != null)
                  ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sem.success,
                      foregroundColor: sem.onSuccess,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Actions for approved (refund)
          if (isApproved && !isRefunded && onRefund != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onRefund,
                icon: const Icon(Icons.undo),
                label: const Text('Refund'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onTertiaryContainer,
                  side: BorderSide(color: cs.outlineVariant),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
