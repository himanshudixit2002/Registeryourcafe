import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/models/table.dart';
import 'package:registeryourcafe/models/table_venue_defaults.dart';
import 'package:registeryourcafe/models/venue_kind.dart';
import 'package:registeryourcafe/models/venue_ui_config.dart';
import 'package:registeryourcafe/models/table_type_definition.dart';
import 'package:registeryourcafe/providers/company_module_provider.dart';
import 'package:registeryourcafe/providers/table_provider.dart';
import 'package:registeryourcafe/providers/table_type_provider.dart';
import 'package:registeryourcafe/theme/app_theme.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/screens/tables/table_types_settings_screen.dart';
import 'package:registeryourcafe/widgets/app_card.dart';
import 'package:registeryourcafe/widgets/empty_state_widget.dart';
import 'package:registeryourcafe/providers/permissions_provider.dart';
import 'package:registeryourcafe/utils/snackbar_helper.dart';
import 'package:registeryourcafe/providers/tenant_provider.dart';
import 'package:registeryourcafe/services/table_type_service.dart';
import 'package:registeryourcafe/widgets/glass_modal_bottom_sheet.dart';
import 'package:registeryourcafe/widgets/section_async_error.dart';
import 'package:registeryourcafe/widgets/permission_denied_scaffold.dart';

enum TableSortOption { nameAsc, nameDesc, rateAsc, rateDesc, typeAsc, typeDesc }

class TableSettingsScreen extends ConsumerStatefulWidget {
  const TableSettingsScreen({super.key});

  @override
  ConsumerState<TableSettingsScreen> createState() =>
      _TableSettingsScreenState();
}

class _TableSettingsScreenState extends ConsumerState<TableSettingsScreen> {
  String _searchQuery = '';
  String? _selectedTypeFilterId;
  TableStatus? _selectedStatus;
  TablePurpose? _purposeFilter;
  TableSortOption _sortOption = TableSortOption.nameAsc;

