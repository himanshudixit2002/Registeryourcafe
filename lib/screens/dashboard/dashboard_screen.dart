import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/permission_id.dart';
import '../../models/venue_ui_config.dart';
import '../../navigation/shell_route_titles.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/shell_route_title_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_skeleton.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/table_provider.dart';
import '../../models/table.dart';
import '../../models/session.dart';
import '../../widgets/active_session_card.dart';
import '../../widgets/dashboard_leaderboard_widget.dart';
import '../../widgets/dashboard_tournament_widget.dart';
import '../../widgets/glass_modal_bottom_sheet.dart';
import 'components/revenue_chart.dart';
import '../tables/session_details_dialog.dart';
import '../tables/dining/dining_session_screen.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/tenant_provider.dart';
import 'widgets/dashboard_category_sales.dart';
import 'widgets/dashboard_hero_header.dart';
import 'widgets/dashboard_insights.dart';
import 'widgets/dashboard_kpi_grid.dart';
import 'widgets/dashboard_load_error.dart';
import 'widgets/dashboard_section.dart';
import '../../widgets/dashboard_billing_health_strip.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardData = ref.watch(dashboardProvider);
    final modules = ref.watch(workspaceModuleVisibilityProvider);
    final venueKind = ref.watch(venueKindProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < AppTheme.kMobileBreakpoint;
    final useWideDashboardLayout = screenWidth >= AppTheme.kTabletBreakpoint;
    final padding = isMobile ? AppTheme.kSpacingSmall : 24.0;
    final perms = ref.watchResolvedPermissions();
    void goToSales() {
      navigateToShellTitleIfVisible(ref, ShellRouteTitles.sales);
    }

    if (!perms.can(PermissionIds.navDashboard)) {
      return const Scaffold(
        body: Center(child: Text('You do not have access to the dashboard.')),
      );
    }

    return dashboardData.when(
      data: (data) {
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashboardHeroHeader(),
            SizedBox(height: isMobile ? 20 : 28),
            const DashboardBillingHealthStrip(),
            if (perms.can(PermissionIds.navTables)) ...[
              _buildActiveSessionsSection(context, ref, screenWidth, isMobile),
              SizedBox(height: isMobile ? 20 : 28),
            ],
            if (perms.can(PermissionIds.navCafe)) ...[
              _buildKitchenSummary(context, ref, isMobile),
              SizedBox(height: isMobile ? 20 : 28),
            ],
            DashboardSection(
              eyebrow: 'Overview',
              title: 'Key metrics',
              subtitle: 'Snapshot from your live data',
              child: DashboardKpiGrid(data: data, venueKind: venueKind),
            ),
            if (perms.can(PermissionIds.navSales)) ...[
              SizedBox(height: isMobile ? 20 : 28),
              if (useWideDashboardLayout)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: RevenueChart(revenueData: data.revenueData),
                    ),
                    SizedBox(width: isMobile ? 16 : 24),
                    Expanded(
                      flex: 1,
                      child: DashboardCategorySales(
                        salesByCategory: data.salesByCategory,
                        screenWidth: screenWidth,
                      ),
                    ),
                  ],
                )
              else ...[
                RevenueChart(revenueData: data.revenueData),
                SizedBox(height: isMobile ? 16 : 24),
                DashboardCategorySales(
                  salesByCategory: data.salesByCategory,
                  screenWidth: screenWidth,
                ),
              ],
              SizedBox(height: isMobile ? 20 : 28),
              if (useWideDashboardLayout)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DashboardTopPerformers(
                        data: data,
                        venueKind: venueKind,
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: DashboardPopularItems(
                        popularItems: data.popularItems,
                      ),
                    ),
                  ],
                )
              else ...[
                DashboardTopPerformers(data: data, venueKind: venueKind),
                SizedBox(height: isMobile ? 16 : 24),
                DashboardPopularItems(popularItems: data.popularItems),
              ],
              SizedBox(height: isMobile ? 16 : 24),
              DashboardRecentOrders(
                recentOrders: data.recentOrders,
                onViewAll: goToSales,
              ),
            ],
            if (modules.tournaments &&
                venueKind.showTournaments &&
                perms.can(PermissionIds.navTournaments)) ...[
              SizedBox(height: isMobile ? 24 : 32),
              DashboardSection(
                eyebrow: 'Gaming',
                title: 'Tournaments',
                subtitle: 'Brackets and registrations',
                child: const Column(
                  children: [
                    DashboardTournamentWidget(),
                    SizedBox(height: 20),
                    DashboardTournamentStatsWidget(),
                  ],
                ),
              ),
            ],
            if (modules.leaderboard &&
                venueKind.showLeaderboard &&
                perms.can(PermissionIds.navLeaderboard)) ...[
              SizedBox(height: isMobile ? 24 : 32),
              DashboardSection(
                eyebrow: 'Gaming',
                title: 'Leaderboard and competition',
                subtitle: 'Player standings and stats',
                child: const Column(
                  children: [
                    DashboardLeaderboardWidget(),
                    SizedBox(height: 20),
                    DashboardLeaderboardStatsWidget(),
                  ],
                ),
              ),
            ],
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
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardProvider);
              },
              child: SingleChildScrollView(
                physics: AppTheme.scrollPhysicsFor(context),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  padding,
                  padding,
                  padding + MediaQuery.paddingOf(context).bottom,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: SizedBox(width: double.infinity, child: content),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () {
        final theme = Theme.of(context);
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            const DashboardSkeleton(),
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading dashboard…',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      error: (error, stack) => DashboardLoadError(error: error),
    );
  }

  /// Opens the session details dialog (bottom sheet on mobile, dialog on desktop).
  void _openSessionDetails(
    BuildContext context,
    WidgetRef ref,
    TableSession session,
    SnookerTable? table,
  ) {
    if (!ref.readResolvedPermissions().can(PermissionIds.navTables)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have access to table sessions.'),
        ),
      );
      return;
    }
    final isMobile = AppTheme.isMobile(context);

    // Fallback table if not found in the map
    final effectiveTable =
        table ??
        SnookerTable(
          id: session.tableId,
          name: session.tableName,
          hourlyRate: session.hourlyRate,
          typeId: ref.read(venueKindProvider).defaultTableTypeId,
          status: TableStatus.occupied,
          tablePurpose: session.tablePurpose,
        );

    if (session.isDining && session.status == SessionStatus.active) {
      Navigator.of(context).push<bool>(
        AppMaterialPageRoute<bool>(
          builder: (_) => DiningSessionScreen(
            session: session,
            table: effectiveTable,
            customerId: session.customerId,
          ),
        ),
      );
      return;
    }

    if (isMobile) {
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => GlassPanel(
            blur: GlassBlur.modal,
            borderRadiusGeometry: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GlassModalSheetDragHandle(),
                Expanded(
                  child: SessionDetailsDialog(
                    session: session,
                    table: effectiveTable,
                    customerId: session.customerId,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SessionDetailsDialog(
          session: session,
          table: effectiveTable,
          customerId: session.customerId,
        ),
      );
    }
  }

  /// Builds a horizontal list of active table sessions for quick kitchen/manager view.
  Widget _buildActiveSessionsSection(
    BuildContext context,
    WidgetRef ref,
    double screenWidth,
    bool isMobile,
  ) {
    final sessionsAsync = ref.watch(activeSessionsProvider);
    final venueKind = ref.watch(venueKindProvider);
    final theme = Theme.of(context);
    final sem = AppSemanticColors.of(context);
    final tables = ref
        .watch(tableListProvider)
        .maybeWhen(
          data: (t) => Map.fromEntries(t.map((e) => MapEntry(e.id, e))),
          orElse: () => <String, SnookerTable>{},
        );
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return sessionsAsync.when(
      data: (sessions) {
        for (final s in sessions) {
          if (s.isBreakExpired) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(tableServiceProvider)
                  .checkAndAutoResumeBreak(session: s);
            });
          }
        }

        if (sessions.isEmpty) {
          return DashboardSection(
            eyebrow: 'Live',
            title: 'Active table sessions',
            subtitle: 'Running tables on the floor',
            child: _buildEmptyActiveSessionsState(theme, isMobile, venueKind.isDiningOrRestaurant),
          );
        }

        // Dining: show linked order total; gaming: table time estimate.
        final totalRunning = sessions.fold<double>(0.0, (acc, s) {
          if (s.isDining) return acc + s.combinedOrderAmount;
          return acc + s.tableCharges;
        });
        final pausedCount = sessions
            .where((s) => s.isGaming && s.isPaused)
            .length;

        return DashboardSection(
          eyebrow: 'Live',
          title: 'Active table sessions',
          subtitle: 'Tap a card for session details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.play_circle_rounded,
                      color: theme.colorScheme.primary,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '${sessions.length} session${sessions.length != 1 ? 's' : ''} running',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                        if (pausedCount > 0) ...[
                          Text(
                            '  •  ',
                            style: TextStyle(
                              color: theme.colorScheme.outline,
                              fontSize: isMobile ? 11 : 12,
                            ),
                          ),
                          Icon(
                            Icons.pause_circle_outline,
                            size: isMobile ? 12 : 14,
                            color: sem.warning,
                          ),
                          SizedBox(width: 2),
                          Text(
                            '$pausedCount paused',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              color: sem.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 14,
                      vertical: isMobile ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withValues(
                        alpha: 0.65,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.tertiary.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Live floor total',
                          style: TextStyle(
                            fontSize: isMobile ? 8 : 10,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          currencyFormat.format(totalRunning),
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 17,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 10 : 14),
              SizedBox(
                height: isMobile ? 190 : 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: AppTheme.scrollPhysicsFor(context),
                  itemCount: sessions.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(width: isMobile ? 10 : 14),
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    final tbl = tables[s.tableId];
                    return ActiveSessionCard(
                      session: s,
                      table: tbl,
                      onTap: () => _openSessionDetails(context, ref, s, tbl),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => DashboardSection(
        eyebrow: 'Live',
        title: 'Active table sessions',
        subtitle: 'Loading floor activity…',
        child: _buildActiveSessionsLoading(context, isMobile),
      ),
      error: (e, _) => DashboardSection(
        eyebrow: 'Live',
        title: 'Active table sessions',
        subtitle: 'Could not load sessions',
        child: Text(
          e.toString(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }

  /// Empty state when no sessions are active (child of [DashboardSection]).
  Widget _buildEmptyActiveSessionsState(ThemeData theme, bool isMobile, [bool isDiningOrRestaurant = false]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sports_esports_outlined,
              size: isMobile ? 32 : 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: isMobile ? 10 : 14),
          Text(
            isDiningOrRestaurant ? 'No seated tables' : 'No active sessions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'All tables are available. Start a new session from the Tables tab.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: isMobile ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Loading skeleton for the active sessions section.
  Widget _buildActiveSessionsLoading(BuildContext context, bool isMobile) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHigh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header skeleton
        Row(
          children: [
            Container(
              width: isMobile ? 32 : 40,
              height: isMobile ? 32 : 40,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isMobile ? 140 : 180,
                  height: isMobile ? 16 : 20,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  width: isMobile ? 100 : 120,
                  height: isMobile ? 10 : 12,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: isMobile ? 10 : 14),
        // Cards skeleton
        SizedBox(
          height: isMobile ? 190 : 220,
          child: Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: i < 2 ? (isMobile ? 10 : 14) : 0,
                  ),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKitchenSummary(
    BuildContext context,
    WidgetRef ref,
    bool isMobile,
  ) {
    final theme = Theme.of(context);
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: tenant
          .cafeOrders()
          .where('status', whereIn: ['pending', 'preparing', 'ready'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return DashboardSection(
            eyebrow: 'Kitchen',
            title: 'Order pipeline',
            subtitle: 'Pending through ready',
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        int pending = 0, preparing = 0, ready = 0;
        for (var d in docs) {
          final status =
              (d.data() as Map<String, dynamic>)['status'] ?? 'pending';
          if (status == 'pending') {
            pending++;
          } else if (status == 'preparing') {
            preparing++;
          } else if (status == 'ready') {
            ready++;
          }
        }

        if (docs.isEmpty) {
          pending = preparing = ready = 0;
        }

        return DashboardSection(
          eyebrow: 'Kitchen',
          title: 'Order pipeline',
          subtitle: 'Counts by ticket status',
          child: Wrap(
            spacing: isMobile ? 12 : 16,
            runSpacing: isMobile ? 12 : 16,
            children: [
              _KitchenStatChip(
                label: 'Pending',
                count: pending,
                color: theme.colorScheme.tertiary,
              ),
              _KitchenStatChip(
                label: 'Preparing',
                count: preparing,
                color: theme.colorScheme.primary,
              ),
              _KitchenStatChip(
                label: 'Ready',
                count: ready,
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KitchenStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _KitchenStatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: isMobile ? 6 : 8),
      label: Text(
        '$label: $count',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
