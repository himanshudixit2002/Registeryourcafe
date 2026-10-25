import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/table.dart';
import '../../models/session.dart';
import '../../models/table_venue_defaults.dart';
import '../../models/venue_ui_config.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/table_type_provider.dart';
import '../../models/table_type_definition.dart';
import '../../widgets/responsive_grid.dart';
import '../../theme/app_theme.dart';
import './table_settings_screen.dart';
import '../../models/customer.dart';
import '../../auth/permission_id.dart';
import './session_details_dialog.dart';
import '../../widgets/dialogs/customer_selection_dialog.dart';
import './all_sessions_history_screen.dart';
import './dining/dining_session_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/stats_strip.dart';
import '../../widgets/filter_chip_bar.dart';
import 'components/table_card.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/dialogs/players_selection_dialog.dart';
import '../admin/restore_sessions_screen.dart';
import '../../widgets/glass_modal_bottom_sheet.dart';
import '../../widgets/section_async_error.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class TableGridScreen extends ConsumerStatefulWidget {
  const TableGridScreen({super.key});

  @override
  ConsumerState<TableGridScreen> createState() => _TableGridScreenState();
}

class _TableGridScreenState extends ConsumerState<TableGridScreen> {
  String _searchTerm = '';
  TableStatus? _selectedStatusFilter;
  String? _selectedTypeFilter;
  TablePurpose? _purposeFilter;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(companyProfileProvider, (prev, next) {
      next.whenData((profile) {
        if (!mounted) return;
        if (profile.venueKind.restrictsTablePurposesToDining) {
          if (_purposeFilter != TablePurpose.dining) {
            setState(() => _purposeFilter = TablePurpose.dining);
          }
        } else {
          final def = profile.venueKind.defaultTablePurposeFilter;
          if (_purposeFilter == null && def != null) {
            setState(() => _purposeFilter = def);
          }
        }
      });
    });

    final perms = ref.watchResolvedPermissions();
    if (!perms.can(PermissionIds.navTables)) {
      return const Scaffold(
        body: Center(child: Text('You do not have access to tables.')),
      );
    }

    final canOpenTableSettings = perms.canOpenTableSettingsScreens();
    final canSessionAdmin = perms.can(PermissionIds.opsSessionAdmin);
    final canSessionsHistory = perms.can(PermissionIds.opsSessionsHistory);
    final venueKind = ref.watch(venueKindProvider);