  List<SnookerTable> _filterAndSortTables(
    List<SnookerTable> tables,
    List<TableTypeDefinition> typeDefs,
  ) {
    final filteredTables = tables.where((table) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatches = table.name.toLowerCase().contains(query);
        final descriptionMatches =
            table.description?.toLowerCase().contains(query) ?? false;
        if (!nameMatches && !descriptionMatches) {
          return false;
        }
      }
      if (_selectedTypeFilterId != null &&
          table.typeId != _selectedTypeFilterId) {
        return false;
      }
      if (_selectedStatus != null && table.status != _selectedStatus) {
        return false;
      }
      if (_purposeFilter != null && table.tablePurpose != _purposeFilter) {
        return false;
      }
      return true;
    }).toList();

    switch (_sortOption) {
      case TableSortOption.nameAsc:
        filteredTables.sort((a, b) => a.name.compareTo(b.name));
        break;
      case TableSortOption.nameDesc:
        filteredTables.sort((a, b) => b.name.compareTo(a.name));
        break;
      case TableSortOption.rateAsc:
        filteredTables.sort((a, b) => a.hourlyRate.compareTo(b.hourlyRate));
        break;
      case TableSortOption.rateDesc:
        filteredTables.sort((a, b) => b.hourlyRate.compareTo(a.hourlyRate));
        break;
      case TableSortOption.typeAsc:
        filteredTables.sort((a, b) {
          final an = lookupTableType(typeDefs, a.typeId)?.name ?? a.typeId;
          final bn = lookupTableType(typeDefs, b.typeId)?.name ?? b.typeId;
          return an.compareTo(bn);
        });
        break;
      case TableSortOption.typeDesc:
        filteredTables.sort((a, b) {
          final an = lookupTableType(typeDefs, a.typeId)?.name ?? a.typeId;
          final bn = lookupTableType(typeDefs, b.typeId)?.name ?? b.typeId;
          return bn.compareTo(an);
        });
        break;
    }
    return filteredTables;
  }

  bool _purposeFilterDiffersFromVenueDefault(WidgetRef ref) {
    final venueDefault = ref.watch(venueKindProvider).defaultTablePurposeFilter;
    return _purposeFilter != venueDefault;
  }

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
    final canOpen = perms.canOpenTableSettingsScreens();
    final canMutate = perms.canMutateTableConfiguration();
    final canOpenTableTypes = perms.canOpenTableTypesSettings();

    if (!canOpen) {
      return const PermissionDeniedScaffold(
        title: 'Manage Tables',
        message: 'You do not have access to table settings.',
      );
    }

    final theme = Theme.of(context);
    final tenant = ref.watch(tenantRefProvider);
    final profileAsync = ref.watch(companyProfileProvider);
    final venueKind = ref.watch(venueKindProvider);
    final showPurposeFilterChip = venueKind == VenueKind.gamingCafe;

    final tablesAsync = ref.watch(tableListProvider);
    final typeDefs = ref
        .watch(tableTypeDefinitionsProvider)
        .maybeWhen(data: (d) => d, orElse: () => <TableTypeDefinition>[]);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage ${venueKind.tableTabLabel}'),
        centerTitle: true,
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
                  color: theme.colorScheme.shadow.withValues(alpha: 0.12),
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
        actions: [
          if (canOpenTableTypes)
            IconButton(
              tooltip: 'Table types',
              icon: Icon(
                Icons.category_outlined,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  AppMaterialPageRoute<void>(
                    builder: (_) => const TableTypesSettingsScreen(),
                  ),
                );
              },
            ),
          if (canMutate && !tablesAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                tooltip: 'Add New Table',
                onPressed: () => _showAddTableDialog(context, ref),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!canMutate)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 12 : 16,
                8,
                isMobile ? 12 : 16,
                0,
              ),
              child: Text(
                'View only. Ask a manager to add or edit tables.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          _buildFilterBar(
            theme,
            isMobile,
            typeDefs,
            showPurposeFilterChip: showPurposeFilterChip,
          ),
          Expanded(
            child: tenant != null && !profileAsync.hasValue
                ? const Center(child: CircularProgressIndicator())
                : tablesAsync.when(
              data: (tables) {
                final displayedTables = _filterAndSortTables(tables, typeDefs);
                if (displayedTables.isEmpty) {
                  return Center(
                    child: EmptyStateWidget(
                      icon: Icons.table_restaurant_outlined,
                                           message:
                          _searchQuery.isNotEmpty ||
                              _selectedTypeFilterId != null ||
                              _selectedStatus != null ||
                              _purposeFilterDiffersFromVenueDefault(ref)
                          ? 'No tables match your filters.'
                          : 'No tables configured yet.',
                      details: canMutate
                          ? 'Try adjusting filters or add a new table.'
                          : 'Try adjusting filters.',
                      actionButton: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedTypeFilterId = null;
                            _selectedStatus = null;
                            _purposeFilter =
                                ref.read(venueKindProvider).defaultTablePurposeFilter;
                            _sortOption = TableSortOption.nameAsc;
                          });
                        },
                        icon: const Icon(Icons.filter_list_off),
                        label: const Text('Clear Filters'),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  physics: AppTheme.scrollPhysicsFor(context),
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  itemCount: displayedTables.length,
                  itemBuilder: (context, index) {
                    final table = displayedTables[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + (index * 50)),
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
                      child: _buildTableSettingCard(
                        context,
                        ref,
                        table,
                        theme,
                        isMobile,
                        typeDefs,
                        canMutate,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => SectionAsyncError(error: err),
            ),
          ),
        ],
      ),
    );
  }

  String _typeFilterChipLabel(List<TableTypeDefinition> defs) {
    if (_selectedTypeFilterId == null) return 'Type';
    final id = _selectedTypeFilterId!;
    final name = lookupTableType(defs, id)?.name ?? id;
    return name.toUpperCase();
  }

  Widget _buildFilterBar(
    ThemeData theme,
    bool isMobile,
    List<TableTypeDefinition> typeDefs, {
    required bool showPurposeFilterChip,
  }) {
    final activeTypes = typeDefs.where((d) => !d.isArchived).toList();
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search tables...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.85,
                  ),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: AppTheme.scrollPhysicsFor(context),
            child: Row(
              children: [
                _buildFilterChip(
                  theme,
                  label: _typeFilterChipLabel(typeDefs),
                  isActive: _selectedTypeFilterId != null,
                  icon: Icons.category_outlined,
                  onTap: () => _showTypeFilter(theme, activeTypes),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  theme,
                  label: _selectedStatus?.name.toUpperCase() ?? 'Status',
                  isActive: _selectedStatus != null,
                  icon: Icons.toggle_on_outlined,
                  onTap: () => _showStatusFilter(theme),
                ),
                if (showPurposeFilterChip) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    theme,
                    label: _purposeFilter == null
                        ? 'Purpose'
                        : (_purposeFilter == TablePurpose.dining
                              ? 'DINING'
                              : 'GAMING'),
                    isActive: _purposeFilterDiffersFromVenueDefault(ref),
                    icon: Icons.restaurant_menu_outlined,
                    onTap: () => _showPurposeFilter(theme),
                  ),
                ],
                const SizedBox(width: 8),
                _buildFilterChip(
                  theme,
                  label: 'Sort',
                  isActive: _sortOption != TableSortOption.nameAsc,
                  icon: Icons.sort_rounded,
                  onTap: () => _showSortOptions(theme),
                ),
                if (_selectedTypeFilterId != null ||
                    _selectedStatus != null ||
                    (showPurposeFilterChip &&
                        _purposeFilterDiffersFromVenueDefault(ref))) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _searchQuery = '';
                        _selectedTypeFilterId = null;
                        _selectedStatus = null;
                        _purposeFilter =
                            ref.read(venueKindProvider).defaultTablePurposeFilter;
                        _sortOption = TableSortOption.nameAsc;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear,
                            size: 14,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.error,
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
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    ThemeData theme, {
    required String label,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.22)
              : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showTypeFilter(ThemeData theme, List<TableTypeDefinition> activeTypes) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildBottomSheet(
        title: 'Filter by Type',
        children: [
          _buildOptionTile(
            null,
            'All Types',
            _selectedTypeFilterId == null,
            () {
              setState(() => _selectedTypeFilterId = null);
              Navigator.pop(ctx);
            },
          ),
          ...activeTypes.map(
            (def) => _buildOptionTile(
              def.id,
              def.name.toUpperCase(),
              _selectedTypeFilterId == def.id,
              () {
                setState(() => _selectedTypeFilterId = def.id);
                Navigator.pop(ctx);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPurposeFilter(ThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildBottomSheet(
        title: 'Filter by Purpose',
        children: [
          _buildOptionTile(null, 'All purposes', _purposeFilter == null, () {
            setState(() => _purposeFilter = null);
            Navigator.pop(ctx);
          }),
          _buildOptionTile(
            TablePurpose.gaming,
            'Gaming (timed)',
            _purposeFilter == TablePurpose.gaming,
            () {
              setState(() => _purposeFilter = TablePurpose.gaming);
              Navigator.pop(ctx);
            },
          ),
          _buildOptionTile(
            TablePurpose.dining,
            'Dining (orders only)',
            _purposeFilter == TablePurpose.dining,
            () {
              setState(() => _purposeFilter = TablePurpose.dining);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showStatusFilter(ThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildBottomSheet(
        title: 'Filter by Status',
        children: [
          _buildOptionTile(null, 'All Statuses', _selectedStatus == null, () {
            setState(() => _selectedStatus = null);
            Navigator.pop(ctx);
          }),
          ...TableStatus.values.map(
            (status) => _buildOptionTile(
              status,
              status.name.toUpperCase(),
              _selectedStatus == status,
              () {
                setState(() => _selectedStatus = status);
                Navigator.pop(ctx);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(ThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildBottomSheet(
        title: 'Sort Tables',
        children: TableSortOption.values.map((option) {
          String text = option.toString().split('.').last;
          if (text.endsWith('Asc')) text = text.replaceAll('Asc', ' ↑');
          if (text.endsWith('Desc')) text = text.replaceAll('Desc', ' ↓');
          text = text
              .replaceAllMapped(
                RegExp(r'([A-Z])'),
                (match) => ' ${match.group(1)}',
              )
              .trim();
          return _buildOptionTile(option, text, _sortOption == option, () {
            setState(() => _sortOption = option);
            Navigator.pop(ctx);
          });
        }).toList(),
      ),
    );
  }

  Widget _buildBottomSheet({
    required String title,
    required List<Widget> children,
  }) {
    return GlassModalSheetChrome(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    dynamic value,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }

  Widget _buildTableSettingCard(
    BuildContext context,
    WidgetRef ref,
    SnookerTable table,
    ThemeData theme,
    bool isMobile,
    List<TableTypeDefinition> typeDefs,
    bool canMutate,
  ) {
    final venueKind = ref.watch(venueKindProvider);
    Color statusColor;
    String statusLabel;

    switch (table.status) {
      case TableStatus.available:
        statusColor = theme.colorScheme.primary;
        statusLabel = 'Available';
        break;
      case TableStatus.occupied:
        statusColor = theme.colorScheme.tertiary;
        statusLabel = 'Occupied';
        break;
      case TableStatus.maintenance:
        statusColor = theme.colorScheme.error;
        statusLabel = 'Maintenance';
        break;
    }

    final typeDef = lookupTableType(typeDefs, table.typeId);
    final typeColor = typeDef?.color ?? theme.colorScheme.secondary;
    final typeIcon = tableTypeIconFromKey(typeDef?.iconKey);
    final typeLabel = (typeDef?.name ?? table.typeId).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        onTap: canMutate
            ? () => _showEditTableDialog(context, ref, table)
            : null,
        child: Row(
          children: [
            // Type Icon
            Container(
              width: isMobile ? 50 : 56,
              height: isMobile ? 50 : 56,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(typeIcon, color: typeColor, size: isMobile ? 24 : 28),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          table.name,
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusBadge(
                        label: statusLabel,
                        color: statusColor,
                        pulsing: table.status == TableStatus.occupied,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        table.tablePurpose == TablePurpose.dining
                            ? Icons.restaurant_menu
                            : Icons.currency_rupee,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        venueKind.showHourlyRate && table.tablePurpose != TablePurpose.dining
                            ? '${table.hourlyRate.toStringAsFixed(0)}/hr'
                            : venueKind.availableSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ),
                      if (table.tablePurpose == TablePurpose.dining) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer
                                .withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.colorScheme.tertiary.withValues(
                                alpha: 0.28,
                              ),
                            ),
                          ),
                          child: Text(
                            'DINING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (table.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      table.description!,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTableDialog(BuildContext context, WidgetRef ref) {
    final profile = ref.read(companyProfileProvider).valueOrNull;
    final VenueKind kind =
        profile != null ? profile.venueKind : ref.read(venueKindProvider);
    showDialog<void>(
      context: context,
      builder: (_) => _TableFormDialog(
        ref: ref,
        defaultPurposeForNewTable: kind.defaultPurposeForNewTable,
        defaultTypeIdForNewTable: kind.defaultTableTypeId,
        pinDiningOnly: kind.restrictsTablePurposesToDining,
      ),
    );
  }

  void _showEditTableDialog(
    BuildContext context,
    WidgetRef ref,
    SnookerTable table,
  ) {
    final profile = ref.read(companyProfileProvider).valueOrNull;
    final VenueKind kind =
        profile != null ? profile.venueKind : ref.read(venueKindProvider);
    showDialog<void>(
      context: context,
      builder: (_) => _TableFormDialog(
        table: table,
        ref: ref,
        pinDiningOnly: kind.restrictsTablePurposesToDining,
      ),
    );
  }
}

class _TableFormDialog extends ConsumerStatefulWidget {
  final SnookerTable? table;
  final WidgetRef ref;
  final TablePurpose? defaultPurposeForNewTable;
  /// When adding a table, default `type` if Firestore has none yet.
  final String? defaultTypeIdForNewTable;
  final bool pinDiningOnly;

  const _TableFormDialog({
    this.table,
    required this.ref,
    this.defaultPurposeForNewTable,
    this.defaultTypeIdForNewTable,
    this.pinDiningOnly = false,
  });

  @override
  ConsumerState<_TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends ConsumerState<_TableFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _rateController;
  late TextEditingController _minMinutesController;
  String _selectedTypeId = kDefaultTableTypeId;
  TableStatus _selectedStatus = TableStatus.available;
  late TablePurpose _purpose;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.table?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.table?.description ?? '',
    );
    _rateController = TextEditingController(
      text: widget.table?.hourlyRate.toString() ?? '',
    );
    _minMinutesController = TextEditingController(
      text: (widget.table?.minimumBillableMinutes ?? 0) > 0
          ? widget.table!.minimumBillableMinutes.toString()
          : '',
    );
    _selectedTypeId = widget.table?.typeId ??
        widget.defaultTypeIdForNewTable ??
        kDefaultTableTypeId;
    _selectedStatus = widget.table?.status ?? TableStatus.available;
    _purpose = widget.table?.tablePurpose ??
        widget.defaultPurposeForNewTable ??
        TablePurpose.gaming;
    if (widget.pinDiningOnly) {
      _purpose = TablePurpose.dining;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _rateController.dispose();
    _minMinutesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    final tableService = ref.read(tableServiceProvider);

    try {
      if (widget.table == null) {
        setState(() => _submitting = true);
        try {
          final tenant = ref.read(tenantRefProvider);
          final profileState = ref.read(companyProfileProvider);
          if (tenant == null ||
              profileState.isLoading ||
              profileState.hasError ||
              !profileState.hasValue) {
            if (!mounted) return;
            context.showErrorSnackbar(
              profileState.hasError
                  ? 'Could not load company profile. Try again.'
                  : 'Company profile is not ready. Wait a moment and try again.',
            );
            return;
          }
          final profile = profileState.requireValue;

          var activeTypes = ref.read(activeTableTypeDefinitionsProvider)
              .maybeWhen(
                data: (list) => list,
                orElse: () => <TableTypeDefinition>[],
              );

          if (activeTypes.isEmpty) {
            await TableTypeService(
              tenant,
            ).ensureDefaultSeedIfEmpty(venueKind: profile.venueKind);
            ref.invalidate(tableTypeDefinitionsProvider);
            final all = await ref.read(tableTypeDefinitionsProvider.future);
            activeTypes = all.where((d) => !d.isArchived).toList();
          }

          if (activeTypes.isEmpty) {
            if (!mounted) return;
            final canTypes = ref
                .readResolvedPermissions()
                .canMutateTableTypeDefinitions();
            context.showErrorSnackbar(
              canTypes ? 'Could not create default table types. Check Firestore '
                      'access or add a type under Table types.'
                  : 'No table types exist yet. Ask a manager with Configure '
                      'tables or table types access to add one.',
            );
            return;
          }

          var typeId = _selectedTypeId;
          if (!activeTypes.any((e) => e.id == typeId)) {
            typeId = activeTypes.first.id;
          }

          final newTable = SnookerTable(
            id: tenant.tables().doc().id,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            hourlyRate: double.tryParse(_rateController.text) ?? 0.0,
            typeId: typeId,
            status: _selectedStatus,
            tablePurpose: _purpose,
            minimumBillableMinutes: _purpose == TablePurpose.gaming
                ? () {
                    final parsed = int.tryParse(
                      _minMinutesController.text.trim(),
                    );
                    if (parsed == null || parsed <= 0) return null;
                    return parsed;
                  }()
                : null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await tableService.addTable(newTable);

          if (!mounted) return;
          Navigator.of(context).pop();
          context.showSuccessSnackbar('Table added successfully!');
        } finally {
          if (mounted) setState(() => _submitting = false);
        }
      } else {
        await tableService.updateTableSettings(
          widget.table!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          hourlyRate: double.tryParse(_rateController.text),
          typeId: _selectedTypeId,
          status: _selectedStatus,
          tablePurpose: _purpose,
          minimumBillableMinutes: _purpose == TablePurpose.gaming
              ? () {
                  final parsed = int.tryParse(
                    _minMinutesController.text.trim(),
                  );
                  if (parsed == null || parsed <= 0) return null;
                  return parsed;
                }()
              : null,
          clearMinimumBillableMinutes: _purpose == TablePurpose.dining,
        );

        if (!mounted) return;
        Navigator.of(context).pop();
        context.showSuccessSnackbar('Table updated successfully!');
      }
    } catch (error) {
      if (!mounted) return;
      context.showErrorSnackbar(
        SnackbarHelper.messageForFirestoreMutationFailure(error),
      );
    }
  }

  bool _typesAllowPrimaryAction(AsyncValue<List<TableTypeDefinition>> types) {
    return !types.isLoading && !types.hasError;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typesAsync = ref.watch(activeTableTypeDefinitionsProvider);
    final canOpenTableTypes = ref.watchResolvedPermissions().canOpenTableTypesSettings();
    final primaryEnabled =
        _typesAllowPrimaryAction(typesAsync) && !_submitting;
    return AlertDialog(
      title: Text(
        widget.table == null ? 'Add New Table' : 'Edit Table',
        style: theme.textTheme.titleLarge,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: AppTheme.inputDecoration(
                  theme,
                  'Table Name',
                  Icons.table_restaurant_outlined,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter a table name'
                    : null,
              ),
              const SizedBox(height: AppTheme.kSpacingMedium),
              TextFormField(
                controller: _descriptionController,
                decoration: AppTheme.inputDecoration(
                  theme,
                  'Description (Optional)',
                  Icons.notes_outlined,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppTheme.kSpacingMedium),
              Text(
                'Purpose',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.kSpacingSmall),
              if (widget.pinDiningOnly)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dining (orders only)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                SegmentedButton<TablePurpose>(
                  segments: const [
                    ButtonSegment<TablePurpose>(
                      value: TablePurpose.gaming,
                      label: Text('Gaming'),
                      icon: Icon(Icons.sports_esports_outlined, size: 18),
                    ),
                    ButtonSegment<TablePurpose>(
                      value: TablePurpose.dining,
                      label: Text('Dining'),
                      icon: Icon(Icons.restaurant_menu_outlined, size: 18),
                    ),
                  ],
                  selected: {_purpose},
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    setState(() => _purpose = s.first);
                  },
                ),
              if (_purpose == TablePurpose.dining) ...[
                const SizedBox(height: AppTheme.kSpacingSmall),
                Text(
                  'Dining tables bill from linked café and merchandise orders only; time is not charged.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (!widget.pinDiningOnly) ...[
                const SizedBox(height: AppTheme.kSpacingMedium),
                TextFormField(
                  controller: _rateController,
                  decoration: AppTheme.inputDecoration(
                    theme,
                    _purpose == TablePurpose.dining
                        ? 'Hourly rate (optional, not billed)'
                        : 'Hourly Rate (\u20B9)',
                    Icons.price_change_outlined,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (_purpose == TablePurpose.dining) {
                      if (value == null || value.trim().isEmpty) return null;
                      final d = double.tryParse(value);
                      if (d == null) return 'Please enter a valid number';
                      if (d < 0) return 'Rate cannot be negative';
                      return null;
                    }
                    if (value == null || value.isEmpty) {
                      return 'Please enter a rate';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    if (double.parse(value) <= 0) return 'Rate must be positive';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: AppTheme.kSpacingMedium),
              typesAsync.when(
                data: (types) {
                  if (types.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'No table types yet. Saving will try to create defaults '
                          'for this venue, or add a type from the category icon '
                          'on Manage Tables.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        if (canOpenTableTypes)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                AppMaterialPageRoute<void>(
                                  builder: (_) =>
                                      const TableTypesSettingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Manage table types'),
                          ),
                      ],
                    );
                  }
                  var chosen = _selectedTypeId;
                  if (!types.any((e) => e.id == chosen)) {
                    chosen = types.first.id;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedTypeId = chosen);
                    });
                  }
                  final typeItems = types
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.id,
                          child: Row(
                            children: [
                              Icon(
                                tableTypeIconFromKey(e.iconKey),
                                size: 22,
                                color: e.color,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(e.name)),
                            ],
                          ),
                        ),
                      )
                      .toList();
                  return DropdownButtonFormField<String>(
                    initialValue: chosen,
                    isExpanded: true,
                    decoration: AppTheme.inputDecoration(
                      theme,
                      'Table Type',
                      Icons.category_outlined,
                    ),
                    items: typeItems,
                    selectedItemBuilder: (context) =>
                        AppTheme.dropdownSelectedItemBuilders(theme, typeItems),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedTypeId = newValue;
                        });
                      }
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => Text(
                  'Could not load table types: $e',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              const SizedBox(height: AppTheme.kSpacingMedium),
              Builder(
                builder: (ctx) {
                  final statusItems =
                      (widget.table?.status == TableStatus.occupied &&
                                  _selectedStatus == TableStatus.occupied
                              ? TableStatus.values
                              : TableStatus.values.where(
                                  (s) => s != TableStatus.occupied,
                                ))
                          .map((TableStatus status) {
                            return DropdownMenuItem<TableStatus>(
                              value: status,
                              child: Text(
                                status.toString().split('.').last.toUpperCase(),
                              ),
                            );
                          })
                          .toList();
                  return DropdownButtonFormField<TableStatus>(
                    initialValue: _selectedStatus,
                    isExpanded: true,
                    decoration: AppTheme.inputDecoration(
                      theme,
                      'Status',
                      Icons.toggle_on_outlined,
                    ),
                    items: statusItems,
                    selectedItemBuilder: (context) =>
                        AppTheme.dropdownSelectedItemBuilders(
                          theme,
                          statusItems,
                        ),
                    onChanged: (TableStatus? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedStatus = newValue;
                        });
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: AppTheme.kSpacingMedium),
              if (_purpose == TablePurpose.gaming) ...[
                TextFormField(
                  controller: _minMinutesController,
                  decoration: AppTheme.inputDecoration(
                    theme,
                    'Minimum Billable Minutes (optional)',
                    Icons.timelapse_outlined,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                    signed: false,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null; // optional
                    }
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null) {
                      return 'Enter a whole number of minutes';
                    }
                    if (parsed < 0) return 'Minutes must be 0 or more';
                    if (parsed > 720) return 'Minutes too large';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('CANCEL'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton.icon(
          icon: Icon(
            widget.table == null
                ? Icons.add_circle_outline_rounded
                : Icons.save_outlined,
          ),
          label: Text(widget.table == null ? 'ADD TABLE' : 'SAVE CHANGES'),
          onPressed: primaryEnabled ? _submitForm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}

class TableSettingCardSkeleton extends StatelessWidget {
  const TableSettingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.05,
                      ),
                      borderRadius: BorderRadius.circular(4),
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
}
