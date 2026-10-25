import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/session.dart';
import '../../models/table.dart';
import '../../models/cafe_order.dart';
import '../../models/merchandise_order.dart';
import '../../models/venue_ui_config.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/table_provider.dart';
import '../../auth/permission_id.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/screen_header.dart';
import '../../utils/snackbar_helper.dart';
import './session_details_dialog.dart';
import './session_checkout_flow.dart';
import '../admin/restore_sessions_screen.dart';
import '../../utils/firestore_utils.dart';
import '../../providers/tenant_provider.dart';
import '../../firestore/tenant_firestore.dart';
import '../../widgets/glass_modal_bottom_sheet.dart';
import '../../widgets/permission_denied_scaffold.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

enum _RefundFilter { any, refunded, nonRefunded }

class AllSessionsHistoryScreen extends ConsumerStatefulWidget {
  const AllSessionsHistoryScreen({super.key});

  @override
  ConsumerState<AllSessionsHistoryScreen> createState() =>
      _AllSessionsHistoryScreenState();
}

class _AllSessionsHistoryScreenState
    extends ConsumerState<AllSessionsHistoryScreen>
    with SingleTickerProviderStateMixin {
  String _searchTerm = '';
  DateTimeRange? _selectedDateRange;
  SessionStatus? _selectedStatus;
  String? _selectedTableId;
  TablePurpose? _purposeFilter;
  _RefundFilter _refundFilter = _RefundFilter.any;
  bool _showFilters = false;
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  @override
  void initState() {
    super.initState();
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    super.dispose();
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
      if (_showFilters) {
        _filterAnimationController.forward();
      } else {
        _filterAnimationController.reverse();
      }
    });
  }

  List<TableSession> _filterSessions(List<TableSession> sessions) {
    List<TableSession> filtered = List.from(sessions);

    if (_searchTerm.isNotEmpty) {
      filtered = filtered.where((session) {
        final term = _searchTerm.toLowerCase();
        return session.customerName.toLowerCase().contains(term) ||
            session.tableName.toLowerCase().contains(term);
      }).toList();
    }

    if (_selectedDateRange != null) {
      filtered = filtered.where((session) {
        return !session.startTime.isBefore(_selectedDateRange!.start) &&
            !session.startTime.isAfter(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered
          .where((session) => session.status == _selectedStatus)
          .toList();
    }

    if (_selectedTableId != null && _selectedTableId!.isNotEmpty) {
      filtered = filtered
          .where((session) => session.tableId == _selectedTableId)
          .toList();
    }

    if (_purposeFilter != null) {
      filtered = filtered
          .where((session) => session.tablePurpose == _purposeFilter)
          .toList();
    }

    // Apply refund filter
    switch (_refundFilter) {
      case _RefundFilter.refunded:
        filtered = filtered.where((s) => s.isRefunded).toList();
        break;
      case _RefundFilter.nonRefunded:
        filtered = filtered.where((s) => !s.isRefunded).toList();
        break;
      case _RefundFilter.any:
        // no-op
        break;
    }

    return filtered;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.opsSessionsHistory)) {
      return const PermissionDeniedScaffold(
        title: 'Session history',
        message: 'You do not have access to session history.',
      );
    }

    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);
    final allSessionsAsync = ref.watch(allSessionsProvider);
    final allTablesAsync = ref.watch(tableListProvider);
    final defaultTableTypeId = ref.watch(venueKindProvider).defaultTableTypeId;

    return Scaffold(
      body: allSessionsAsync.when(
        data: (sessions) {
          final filteredSessions = _filterSessions(sessions);
          return CustomScrollView(
            physics: AppTheme.scrollPhysicsFor(context),
            slivers: [
              _buildModernAppBar(
                context,
                theme,
                sessions,
                filteredSessions,
                isMobile,
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildBillingLocksBanner(theme, isMobile),
                    _buildAffectedSessionsBanner(theme, isMobile),
                    _buildStatsCards(theme, filteredSessions, isMobile),
                    _buildSearchBar(theme, isMobile),
                    _buildFilterChips(theme, isMobile),
                    SizeTransition(
                      sizeFactor: _filterAnimation,
                      child: _buildAdvancedFilters(
                        theme,
                        allTablesAsync.asData?.value ?? [],
                        isMobile,
                      ),
                    ),
                  ],
                ),
              ),
              filteredSessions.isEmpty
                  ? SliverFillRemaining(
                      child: EmptyStateWidget(
                        icon: Icons.history_toggle_off_outlined,
                        message: sessions.isEmpty
                            ? 'No sessions recorded yet.'
                            : 'No sessions match your filters.',
                        details:
                            'Try adjusting your search or filter criteria.',
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.all(
                        isMobile ? 12 : AppTheme.kSpacingMedium,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final session = filteredSessions[index];
                          final tableForDialog =
                              allTablesAsync.asData?.value.firstWhere(
                                (t) => t.id == session.tableId,
                                orElse: () => SnookerTable(
                                  id: session.tableId,
                                  name: session.tableName,
                                  typeId: defaultTableTypeId,
                                  status: TableStatus.available,
                                  hourlyRate: session.hourlyRate,
                                  description: '',
                                  tablePurpose: session.tablePurpose,
                                ),
                              ) ??
                              SnookerTable(
                                id: session.tableId,
                                name: session.tableName,
                                typeId: defaultTableTypeId,
                                status: TableStatus.available,
                                hourlyRate: session.hourlyRate,
                                description: '',
                                tablePurpose: session.tablePurpose,
                              );

                          return _AnimatedSessionCard(
                            index: index,
                            child: _buildEnhancedSessionCard(
                              context,
                              session,
                              theme,
                              tableForDialog,
                              isMobile,
                            ),
                          );
                        }, childCount: filteredSessions.length),
                      ),
                    ),
            ],
          );
        },
        loading: () => _buildLoadingSkeleton(context, isMobile),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading sessions',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context, bool isMobile) {
    return CustomScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      slivers: [
        SliverAppBar(
          expandedHeight: isMobile ? 80 : 120,
          pinned: true,
          flexibleSpace: const ShimmerSkeleton(height: 120, borderRadius: 0),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                // Stats skeleton
                Row(
                  children: List.generate(
                    isMobile ? 3 : 4,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 4 : 6,
                        ),
                        child: ShimmerSkeleton(
                          height: isMobile ? 70 : 90,
                          borderRadius: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                // Search bar skeleton
                ShimmerSkeleton(height: isMobile ? 44 : 52, borderRadius: 12),
                SizedBox(height: isMobile ? 12 : 16),
                // Filter chips skeleton
                Row(
                  children: List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ShimmerSkeleton(
                        width: 80,
                        height: 32,
                        borderRadius: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _SessionCardSkeleton(index: index, isMobile: isMobile),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernAppBar(
    BuildContext context,
    ThemeData theme,
    List<TableSession> allSessions,
    List<TableSession> filteredSessions,
    bool isMobile,
  ) {
    final venueKind = ref.watch(venueKindProvider);
    return SliverToBoxAdapter(
      child: ScreenHeader(
        title: venueKind.sessionHistoryTitle,
        icon: Icons.history_rounded,
        subtitle: filteredSessions.length != allSessions.length
            ? '${filteredSessions.length} of ${allSessions.length} sessions'
            : '${allSessions.length} sessions',
        actions: [
          ScreenHeaderAction(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearBillingLock(
    BuildContext context,
    TableSession session,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear billing lock?'),
        content: Text(
          'Session for ${session.customerName} on ${session.tableName} is still '
          'marked billing in progress. Clear only if checkout failed or the UI is stuck.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear lock'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final tenant = ref.read(tenantRefProvider);
    final ok = await setSessionBillingInProgress(tenant, session.id, false);
    if (!context.mounted) return;
    if (ok) {
      context.showSuccessSnackbar('Billing lock cleared');
    } else {
      context.showErrorSnackbar('Could not clear billing lock');
    }
  }

  Widget _buildBillingLocksBanner(ThemeData theme, bool isMobile) {
    final canAdmin = ref.watchResolvedPermissions().can(
      PermissionIds.opsSessionAdmin,
    );
    if (!canAdmin) return const SizedBox.shrink();

    final locksAsync = ref.watch(billingLockedSessionsProvider);
    final dateFmt = DateFormat('MMM d, HH:mm');

    return locksAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsets.fromLTRB(
            isMobile ? 12 : 16,
            isMobile ? 12 : 16,
            isMobile ? 12 : 16,
            0,
          ),
          padding: EdgeInsets.all(isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
            border: Border.all(
              color: theme.colorScheme.error.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    color: theme.colorScheme.onErrorContainer,
                    size: isMobile ? 22 : 24,
                  ),
                  SizedBox(width: isMobile ? 8 : 10),
                  Expanded(
                    child: Text(
                      'Billing in progress (${sessions.length})',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 13 : 15,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isMobile) ...[
                const SizedBox(height: 4),
                Text(
                  'These sessions may be stuck after a failed checkout. Clear the '
                  'lock only if no payment is still being processed.',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer.withValues(
                      alpha: 0.9,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ...sessions.take(6).map(
                (s) => Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _confirmClearBillingLock(context, s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.customerName,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isMobile ? 13 : 14,
                                  ),
                                ),
                                Text(
                                  '${s.tableName} · ${dateFmt.format(s.startTime)}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer
                                        .withValues(alpha: 0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Clear',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (sessions.length > 6)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '…and ${sessions.length - 6} more (tap a row to clear)',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildAffectedSessionsBanner(ThemeData theme, bool isMobile) {
    final canSessionAdmin = ref.watchResolvedPermissions().can(
      PermissionIds.opsSessionAdmin,
    );

    if (!canSessionAdmin) return const SizedBox.shrink();

    final orphanSessionsAsync = ref.watch(orphanCancelledSessionsProvider);

    return orphanSessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              AppMaterialPageRoute<void>(
                builder: (_) => const RestoreSessionsScreen(),
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.fromLTRB(
              isMobile ? 12 : 16,
              isMobile ? 12 : 16,
              isMobile ? 12 : 16,
              0,
            ),
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.tertiary,
                  theme.colorScheme.tertiary.withValues(alpha: 0.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onTertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.onTertiary,
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sessions.length} Session(s) Need Attention',
                        style: TextStyle(
                          color: theme.colorScheme.onTertiary,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 13 : 15,
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Tap to mark them as completed for sales tracking',
                          style: TextStyle(
                            color: theme.colorScheme.onTertiary.withValues(
                              alpha: 0.88,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: theme.colorScheme.onTertiary.withValues(alpha: 0.75),
                  size: isMobile ? 16 : 18,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatsCards(
    ThemeData theme,
    List<TableSession> sessions,
    bool isMobile,
  ) {
    final totalSessions = sessions.length;
    final completedSessions = sessions
        .where((s) => s.status == SessionStatus.completed)
        .length;
    final totalRevenue = sessions
        .where((s) => s.status == SessionStatus.completed && !s.isRefunded)
        .fold(0.0, (sum, s) => sum + (s.totalBillAmount ?? 0.0));
    final refundedSessions = sessions.where((s) => s.isRefunded).length;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : AppTheme.kSpacingMedium),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              theme,
              Icons.history_outlined,
              isMobile ? 'Total' : 'Total Sessions',
              totalSessions.toString(),
              theme.colorScheme.primary,
              isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 6 : AppTheme.kSpacingSmall),
          Expanded(
            child: _buildStatCard(
              theme,
              Icons.check_circle_outline,
              isMobile ? 'Done' : 'Completed',
              completedSessions.toString(),
              theme.colorScheme.tertiary,
              isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 6 : AppTheme.kSpacingSmall),
          Expanded(
            child: _buildStatCard(
              theme,
              Icons.currency_rupee,
              'Revenue',
              isMobile
                  ? '₹${_formatCompactNumber(totalRevenue)}'
                  : '₹${totalRevenue.toStringAsFixed(0)}',
              theme.colorScheme.secondary,
              isMobile,
            ),
          ),
          if (refundedSessions > 0) ...[
            SizedBox(width: isMobile ? 6 : AppTheme.kSpacingSmall),
            Expanded(
              child: _buildStatCard(
                theme,
                Icons.reply_all_outlined,
                isMobile ? 'Refund' : 'Refunded',
                refundedSessions.toString(),
                theme.colorScheme.error,
                isMobile,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCompactNumber(double value) {
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildStatCard(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : AppTheme.kSpacingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(26), color.withAlpha(13)],
        ),
        borderRadius: BorderRadius.circular(
          isMobile ? 10 : AppTheme.kBorderRadiusMedium,
        ),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isMobile ? 20 : 24),
          SizedBox(height: isMobile ? 4 : AppTheme.kSpacingSmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: isMobile ? 16 : 20,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
              fontSize: isMobile ? 10 : 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : AppTheme.kSpacingMedium,
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: isMobile
              ? 'Search sessions...'
              : 'Search by Customer or Table Name...',
          hintStyle: TextStyle(fontSize: isMobile ? 14 : 15),
          prefixIcon: Icon(Icons.search_rounded, size: isMobile ? 22 : 24),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              isMobile ? 10 : AppTheme.kBorderRadiusMedium,
            ),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : AppTheme.kSpacingMedium,
            vertical: isMobile ? 10 : AppTheme.kSpacingSmall,
          ),
          isDense: isMobile,
        ),
        style: TextStyle(fontSize: isMobile ? 14 : 15),
        onChanged: (value) => setState(() => _searchTerm = value),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, bool isMobile) {
    final hasActiveFilters =
        _selectedDateRange != null ||
        _selectedStatus != null ||
        _selectedTableId != null ||
        _purposeFilter != null ||
        _refundFilter != _RefundFilter.any;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 10 : AppTheme.kSpacingMedium),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: AppTheme.scrollPhysicsFor(context),
        child: Row(
          children: [
            FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showFilters ? Icons.expand_less : Icons.filter_list,
                    size: isMobile ? 16 : 18,
                  ),
                  SizedBox(width: isMobile ? 4 : 6),
                  Text(
                    'Filters',
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
                  if (hasActiveFilters) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              selected: _showFilters,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                _toggleFilters();
              },
              selectedColor: theme.colorScheme.primaryContainer,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
            ),
            if (_selectedDateRange != null) ...[
              SizedBox(width: isMobile ? 6 : 8),
              Chip(
                avatar: Icon(Icons.calendar_today, size: isMobile ? 14 : 16),
                label: Text(
                  isMobile
                      ? '${DateFormat.Md().format(_selectedDateRange!.start)} - ${DateFormat.Md().format(_selectedDateRange!.end)}'
                      : '${DateFormat.MMMd().format(_selectedDateRange!.start)} - ${DateFormat.MMMd().format(_selectedDateRange!.end)}',
                  style: TextStyle(fontSize: isMobile ? 11 : 12),
                ),
                deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
                onDeleted: () => setState(() => _selectedDateRange = null),
                backgroundColor: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.75),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              ),
            ],
            if (_selectedStatus != null) ...[
              SizedBox(width: isMobile ? 6 : 8),
              Chip(
                avatar: Icon(Icons.filter_alt, size: isMobile ? 14 : 16),
                label: Text(
                  _selectedStatus.toString().split('.').last.toUpperCase(),
                  style: TextStyle(fontSize: isMobile ? 11 : 12),
                ),
                deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
                onDeleted: () => setState(() => _selectedStatus = null),
                backgroundColor: theme.colorScheme.secondaryContainer
                    .withValues(alpha: 0.75),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              ),
            ],
            if (_purposeFilter != null) ...[
              SizedBox(width: isMobile ? 6 : 8),
              Chip(
                avatar: Icon(Icons.restaurant_menu, size: isMobile ? 14 : 16),
                label: Text(
                  _purposeFilter == TablePurpose.dining ? 'DINING' : 'GAMING',
                  style: TextStyle(fontSize: isMobile ? 11 : 12),
                ),
                deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
                onDeleted: () => setState(() => _purposeFilter = null),
                backgroundColor: theme.colorScheme.tertiaryContainer
                    .withValues(alpha: 0.75),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              ),
            ],
            if (_refundFilter != _RefundFilter.any) ...[
              SizedBox(width: isMobile ? 6 : 8),
              Chip(
                avatar: Icon(Icons.reply_all, size: isMobile ? 14 : 16),
                label: Text(
                  _refundFilter == _RefundFilter.refunded
                      ? 'Refunded'
                      : 'Non-Refunded',
                  style: TextStyle(fontSize: isMobile ? 11 : 12),
                ),
                deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
                onDeleted: () =>
                    setState(() => _refundFilter = _RefundFilter.any),
                backgroundColor:
                    theme.colorScheme.errorContainer.withValues(alpha: 0.75),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              ),
            ],
            if (hasActiveFilters) ...[
              SizedBox(width: isMobile ? 6 : 8),
              ActionChip(
                avatar: Icon(Icons.clear_all, size: isMobile ? 14 : 16),
                label: Text(
                  'Clear',
                  style: TextStyle(fontSize: isMobile ? 11 : 12),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedDateRange = null;
                    _selectedStatus = null;
                    _selectedTableId = null;
                    _purposeFilter = null;
                    _refundFilter = _RefundFilter.any;
                  });
                },
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                side: BorderSide(color: theme.colorScheme.outline.withValues(
                  alpha: 0.35,
                )),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters(
    ThemeData theme,
    List<SnookerTable> allTables,
    bool isMobile,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : AppTheme.kSpacingMedium,
      ),
      padding: EdgeInsets.all(isMobile ? 12 : AppTheme.kSpacingMedium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
        borderRadius: BorderRadius.circular(
          isMobile ? 10 : AppTheme.kBorderRadiusMedium,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(
                    Icons.calendar_today_rounded,
                    size: isMobile ? 18 : 20,
                  ),
                  label: Text(
                    _selectedDateRange == null
                        ? (isMobile ? 'Date Range' : 'Select Date Range')
                        : '${DateFormat.Md().format(_selectedDateRange!.start)} - ${DateFormat.Md().format(_selectedDateRange!.end)}',
                    style: TextStyle(fontSize: isMobile ? 12 : 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _selectDateRange(context),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : AppTheme.kSpacingSmall),
          if (isMobile)
            // Stack filters vertically on mobile
            Column(
              children: [
                _buildStatusDropdown(theme, isMobile),
                const SizedBox(height: 8),
                _buildTableDropdown(theme, allTables, isMobile),
                if (ref.watch(venueKindProvider).showPurposeFilter) ...[
                  const SizedBox(height: 8),
                  _buildPurposeDropdown(theme, isMobile),
                ],
                const SizedBox(height: 8),
                _buildRefundDropdown(theme, isMobile),
              ],
            )
          else
            // Row layout on desktop/tablet
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatusDropdown(theme, isMobile)),
                    const SizedBox(width: AppTheme.kSpacingSmall),
                    Expanded(
                      child: _buildTableDropdown(theme, allTables, isMobile),
                    ),
                  ],
                ),
                if (ref.watch(venueKindProvider).showPurposeFilter) ...[
                  const SizedBox(height: AppTheme.kSpacingSmall),
                  _buildPurposeDropdown(theme, isMobile),
                ],
                const SizedBox(height: AppTheme.kSpacingSmall),
                _buildRefundDropdown(theme, isMobile),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(ThemeData theme, bool isMobile) {
    final statusItems = <DropdownMenuItem<SessionStatus?>>[
      const DropdownMenuItem(value: null, child: Text('All')),
      ...SessionStatus.values.map((status) {
        return DropdownMenuItem(
          value: status,
          child: Text(status.toString().split('.').last.toUpperCase()),
        );
      }),
    ];
    return DropdownButtonFormField<SessionStatus?>(
      initialValue: _selectedStatus,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Status',
        prefixIcon: Icon(Icons.filter_list_rounded, size: isMobile ? 18 : 20),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            isMobile ? 8 : AppTheme.kBorderRadiusSmall,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : AppTheme.kSpacingSmall,
          vertical: isMobile ? 8 : AppTheme.kSpacingSmall,
        ),
        isDense: isMobile,
      ),
      style: TextStyle(
        fontSize: isMobile ? 13 : 14,
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      items: statusItems,
      selectedItemBuilder: (context) =>
          AppTheme.dropdownSelectedItemBuilders(theme, statusItems),
      onChanged: (value) => setState(() => _selectedStatus = value),
    );
  }

  Widget _buildTableDropdown(
    ThemeData theme,
    List<SnookerTable> allTables,
    bool isMobile,
  ) {
    final tableItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('All')),
      ...allTables.map((table) {
        return DropdownMenuItem(
          value: table.id,
          child: Text(table.name, overflow: TextOverflow.ellipsis),
        );
      }),
    ];
    return DropdownButtonFormField<String?>(
      initialValue: _selectedTableId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Table',
        prefixIcon: Icon(
          Icons.table_restaurant_rounded,
          size: isMobile ? 18 : 20,
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            isMobile ? 8 : AppTheme.kBorderRadiusSmall,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : AppTheme.kSpacingSmall,
          vertical: isMobile ? 8 : AppTheme.kSpacingSmall,
        ),
        isDense: isMobile,
      ),
      style: TextStyle(
        fontSize: isMobile ? 13 : 14,
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      items: tableItems,
      selectedItemBuilder: (context) =>
          AppTheme.dropdownSelectedItemBuilders(theme, tableItems),
      onChanged: (value) => setState(() => _selectedTableId = value),
    );
  }

  Widget _buildPurposeDropdown(ThemeData theme, bool isMobile) {
    final purposeItems = <DropdownMenuItem<TablePurpose?>>[
      const DropdownMenuItem(value: null, child: Text('All')),
      ...TablePurpose.values.map((p) {
        return DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()));
      }),
    ];
    return DropdownButtonFormField<TablePurpose?>(
      initialValue: _purposeFilter,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Purpose',
        prefixIcon: Icon(
          Icons.restaurant_menu_outlined,
          size: isMobile ? 18 : 20,
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            isMobile ? 8 : AppTheme.kBorderRadiusSmall,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : AppTheme.kSpacingSmall,
          vertical: isMobile ? 8 : AppTheme.kSpacingSmall,
        ),
        isDense: isMobile,
      ),
      style: TextStyle(
        fontSize: isMobile ? 13 : 14,
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      items: purposeItems,
      selectedItemBuilder: (context) =>
          AppTheme.dropdownSelectedItemBuilders(theme, purposeItems),
      onChanged: (value) => setState(() => _purposeFilter = value),
    );
  }

  Widget _buildRefundDropdown(ThemeData theme, bool isMobile) {
    const refundItems = <DropdownMenuItem<_RefundFilter>>[
      DropdownMenuItem(value: _RefundFilter.any, child: Text('All')),
      DropdownMenuItem(
        value: _RefundFilter.refunded,
        child: Text('Refunded'),
      ),
      DropdownMenuItem(
        value: _RefundFilter.nonRefunded,
        child: Text('Non-Refunded'),
      ),
    ];
    return DropdownButtonFormField<_RefundFilter>(
      initialValue: _refundFilter,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Refund Status',
        prefixIcon: Icon(Icons.reply_all_outlined, size: isMobile ? 18 : 20),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            isMobile ? 8 : AppTheme.kBorderRadiusSmall,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : AppTheme.kSpacingSmall,
          vertical: isMobile ? 8 : AppTheme.kSpacingSmall,
        ),
        isDense: isMobile,
      ),
      style: TextStyle(
        fontSize: isMobile ? 13 : 14,
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      items: refundItems,
      selectedItemBuilder: (context) =>
          AppTheme.dropdownSelectedItemBuilders(theme, refundItems),
      onChanged: (v) => setState(() => _refundFilter = v ?? _RefundFilter.any),
    );
  }

  Widget _buildEnhancedSessionCard(
    BuildContext context,
    TableSession session,
    ThemeData theme,
    SnookerTable table,
    bool isMobile,
  ) {
    final duration = session.duration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    String statusText;
    Color statusColor;
    IconData statusIcon;
    Color cardGradientStart;
    Color cardGradientEnd;

    final cs = theme.colorScheme;

    if (session.isRefunded) {
      statusText = 'REFUNDED';
      statusColor = cs.error;
      statusIcon = Icons.reply_all_outlined;
      cardGradientStart = cs.errorContainer.withValues(alpha: 0.95);
      cardGradientEnd = cs.errorContainer.withValues(alpha: 0.45);
    } else {
      statusText = session.status.toString().split('.').last.toUpperCase();
      switch (session.status) {
        case SessionStatus.completed:
          statusColor = cs.tertiary;
          statusIcon = Icons.check_circle;
          cardGradientStart = cs.tertiaryContainer.withValues(alpha: 0.92);
          cardGradientEnd = cs.tertiaryContainer.withValues(alpha: 0.38);
          break;
        case SessionStatus.cancelled:
          statusColor = cs.secondary;
          statusIcon = Icons.cancel;
          cardGradientStart = cs.secondaryContainer.withValues(alpha: 0.88);
          cardGradientEnd = cs.secondaryContainer.withValues(alpha: 0.42);
          break;
        case SessionStatus.active:
          statusColor = cs.primary;
          statusIcon = Icons.timer;
          cardGradientStart = cs.primaryContainer.withValues(alpha: 0.88);
          cardGradientEnd = cs.primaryContainer.withValues(alpha: 0.4);
          break;
      }
    }

    final hasCafeOrders = session.hasCafeBillActivity;
    final hasMerchOrders = session.hasMerchandiseBillActivity;
    final int linkedOrderCount = session.linkedOrderDocumentCount;
    final bool showOrderCountBadge =
        linkedOrderCount > 0 || hasCafeOrders || hasMerchOrders;
    final String orderCountLabel = linkedOrderCount > 0
        ? '$linkedOrderCount Order${linkedOrderCount > 1 ? 's' : ''}'
        : 'Orders';

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : AppTheme.kSpacingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardGradientStart, cardGradientEnd],
        ),
        borderRadius: BorderRadius.circular(
          isMobile ? 12 : AppTheme.kBorderRadiusMedium,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withAlpha(51),
            blurRadius: isMobile ? 6 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showSessionDetails(context, session, table, isMobile);
          },
          borderRadius: BorderRadius.circular(
            isMobile ? 12 : AppTheme.kBorderRadiusMedium,
          ),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 12 : AppTheme.kSpacingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                isMobile ? 12 : AppTheme.kBorderRadiusMedium,
              ),
              border: Border.all(
                color: statusColor.withAlpha(77),
                width: isMobile ? 1.5 : 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row - Status & Amount
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 6 : 8),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: isMobile ? 20 : 24,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : AppTheme.kSpacingSmall),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                          Text(
                            session.formattedStartTime,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(153),
                              fontSize: isMobile ? 11 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (session.isDining) ...[
                      SizedBox(width: isMobile ? 6 : 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 5,
                        ),
                        decoration: BoxDecoration(
                          color: cs.tertiaryContainer.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: cs.tertiary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: isMobile ? 14 : 16,
                              color: cs.onTertiaryContainer,
                            ),
                            SizedBox(width: isMobile ? 4 : 6),
                            Text(
                              'DINING',
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 11,
                                fontWeight: FontWeight.w700,
                                color: cs.onTertiaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (session.status == SessionStatus.completed &&
                        session.totalAmount != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 10 : 12,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(
                            isMobile ? 16 : 20,
                          ),
                          border: Border.all(
                            color: cs.secondary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '₹${session.totalAmount!.toStringAsFixed(0)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                      ),
                  ],
                ),

                // Session ID Badge (new)
                Padding(
                  padding: EdgeInsets.only(top: isMobile ? 8 : 10),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tag_rounded,
                              size: isMobile ? 12 : 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Session: ${_truncateId(session.id)}',
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 11,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showOrderCountBadge) ...[
                        SizedBox(width: isMobile ? 6 : 8),
                        Tooltip(
                          message:
                              linkedOrderCount == 0 &&
                                  (hasCafeOrders || hasMerchOrders)
                              ? 'Order IDs may be missing — open session for details'
                              : 'Orders on this session',
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 10,
                              vertical: isMobile ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: isMobile ? 12 : 14,
                                  color: cs.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  orderCountLabel,
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 11,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Divider(
                  height: isMobile ? 16 : AppTheme.kSpacingMedium,
                  thickness: 1,
                  color: AppTheme.subtleDividerColor(theme),
                ),

                // Info Row 1 - Table & Customer
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        theme,
                        Icons.table_restaurant,
                        session.tableName,
                        theme.colorScheme.secondary,
                        isMobile,
                      ),
                    ),
                    SizedBox(width: isMobile ? 6 : AppTheme.kSpacingSmall),
                    Expanded(
                      child: _buildInfoChip(
                        theme,
                        Icons.person,
                        session.customerName,
                        theme.colorScheme.primary,
                        isMobile,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 6 : AppTheme.kSpacingSmall),

                // Info Row 2 - Duration & Payment
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        theme,
                        Icons.timer,
                        '${hours}h ${minutes}m',
                        theme.colorScheme.tertiary,
                        isMobile,
                      ),
                    ),
                    SizedBox(width: isMobile ? 6 : AppTheme.kSpacingSmall),
                    Expanded(
                      child: _buildInfoChip(
                        theme,
                        Icons.payment,
                        session.paymentMode
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase(),
                        theme.colorScheme.outline,
                        isMobile,
                      ),
                    ),
                  ],
                ),

                // Order IDs Section (New)
                if (hasCafeOrders || hasMerchOrders) ...[
                  SizedBox(height: isMobile ? 8 : AppTheme.kSpacingSmall),
                  _buildOrderIdsSection(theme, session, isMobile),
                ],

                // Credits Used
                if (session.creditsUsed != null &&
                    session.creditsUsed! > 0) ...[
                  SizedBox(height: isMobile ? 8 : AppTheme.kSpacingSmall),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 12,
                      vertical: isMobile ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.32,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: isMobile ? 14 : 16,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Credits Used: ₹${session.creditsUsed!.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Refund Details
                if (session.isRefunded) ...[
                  SizedBox(height: isMobile ? 8 : AppTheme.kSpacingSmall),
                  _buildRefundDetailsCard(theme, session, isMobile),
                ],

                // Order-level refunds
                if (session.status == SessionStatus.completed)
                  _buildOrderRefundsSummary(session.id, isMobile),

                // Fix orphan session button
                if (session.status == SessionStatus.cancelled &&
                    session.data['cancelledReason'] ==
                        'auto_cleanup_orphaned_session')
                  _buildFixOrphanSessionButton(theme, session, isMobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  void _showSessionDetails(
    BuildContext context,
    TableSession session,
    SnookerTable table,
    bool isMobile,
  ) {
    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => GlassPanel(
            blur: GlassBlur.modal,
            borderRadiusGeometry: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const GlassModalSheetDragHandle(),
                Expanded(
                  child: SessionDetailsDialog(
                    session: session,
                    table: table,
                    customerId: session.customerId,
                    isReadOnly: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SessionDetailsDialog(
          session: session,
          table: table,
          customerId: session.customerId,
          isReadOnly: true,
        ),
      );
    }
  }

  Widget _buildOrderIdsSection(
    ThemeData theme,
    TableSession session,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: isMobile ? 14 : 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Order IDs',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Wrap(
            spacing: isMobile ? 4 : 6,
            runSpacing: isMobile ? 4 : 6,
            children: [
              // Cafe Orders
              ...session.cafeOrderIds.map(
                (orderId) => _buildOrderIdChip(
                  theme,
                  orderId,
                  Icons.local_cafe_rounded,
                  theme.colorScheme.tertiary,
                  'Cafe',
                  isMobile,
                ),
              ),
              // Merchandise Orders
              ...session.merchandiseOrderIds.map(
                (orderId) => _buildOrderIdChip(
                  theme,
                  orderId,
                  Icons.shopping_bag_rounded,
                  theme.colorScheme.secondary,
                  'Merch',
                  isMobile,
                ),
              ),
              if (session.cafeOrderIds.isEmpty &&
                  session.merchandiseOrderIds.isEmpty &&
                  (session.hasCafeBillActivity ||
                      session.hasMerchandiseBillActivity))
                Text(
                  'No order IDs on this session document. Linked orders use sessionId in Firestore — open the session to view them.',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderIdChip(
    ThemeData theme,
    String orderId,
    IconData icon,
    Color color,
    String type,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: isMobile ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            '#${_truncateId(orderId)}',
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    ThemeData theme,
    IconData icon,
    String label,
    Color color,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 12,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 14 : 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color.withAlpha(230),
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRefundsSummary(String sessionId, bool isMobile) {
    final tenant = ref.read(tenantRefProvider);
    return FutureBuilder<List<_OrderRefundInfo>>(
      future: tenant == null
          ? Future.value(<_OrderRefundInfo>[])
          : _fetchRefundedOrdersForSession(tenant, sessionId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final refundedOrders = snapshot.data!;
        final theme = Theme.of(context);

        final cs = theme.colorScheme;
        return Container(
          margin: EdgeInsets.only(top: isMobile ? 8 : AppTheme.kSpacingSmall),
          padding: EdgeInsets.all(isMobile ? 8 : 10),
          decoration: BoxDecoration(
            color: cs.tertiaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
            border: Border.all(
              color: cs.tertiary.withValues(alpha: 0.32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: isMobile ? 12 : 14,
                    color: cs.onTertiaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Order Refunds',
                    style: TextStyle(
                      color: cs.onTertiaryContainer,
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 4 : 6),
              ...refundedOrders.map(
                (order) => _buildOrderRefundRow(theme, order, isMobile),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<_OrderRefundInfo>> _fetchRefundedOrdersForSession(
    TenantRef tenant,
    String sessionId,
  ) async {
    final List<_OrderRefundInfo> refundedOrders = [];

    // Fetch refunded cafe orders
    final cafeSnap = await tenant
        .cafeOrders()
        .where('sessionId', isEqualTo: sessionId)
        .get();

    for (final doc in cafeSnap.docs) {
      final order = CafeOrder.fromFirestore(doc);
      if (order.refundHistory.isNotEmpty) {
        double totalRefunded = 0;
        double creditsRefunded = 0;
        for (final refund in order.refundHistory) {
          totalRefunded +=
              parseFirestoreDoubleOrNull(refund['refundAmount']) ??
              parseFirestoreDoubleOrNull(refund['amount']) ??
              0;
          creditsRefunded += parseFirestoreDouble(refund['creditsRefunded']);
        }
        refundedOrders.add(
          _OrderRefundInfo(
            orderId: order.id,
            type: 'Cafe',
            refundAmount: totalRefunded,
            creditsRefunded: creditsRefunded,
            items: order.refundHistory
                .expand((r) => (r['items'] as List<dynamic>?) ?? [])
                .map((i) => '${i['name']} x${i['quantity']}')
                .toList(),
          ),
        );
      }
    }

    // Fetch refunded merchandise orders
    final merchSnap = await tenant
        .merchandiseOrders()
        .where('sessionId', isEqualTo: sessionId)
        .get();

    for (final doc in merchSnap.docs) {
      final order = MerchandiseOrder.fromFirestore(doc);
      if (order.refundHistory != null && order.refundHistory!.isNotEmpty) {
        double totalRefunded = 0;
        double creditsRefunded = 0;
        for (final refund in order.refundHistory!) {
          totalRefunded +=
              parseFirestoreDoubleOrNull(refund['refundAmount']) ??
              parseFirestoreDoubleOrNull(refund['amount']) ??
              0;
          creditsRefunded += parseFirestoreDouble(refund['creditsRefunded']);
        }
        refundedOrders.add(
          _OrderRefundInfo(
            orderId: order.id,
            type: 'Merchandise',
            refundAmount: totalRefunded,
            creditsRefunded: creditsRefunded,
            items: order.refundHistory!
                .expand((r) => (r['items'] as List<dynamic>?) ?? [])
                .map((i) => '${i['name']} x${i['quantity']}')
                .toList(),
          ),
        );
      }
    }

    return refundedOrders;
  }

  Widget _buildOrderRefundRow(
    ThemeData theme,
    _OrderRefundInfo order,
    bool isMobile,
  ) {
    final cs = theme.colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 3 : 4),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      order.type == 'Cafe'
                          ? Icons.local_cafe
                          : Icons.shopping_bag,
                      size: isMobile ? 10 : 12,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${order.type} #${_truncateId(order.orderId)}',
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${order.refundAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: isMobile ? 10 : 11,
                  fontWeight: FontWeight.bold,
                  color: cs.error,
                ),
              ),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              order.items.join(', '),
              style: TextStyle(
                fontSize: isMobile ? 9 : 10,
                color: cs.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (order.creditsRefunded > 0) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: isMobile ? 9 : 10,
                  color: cs.secondary,
                ),
                const SizedBox(width: 2),
                Text(
                  'Credits: ₹${order.creditsRefunded.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: isMobile ? 9 : 10,
                    color: cs.secondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFixOrphanSessionButton(
    ThemeData theme,
    TableSession session,
    bool isMobile,
  ) {
    // Check if user is admin
    final canSessionAdmin = ref.watchResolvedPermissions().can(
      PermissionIds.opsSessionAdmin,
    );

    if (!canSessionAdmin) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: isMobile ? 8 : AppTheme.kSpacingSmall),
      child: ElevatedButton.icon(
        onPressed: () async {
          await HapticFeedback.mediumImpact();
          if (!mounted) return;
          try {
            await ref
                .read(tableServiceProvider)
                .markOrphanCancelledAsCompleted(session: session);
            if (mounted) {
              context.showSuccessSnackbar(
                'Session marked as completed! Sales are now tracked.',
              );
            }
          } catch (e) {
            if (mounted) {
              context.showErrorSnackbar('Failed: ${e.toString()}');
            }
          }
        },
        icon: Icon(Icons.check_circle_outline, size: isMobile ? 16 : 18),
        label: Text(
          isMobile ? 'Complete' : 'Mark as Completed',
          style: TextStyle(fontSize: isMobile ? 12 : 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 8 : 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
          ),
        ),
      ),
    );
  }

  Widget _buildRefundDetailsCard(
    ThemeData theme,
    TableSession session,
    bool isMobile,
  ) {
    final refundAmount = session.refundAmount ?? 0.0;
    final creditsRefunded = session.creditsRefunded ?? 0.0;
    final nonCreditsRefunded = refundAmount - creditsRefunded;
    final refundedBy = session.refundedByName ?? 'Staff';
    final refundedAt = session.refundedAt;

    final cs = theme.colorScheme;
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
        border: Border.all(
          color: cs.error.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reply_all_outlined,
                size: isMobile ? 14 : 16,
                color: cs.onErrorContainer,
              ),
              const SizedBox(width: 6),
              Text(
                'Refund Details',
                style: TextStyle(
                  color: cs.onErrorContainer,
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Refunded:',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: cs.onErrorContainer.withValues(alpha: 0.92),
                ),
              ),
              Text(
                '₹${refundAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onErrorContainer,
                  fontSize: isMobile ? 12 : 13,
                ),
              ),
            ],
          ),
          if (creditsRefunded > 0) ...[
            SizedBox(height: isMobile ? 3 : 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: isMobile ? 10 : 12,
                      color: cs.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Credits Returned:',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        color: cs.secondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${creditsRefunded.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.secondary,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
              ],
            ),
          ],
          if (nonCreditsRefunded > 0.01) ...[
            SizedBox(height: isMobile ? 3 : 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cash/UPI:',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: cs.onErrorContainer.withValues(alpha: 0.88),
                  ),
                ),
                Text(
                  '₹${nonCreditsRefunded.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: cs.onErrorContainer,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: isMobile ? 4 : 6),
          Text(
            'By $refundedBy${refundedAt != null ? ' · ${DateFormat.yMd().add_jm().format(refundedAt)}' : ''}',
            style: TextStyle(
              fontSize: isMobile ? 9 : 10,
              fontStyle: FontStyle.italic,
              color: cs.onErrorContainer.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated wrapper for session cards with staggered entry
class _AnimatedSessionCard extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedSessionCard({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index.clamp(0, 10) * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Skeleton loader for session cards
class _SessionCardSkeleton extends StatelessWidget {
  final int index;
  final bool isMobile;

  const _SessionCardSkeleton({required this.index, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 80)),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerSkeleton(
                  width: isMobile ? 36 : 40,
                  height: isMobile ? 36 : 40,
                  borderRadius: 8,
                ),
                SizedBox(width: isMobile ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerSkeleton.text(
                        width: 80,
                        height: isMobile ? 14 : 16,
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      ShimmerSkeleton.text(
                        width: 120,
                        height: isMobile ? 10 : 12,
                      ),
                    ],
                  ),
                ),
                ShimmerSkeleton(
                  width: isMobile ? 60 : 80,
                  height: isMobile ? 28 : 32,
                  borderRadius: 16,
                ),
              ],
            ),
            SizedBox(height: isMobile ? 10 : 12),
            Row(
              children: [
                ShimmerSkeleton(
                  width: isMobile ? 100 : 120,
                  height: isMobile ? 20 : 24,
                  borderRadius: 6,
                ),
                SizedBox(width: isMobile ? 8 : 10),
                ShimmerSkeleton(
                  width: isMobile ? 80 : 100,
                  height: isMobile ? 20 : 24,
                  borderRadius: 6,
                ),
              ],
            ),
            SizedBox(height: isMobile ? 8 : 10),
            Row(
              children: [
                Expanded(
                  child: ShimmerSkeleton(
                    height: isMobile ? 32 : 36,
                    borderRadius: 8,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: ShimmerSkeleton(
                    height: isMobile ? 32 : 36,
                    borderRadius: 8,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Row(
              children: [
                Expanded(
                  child: ShimmerSkeleton(
                    height: isMobile ? 32 : 36,
                    borderRadius: 8,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: ShimmerSkeleton(
                    height: isMobile ? 32 : 36,
                    borderRadius: 8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderRefundInfo {
  final String orderId;
  final String type;
  final double refundAmount;
  final double creditsRefunded;
  final List<String> items;

  const _OrderRefundInfo({
    required this.orderId,
    required this.type,
    required this.refundAmount,
    required this.creditsRefunded,
    required this.items,
  });
}