    return Scaffold(
      body: _isLoading
          ? const Center(child: LoadingIndicator(message: 'Processing...'))
          : Column(
              children: [
                ScreenHeader(
                  title: venueKind.floorTitle,
                  icon: venueKind.tableTabActiveIcon,
                  actions: [
                    if (canSessionAdmin) _buildRestoreSessionsButton(AppTheme.isMobile(context)),
                    if (canOpenTableSettings)
                      ScreenHeaderAction(
                        icon: Icons.settings_outlined,
                        tooltip: 'Table settings',
                        onTap: () => Navigator.push(
                          context,
                          AppMaterialPageRoute<void>(
                            builder: (_) => const TableSettingsScreen(),
                          ),
                        ),
                      ),
                    if (canSessionsHistory)
                      ScreenHeaderAction(
                        icon: Icons.history,
                        tooltip: venueKind.sessionHistoryTitle,
                        onTap: () => Navigator.push(
                          context,
                          AppMaterialPageRoute<void>(
                            builder: (_) => const AllSessionsHistoryScreen(),
                          ),
                        ),
                      ),
                  ],
                ),
                _buildFloorStatsStrip(),
                Expanded(child: _buildTablesTab()),
              ],
            ),
    );
  }

  Widget _buildFloorStatsStrip() {
    final tablesAsync = ref.watch(tableListProvider);
    final venueKind = ref.watch(venueKindProvider);
    final sem = AppSemanticColors.of(context);

    return tablesAsync.maybeWhen(
      data: (tables) {
        if (tables.isEmpty) return const SizedBox.shrink();
        final occupied = tables.where((t) => t.status == TableStatus.occupied).length;
        final available = tables.where((t) => t.status == TableStatus.available).length;
        final maintenance = tables.where((t) => t.status == TableStatus.maintenance).length;

        return StatsStrip(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          items: [
            StatStripItem(
              icon: Icons.people_rounded,
              label: venueKind.occupiedStatsLabel,
              value: '$occupied',
              color: sem.warning,
            ),
            StatStripItem(
              icon: Icons.check_circle_outline,
              label: 'Available',
              value: '$available',
              color: sem.success,
            ),
            if (maintenance > 0)
              StatStripItem(
                icon: Icons.build_circle_outlined,
                label: 'Maintenance',
                value: '$maintenance',
                color: Theme.of(context).colorScheme.outline,
              ),
            StatStripItem(
              icon: venueKind.tableTabActiveIcon,
              label: 'Total',
              value: '${tables.length}',
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildTablesTab() {
    final tenant = ref.watch(tenantRefProvider);
    final profileAsync = ref.watch(companyProfileProvider);
    if (tenant != null && profileAsync.isLoading) {
      return const Center(
        child: LoadingIndicator(message: 'Loading workspace…'),
      );
    }
    if (tenant != null && profileAsync.hasError) {
      return SectionAsyncError(error: profileAsync.error!);
    }

    final tablesAsyncValue = ref.watch(tableListProvider);
    final typeDefs = ref
        .watch(tableTypeDefinitionsProvider)
        .maybeWhen(data: (d) => d, orElse: () => <TableTypeDefinition>[]);
    final activeTypes = typeDefs.where((d) => !d.isArchived).toList();
    return Column(
      children: [
        _buildFilterBar(activeTypes),
        Expanded(
          child: tablesAsyncValue.when(
            data: (allTables) {
              final filteredTables = allTables.where((table) {
                final searchTermLower = _searchTerm.toLowerCase();
                final nameMatches = table.name.toLowerCase().contains(
                  searchTermLower,
                );
                final statusMatches =
                    _selectedStatusFilter == null ||
                    table.status == _selectedStatusFilter;
                final typeMatches =
                    _selectedTypeFilter == null ||
                    table.typeId == _selectedTypeFilter;
                final purposeMatches =
                    _purposeFilter == null ||
                    table.tablePurpose == _purposeFilter;
                return nameMatches &&
                    statusMatches &&
                    typeMatches &&
                    purposeMatches;
              }).toList();
              return _buildTableGrid(filteredTables);
            },
            loading: () => const Center(
              child: LoadingIndicator(message: 'Loading tables...'),
            ),
            error: (error, stack) => SectionAsyncError(error: error),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(List<TableTypeDefinition> activeTypes) {
    final venueKind = ref.watch(venueKindProvider);
    final venuePurposeDefault = venueKind.defaultTablePurposeFilter;
    final showPurposeFilter = venueKind.showPurposeFilter;
    final hasActiveFilters =
        _selectedTypeFilter != null ||
        _selectedStatusFilter != null ||
        _purposeFilter != venuePurposeDefault;

    return FilterChipBar(
      searchHint: venueKind.tableSearchHint,
      onSearchChanged: (value) => setState(() => _searchTerm = value),
      hasActiveFilters: hasActiveFilters,
      onClearFilters: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTypeFilter = null;
          _selectedStatusFilter = null;
          _purposeFilter = ref.read(venueKindProvider).defaultTablePurposeFilter;
        });
      },
      dropdowns: [
        FilterDropdownDef<String>(
          label: 'Type',
          value: _selectedTypeFilter,
          icon: Icons.category_outlined,
          items: activeTypes
              .map((def) => DropdownMenuItem<String>(
                    value: def.id,
                    child: Text(def.name, style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedTypeFilter = value),
        ),
        FilterDropdownDef<TableStatus>(
          label: 'Status',
          value: _selectedStatusFilter,
          icon: Icons.filter_list,
          items: TableStatus.values
              .map((status) => DropdownMenuItem<TableStatus>(
                    value: status,
                    child: Text(status.name, style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedStatusFilter = value),
        ),
        if (showPurposeFilter)
          FilterDropdownDef<TablePurpose>(
            label: 'Purpose',
            value: _purposeFilter,
            icon: Icons.restaurant_menu_outlined,
            items: TablePurpose.values
                .map((p) => DropdownMenuItem<TablePurpose>(
                      value: p,
                      child: Text(p.name, style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _purposeFilter = value),
          ),
      ],
    );
  }

  Widget _buildTableGrid(List<SnookerTable> tables) {
    if (tables.isEmpty) {
      final vk = ref.watch(venueKindProvider);
      return Center(
        child: EmptyStateWidget(
          icon: vk.tableTabActiveIcon,
          message: vk.emptyFloorMessage,
          details: 'Try adjusting your search or filters.',
        ),
      );
    }

    final isMobile = AppTheme.isMobile(context);
    final isDesktop = AppTheme.isDesktop(context);

    final gridPad = isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tableListProvider);
      },
      child: ResponsiveGrid(
      padding: EdgeInsets.fromLTRB(
        gridPad,
        gridPad,
        gridPad,
        gridPad + MediaQuery.paddingOf(context).bottom,
      ),
      maxCrossAxisExtent: isDesktop ? 280 : (isMobile ? 165 : 200),
      childAspectRatio: isDesktop ? 1.0 : (isMobile ? 0.75 : 0.85),
      children: tables.map((table) {
        VoidCallback? onTapAction;
        switch (table.status) {
          case TableStatus.occupied:
            onTapAction = () => _showEndSessionDialog(table);
            break;
          case TableStatus.available:
            onTapAction = () => _showStartSessionDialog(table);
            break;
          case TableStatus.maintenance:
            onTapAction = () {
              final t = Theme.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'This table is currently under maintenance.',
                    style: TextStyle(color: t.colorScheme.onTertiaryContainer),
                  ),
                  backgroundColor: t.colorScheme.tertiaryContainer,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            };
            break;
        }
        return TableCard(
          key: ValueKey(table.id),
          table: table,
          onTap: onTapAction,
        );
      }).toList(),
      ),
    );
  }

  Future<void> _showStartSessionDialog(SnookerTable table) async {
    bool isPTL = false;
    int selectedPlayers = 2;
    final isMobile = AppTheme.isMobile(context);

    final modules = ref.read(workspaceModuleVisibilityProvider);
    final bool showLtpSessionMode = modules.leaderboard || modules.tournaments;

    bool? modeConfirmed;
    final venueKind = ref.read(venueKindProvider);
    final bool skipGamingMode = venueKind.isDiningOrRestaurant || table.tablePurpose == TablePurpose.dining;

    if (!skipGamingMode && !showLtpSessionMode) {
      modeConfirmed = true;
      isPTL = false;
    }

    if (!skipGamingMode && showLtpSessionMode) {
      if (isMobile) {
        // Mobile: Use bottom sheet for better UX
        modeConfirmed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setStateSB) {
                // Define prominent colors for mobile
                const Color primaryGreen = Color(0xFF2E7D32);
                final cs = Theme.of(ctx).colorScheme;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                  ),
                  child: GlassModalSheetChrome(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with gradient background
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryGreen,
                                  primaryGreen.withValues(alpha: 0.85),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryGreen.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cs.onPrimary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.play_circle_rounded,
                                    color: cs.onPrimary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Session',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: cs.onPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        table.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: cs.onPrimary.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Rate display
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.onPrimary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₹${table.hourlyRate.toStringAsFixed(0)}/hr',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Session Mode Selection
                          Text(
                            'Select Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Mode Cards - Enhanced for visibility
                          Row(
                            children: [
                              Expanded(
                                child: _buildMobileModeCard(
                                  context: ctx,
                                  icon: Icons.person_rounded,
                                  title: 'Regular',
                                  subtitle: 'Single player',
                                  isSelected: !isPTL,
                                  selectedColor: primaryGreen,
                                  onTap: () => setStateSB(() => isPTL = false),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildMobileModeCard(
                                  context: ctx,
                                  icon: Icons.people_rounded,
                                  title: 'LTP',
                                  subtitle: 'Loser pays',
                                  isSelected: isPTL,
                                  selectedColor: const Color(0xFFE65100),
                                  onTap: () => setStateSB(() => isPTL = true),
                                ),
                              ),
                            ],
                          ),

                          // Player count for PTL
                          if (isPTL) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Number of Players',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 56,
                              child: ListView.separated(
                                physics: AppTheme.scrollPhysicsFor(ctx),
                                scrollDirection: Axis.horizontal,
                                itemCount: 5,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (_, index) {
                                  final count = index + 2;
                                  final isSelected = selectedPlayers == count;
                                  return GestureDetector(
                                    onTap: () => setStateSB(
                                      () => selectedPlayers = count,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 56,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFE65100)
                                            : const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFFE65100)
                                              : const Color(0xFFFFB74D),
                                          width: 2,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFFE65100,
                                                  ).withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$count',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? cs.onPrimary
                                                : const Color(0xFFE65100),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Action Buttons - Enhanced visibility
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    side: BorderSide(
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.55),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    AppStrings.cancel,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(ctx)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryGreen,
                                    foregroundColor: cs.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    elevation: 3,
                                    shadowColor: primaryGreen.withValues(
                                      alpha: 0.4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Continue',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      } else {
        // Desktop/Tablet: Use dialog
        modeConfirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setStateSB) {
                return AlertDialog(
                  title: const Text('Select Session Mode'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RadioGroup<bool>(
                        groupValue: isPTL,
                        onChanged: (val) {
                          if (val == null) return;
                          setStateSB(() => isPTL = val);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            RadioListTile<bool>(
                              title: Text('Regular'),
                              value: false,
                            ),
                            RadioListTile<bool>(
                              title: Text('Loser to Pay (LTP)'),
                              value: true,
                            ),
                          ],
                        ),
                      ),
                      if (isPTL) ...[
                        Divider(
                          color: AppTheme.subtleDividerColor(Theme.of(ctx)),
                        ),
                        const Text('Number of Players (min 2)'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: List.generate(5, (index) {
                            final count =
                                index + 2; // Start from 2 (minimum for PTL)
                            return ChoiceChip(
                              label: Text('$count'),
                              selected: selectedPlayers == count,
                              onSelected: (_) =>
                                  setStateSB(() => selectedPlayers = count),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text(AppStrings.cancel),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Next'),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    }

    if (!skipGamingMode && modeConfirmed != true) return;
    if (skipGamingMode) {
      isPTL = false;
    }

    if (!mounted) return;

    Customer? primaryCustomer;
    List<Customer>? players;

    if (isPTL && selectedPlayers > 1) {
      // Show players selection
      if (isMobile) {
        players = await showModalBottomSheet<List<Customer>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: false,
          builder: (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, _) => GlassPanel(
              blur: GlassBlur.modal,
              borderRadiusGeometry: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  const GlassModalSheetDragHandle(),
                  Expanded(
                    child: PlayersSelectionDialog(
                      requiredPlayers: selectedPlayers,
                      customers: ref.read(tenantRefProvider)!.customers(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        players = await showDialog<List<Customer>>(
          context: context,
          barrierDismissible: false,
          builder: (_) => PlayersSelectionDialog(
            requiredPlayers: selectedPlayers,
            customers: ref.read(tenantRefProvider)!.customers(),
          ),
        );
      }
      if (!mounted) return;
      if (players == null) return;
      primaryCustomer = players.first;
    } else {
      // Show single customer selection
      if (isMobile) {
        primaryCustomer = await showModalBottomSheet<Customer>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, _) => GlassPanel(
              blur: GlassBlur.modal,
              borderRadiusGeometry: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  const GlassModalSheetDragHandle(),
                  Expanded(
                    child: CustomerSelectionDialog(
                      customers: ref.read(tenantRefProvider)!.customers(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        primaryCustomer = await showDialog<Customer>(
          context: context,
          builder: (_) => CustomerSelectionDialog(
            customers: ref.read(tenantRefProvider)!.customers(),
          ),
        );
      }
      if (!mounted) return;
      if (primaryCustomer == null) return;
    }

    final currentUser = ref.read(appUserProvider).value;
    if (currentUser == null) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not identify current user. Please log in again.',
            style: TextStyle(color: cs.onErrorContainer),
          ),
          backgroundColor: cs.errorContainer,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(tableServiceProvider)
          .startSession(
            table: table,
            customer: primaryCustomer,
            paymentMode: PaymentMode.cash,
            startedBy: currentUser,
            isPTL: isPTL,
            playerCount: isPTL ? selectedPlayers : null,
            players: isPTL ? (players ?? [primaryCustomer]) : null,
          );

      if (!mounted) return;
      final csOk = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session started for ${primaryCustomer.name} on ${table.name}.',
            style: TextStyle(color: csOk.onPrimary),
          ),
          backgroundColor: csOk.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final csErr = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error starting session: $e',
            style: TextStyle(color: csErr.onErrorContainer),
          ),
          backgroundColor: csErr.errorContainer,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showEndSessionDialog(SnookerTable table) async {
    if (table.currentSessionId == null) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Table session is not active or out of sync. Refreshing...',
            style: TextStyle(color: cs.onTertiaryContainer),
          ),
          backgroundColor: cs.tertiaryContainer,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) {
        throw Exception('No company context');
      }
      final sessionDoc = await tenant
          .sessions()
          .doc(table.currentSessionId)
          .get();
      if (!sessionDoc.exists) {
        throw Exception('Session data not found!');
      }
      final session = TableSession.fromFirestore(sessionDoc);

      setState(() => _isLoading = false);

      if (!mounted) return;

      final isMobile = AppTheme.isMobile(context);
      bool? sessionEnded;

      if (session.isDining && session.status == SessionStatus.active) {
        sessionEnded = await Navigator.of(context).push<bool>(
          AppMaterialPageRoute<bool>(
            builder: (_) => DiningSessionScreen(
              session: session,
              table: table,
              customerId: session.customerId,
            ),
          ),
        );
      } else if (isMobile) {
        // Use bottom sheet on mobile for better UX
        sessionEnded = await showModalBottomSheet<bool>(
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
                      table: table,
                      customerId: session.customerId,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        sessionEnded = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => SessionDetailsDialog(
            session: session,
            table: table,
            customerId: session.customerId,
          ),
        );
      }

      if (!mounted) return;

      if (sessionEnded == true) {
        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Session for ${table.name} has been successfully ended.',
                style: TextStyle(color: cs.onPrimary),
              ),
              backgroundColor: cs.primary,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading session details: ${e.toString()}',
              style: TextStyle(color: cs.onErrorContainer),
            ),
            backgroundColor: cs.errorContainer,
          ),
        );
      }
    }
  }

  // Enhanced mobile mode card with better visibility
  Widget _buildMobileModeCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final Color bgColor = isSelected
        ? selectedColor.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest.withValues(alpha: 0.65);
    final Color borderColor =
        isSelected ? selectedColor : cs.outline.withValues(alpha: 0.45);
    final Color iconColor = isSelected ? selectedColor : cs.onSurfaceVariant;
    final Color textColor = isSelected ? selectedColor : cs.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2.5 : 1.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.15)
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.8)
                    : cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 14, color: cs.onPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Selected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreSessionsButton(bool isMobile) {
    final orphanSessionsAsync = ref.watch(orphanCancelledSessionsProvider);

    return orphanSessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();

        return Tooltip(
          message: 'Fix ${sessions.length} affected session(s)',
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              AppMaterialPageRoute<void>(
                builder: (_) => const RestoreSessionsScreen(),
              ),
            ),
            child: Builder(
              builder: (context) {
                final cs = Theme.of(context).colorScheme;
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: cs.tertiary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: isMobile ? 16 : 20,
                        color: cs.onTertiary,
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${sessions.length}',
                            style: TextStyle(
                              color: cs.onError,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
