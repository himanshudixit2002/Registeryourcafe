import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/permission_id.dart';
import '../../firestore/tenant_firestore.dart';
import '../../models/stock_item.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/permission_denied_scaffold.dart';
import '../../services/stock_cost_service.dart';
import '../../services/stock_helper.dart';
import '../../services/public_venue_sync_service.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/business_validators.dart';
import '../../widgets/linked_stock_picker.dart';
import '../../widgets/stock_category_selection_field.dart';
import '../../utils/snackbar_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'components/category_filter_bar.dart';
import '../inventory/inventory_hub_screen.dart';
import '../../widgets/glass_modal_bottom_sheet.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/constants/app_strings.dart';
import 'package:registeryourcafe/widgets/safe_network_avatar.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  TenantRef get _tenant {
    final t = ref.read(tenantRefProvider);
    if (t == null) throw StateError('Company required');
    return t;
  }

  String _searchTerm = '';
  String _selectedCategory = 'All';
  bool _showLowStockOnly = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);

    if (!ref.watchResolvedPermissions().can(PermissionIds.navCafe)) {
      return const PermissionDeniedScaffold(
        title: 'Stock',
        message: 'You do not have access to the café.',
      );
    }

    final canMutateStock = ref.watchResolvedPermissions().can(
      PermissionIds.opsCafeAdmin,
    );

    return Scaffold(
      body: Column(
        children: [
          // Header Section
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            isDense: isMobile,
                            hintText: 'Search Cafe Stock...',
                            hintStyle: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isMobile ? 10 : 14,
                            ),
                            suffixIcon: _searchTerm.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    // Add Filter Button
                    Container(
                      decoration: BoxDecoration(
                        color: _showLowStockOnly
                            ? theme.colorScheme.errorContainer
                            : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.warning_amber_rounded,
                          color: _showLowStockOnly
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Show Low Stock',
                        onPressed: () {
                          setState(
                            () => _showLowStockOnly = !_showLowStockOnly,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _tenant
                  .stockItems()
                  .where('isMerchandise', isEqualTo: false)
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildStockSkeletonGrid(isMobile);
                }

                final allStockItems = snapshot.data!.docs
                    .map((doc) => StockItem.fromFirestore(doc))
                    .toList();

                final categoriesSet = <String>{
                  for (var it in allStockItems)
                    if (it.category != null && it.category!.isNotEmpty)
                      it.category!,
                };
                final List<String> categories = [
                  'All',
                  ...categoriesSet.toList()..sort(),
                ];

                // Apply filters
                final itemsAfterPrimaryFilters = allStockItems.where((item) {
                  final searchMatch =
                      _searchTerm.isEmpty ||
                      item.name.toLowerCase().contains(_searchTerm);
                  final categoryMatch =
                      _selectedCategory == 'All' ||
                      item.category == _selectedCategory;
                  return searchMatch && categoryMatch;
                }).toList();

                final int lowStockCount = itemsAfterPrimaryFilters
                    .where(
                      (it) =>
                          it.quantity <= it.lowStockThreshold &&
                          it.lowStockThreshold > 0,
                    )
                    .length;

                final itemsForGrid = _showLowStockOnly
                    ? itemsAfterPrimaryFilters
                          .where(
                            (it) =>
                                it.quantity <= it.lowStockThreshold &&
                                it.lowStockThreshold > 0,
                          )
                          .toList()
                    : itemsAfterPrimaryFilters;

                return Column(
                  children: [
                    // Stats & Actions
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 12 : 16,
                        isMobile ? 6 : 12,
                        isMobile ? 12 : 16,
                        0,
                      ),
                      child: isMobile
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _buildStatChip(
                                        label:
                                            'Total: ${itemsAfterPrimaryFilters.length}',
                                        icon: Icons.inventory_2_outlined,
                                        color: theme.colorScheme.primary,
                                        theme: theme,
                                        compact: true,
                                      ),
                                      _buildStatChip(
                                        label: 'Low: $lowStockCount',
                                        icon: Icons.warning_amber_rounded,
                                        color: lowStockCount > 0
                                            ? theme.colorScheme.error
                                            : theme.colorScheme.tertiary,
                                        theme: theme,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Stock actions',
                                  child: Icon(
                                    Icons.tune_rounded,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'restock':
                                        if (canMutateStock) {
                                          _showGlobalRestockDialog();
                                        } else {
                                          _snackCafeStockReadOnly();
                                        }
                                        break;
                                      case 'damage':
                                        if (canMutateStock) {
                                          _showDamageItemDialog();
                                        } else {
                                          _snackCafeStockReadOnly();
                                        }
                                        break;
                                      case 'vendor':
                                        Navigator.of(context).push(
                                          AppMaterialPageRoute<void>(
                                            builder: (_) =>
                                                const InventoryHubScreen(
                                                  initialTabIndex: 0,
                                                ),
                                          ),
                                        );
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'restock',
                                      enabled: canMutateStock,
                                      child: const Text('Quick Restock'),
                                    ),
                                    PopupMenuItem(
                                      value: 'damage',
                                      enabled: canMutateStock,
                                      child: const Text('Report Damage'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'vendor',
                                      child: Text(
                                        'Vendor receiving & inventory',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Row(
                                  children: [
                                    _buildStatChip(
                                      label:
                                          'Total: ${itemsAfterPrimaryFilters.length}',
                                      icon: Icons.inventory_2_outlined,
                                      color: theme.colorScheme.primary,
                                      theme: theme,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStatChip(
                                      label: 'Low Stock: $lowStockCount',
                                      icon: Icons.warning_amber_rounded,
                                      color: lowStockCount > 0
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.tertiary,
                                      theme: theme,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: canMutateStock
                                            ? _showGlobalRestockDialog
                                            : _snackCafeStockReadOnly,
                                        icon: const Icon(
                                          Icons.add_circle_outline_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Quick Restock'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: canMutateStock
                                            ? _showDamageItemDialog
                                            : _snackCafeStockReadOnly,
                                        icon: const Icon(
                                          Icons.remove_circle_outline_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Report Damage'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.tertiary,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: theme.colorScheme.outline
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        AppMaterialPageRoute<void>(
                                          builder: (_) =>
                                              const InventoryHubScreen(
                                                initialTabIndex: 0,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Vendor receiving & inventory',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),

                    // Categories
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 7 : 12,
                      ),
                      child: CategoryFilterBar(
                        categories: categories,
                        selectedCategory: _selectedCategory,
                        onCategorySelected: (cat) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    ),

                    // List
                    Expanded(
                      child: itemsForGrid.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 64,
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    allStockItems.isEmpty
                                        ? 'No items in stock.\nAdd items to get started!'
                                        : 'No items match your filters.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              physics: AppTheme.scrollPhysicsFor(context),
                              padding: EdgeInsets.fromLTRB(
                                isMobile ? 12 : 16,
                                0,
                                isMobile ? 12 : 16,
                                88,
                              ),
                              itemCount: itemsForGrid.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                return _buildStockListRow(
                                  itemsForGrid[index],
                                  index,
                                  canMutateStock,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canMutateStock
          ? FloatingActionButton.extended(
              heroTag: 'fab-cafe-stock',
              onPressed: _showAddOptionsBottomSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item'),
              elevation: 4,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            )
          : null,
    );
  }

  Widget _buildStockSkeletonGrid(bool isMobile) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 16,
        8,
        isMobile ? 12 : 16,
        8,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 10,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  Widget _buildStatChip({
    required String label,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    bool compact = false,
  }) {
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    final iconSize = compact ? 14.0 : 16.0;
    final fontSize = compact ? 11.0 : 12.0;
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _snackCafeStockReadOnly() {
    if (!mounted) return;
    context.showErrorSnackbar(
      'Café admin permission is required to add, edit, or restock items.',
    );
  }

  Widget _buildStockListRow(StockItem item, int rowIndex, bool canMutateStock) {
    final isLowStock =
        item.quantity <= item.lowStockThreshold && item.lowStockThreshold > 0;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final qtyStr =
        '${item.quantity.toStringAsFixed(item.unit == 'piece' || item.unit == 'pcs' ? 0 : 1)} ${item.unit}';

    final rowBg = rowIndex.isEven
        ? cs.surfaceContainerHighest.withValues(alpha: 0.28)
        : cs.primary.withValues(alpha: 0.04);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (!canMutateStock) {
              _snackCafeStockReadOnly();
              return;
            }
            _showAddEditStockItemDialog(item: item);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Row(
              children: [
                SafeNetworkAvatar(
                  imageUrl: item.imageUrl,
                  radius: 22,
                  fallbackIcon: item.isSellable
                      ? Icons.local_cafe_rounded
                      : Icons.inventory_2_rounded,
                  fallbackBackgroundColor: isLowStock
                      ? cs.errorContainer.withValues(alpha: 0.5)
                      : cs.primaryContainer.withValues(alpha: 0.4),
                  fallbackIconColor: isLowStock ? cs.error : cs.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.category != null &&
                          item.category!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.category!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            qtyStr,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isLowStock ? cs.error : cs.onSurface,
                            ),
                          ),
                          if (item.isSellable)
                            Text(
                              '₹${item.price?.toStringAsFixed(0) ?? '0'}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (item.lastUnitCost != null)
                            Text(
                              'Cost ₹${item.lastUnitCost!.toStringAsFixed(2)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          if (isLowStock)
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: cs.error,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Quick restock',
                  onPressed: canMutateStock
                      ? () {
                          HapticFeedback.lightImpact();
                          _showRestockDialog(item);
                        }
                      : _snackCafeStockReadOnly,
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddOptionsBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassModalSheetChrome(
          topRadius: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Create New Item'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddEditStockItemDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Create Items in Bulk'),
                onTap: () {
                  Navigator.pop(context);
                  _showBulkAddStockItemsDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showBulkAddStockItemsDialog() async {
    final formKey = GlobalKey<FormState>();
    final bulkController = TextEditingController();
    final stateContext = context;

    await showDialog<void>(
      context: stateContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bulk Add Cafe Stock'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Each line sets total on-hand quantity for that item name.\n'
                  'New items are created; existing cafe items are updated and logged in stock history.\n'
                  'Format: name, quantity, unit, lowStock(optional)\n\n'
                  'Example:\nSugar, 5, kg, 1\nTea Leaves, 2, kg',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: bulkController,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Milk, 10, litre, 2',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter items manually or choose a CSV file';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Pick CSV file',
                      icon: const Icon(Icons.attach_file_outlined),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['csv', 'txt'],
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final file = result.files.single;
                          if (file.bytes != null) {
                            final fileContent = String.fromCharCodes(
                              file.bytes!,
                            ).trim();
                            final currentText = bulkController.text.trim();

                            if (currentText.isEmpty) {
                              bulkController.text = fileContent;
                            } else {
                              bulkController.text =
                                  '$currentText\n$fileContent';
                            }
                            // Move cursor to the end
                            bulkController
                                .selection = TextSelection.fromPosition(
                              TextPosition(offset: bulkController.text.length),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final lines = bulkController.text.split('\n');
              final batch = _tenant.db.batch();
              int successCount = 0;
              int updatedCount = 0;

              // 1. Fetch existing cafe items to check for updates
              final existingStockSnapshot = await _tenant
                  .stockItems()
                  .where('isMerchandise', isEqualTo: false)
                  .get();
              if (!stateContext.mounted) return;
              final existingStockMap = {
                for (var doc in existingStockSnapshot.docs)
                  ((doc.data()['name'] as String?) ?? '').toLowerCase(): doc.id,
              };

              for (var rawLine in lines) {
                final line = rawLine.trim();
                if (line.isEmpty) continue;
                final parts = line.split(',').map((e) => e.trim()).toList();
                if (parts.length < 3) continue;

                final name = parts[0];
                final quantity = double.tryParse(parts[1]) ?? 0;
                final unit = parts[2].isNotEmpty ? parts[2] : 'piece';
                final lowStock = parts.length > 3
                    ? double.tryParse(parts[3]) ?? 0
                    : 0;

                if (name.isEmpty || quantity < 0) {
                  continue;
                }

                final itemData = {
                  'name': name,
                  'quantity': quantity,
                  'unit': unit,
                  'lowStockThreshold': lowStock,
                  'lastUpdated': FieldValue.serverTimestamp(),
                  'isSellable': false,
                  'isMerchandise': false,
                };

                // 2. Check if item exists to update, otherwise create
                final nameKey = name.toLowerCase();
                if (existingStockMap.containsKey(nameKey)) {
                  final docId = existingStockMap[nameKey]!;
                  final docRef = _tenant.stockItems().doc(docId);
                  try {
                    final u = FirebaseAuth.instance.currentUser;
                    await StockService.setQuantity(
                      tenant: _tenant,
                      itemId: docId,
                      quantity: quantity,
                      reason: 'Bulk import: set on-hand (cafe)',
                      updatedById: u?.uid,
                      updatedByName: u?.displayName ?? u?.email,
                    );
                    StockHelper.invalidateCache(docId);
                  } on Exception catch (e) {
                    if (!stateContext.mounted) return;
                    stateContext.showErrorSnackbar(e.userMessage);
                    return;
                  }
                  batch.update(docRef, {
                    'name': name,
                    'unit': unit,
                    'lowStockThreshold': lowStock,
                    'lastUpdated': FieldValue.serverTimestamp(),
                    'isSellable': false,
                    'isMerchandise': false,
                  });
                  updatedCount++;
                } else {
                  // Add new item
                  final docRef = _tenant.stockItems().doc();
                  batch.set(docRef, itemData);
                  successCount++;
                }
              }

              if (successCount == 0 && updatedCount == 0) {
                if (!stateContext.mounted) return;
                final cs = Theme.of(stateContext).colorScheme;
                ScaffoldMessenger.of(stateContext).showSnackBar(
                  SnackBar(
                    backgroundColor: cs.tertiaryContainer,
                    content: Text(
                      'No valid items found to add or update.',
                      style: TextStyle(color: cs.onTertiaryContainer),
                    ),
                  ),
                );
                return;
              }

              try {
                await batch.commit();
                if (!stateContext.mounted) return;
                final cs = Theme.of(stateContext).colorScheme;
                ScaffoldMessenger.of(stateContext).showSnackBar(
                  SnackBar(
                    backgroundColor: cs.primaryContainer,
                    content: Text(
                      '$successCount item(s) added, $updatedCount item(s) updated.',
                      style: TextStyle(color: cs.onPrimaryContainer),
                    ),
                  ),
                );
                Navigator.pop(dialogContext);
              } catch (e) {
                if (!stateContext.mounted) return;
                final cs = Theme.of(stateContext).colorScheme;
                ScaffoldMessenger.of(stateContext).showSnackBar(
                  SnackBar(
                    backgroundColor: cs.errorContainer,
                    content: Text(
                      'Error adding items: $e',
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                );
              }
            },
            child: const Text('Add Items'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEditStockItemDialog({StockItem? item}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: item?.name ?? '');
    final quantityController = TextEditingController(
      text: item?.quantity.toString() ?? '',
    );
    final unitController = TextEditingController(text: item?.unit ?? 'piece');
    final lowStockThresholdController = TextEditingController(
      text: item?.lowStockThreshold.toString() ?? '0',
    );
    final unitCostController = TextEditingController(
      text: item?.lastUnitCost != null
          ? item!.lastUnitCost!.toStringAsFixed(2)
          : '',
    );

    bool isSellable = item?.isSellable ?? false;
    final priceController = TextEditingController(
      text: item?.price?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: item?.description ?? '',
    );

    String? selectedCategory = item?.category;
    bool addingNewCategory = false;
    final newCategoryController = TextEditingController();

    final bool isNewItem = item == null;
    final String docId = isNewItem ? _tenant.stockItems().doc().id : item.id;
    final linkedStockItemIds = List<String>.from(
      item?.linkedStockItemIds ?? [],
    );

    if (unitController.text.isEmpty) {
      unitController.text = 'piece';
    }

    final stateContext = context;
    await showDialog<void>(
      context: stateContext,
      builder: (context) {
        final isMobile = AppTheme.isMobile(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final media = MediaQuery.of(context);
            final availH = media.size.height - media.viewInsets.vertical;
            final maxDialogHeight = (availH * 0.92).clamp(240.0, 4000.0);

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 40,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: maxDialogHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isNewItem
                                ? Icons.add_circle_outline_rounded
                                : Icons.edit_note_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isNewItem ? 'Add Stock Item' : 'Edit Stock Item',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: nameController,
                                  decoration: AppTheme.baseInputDecoration
                                      .copyWith(
                                        labelText: 'Item Name',
                                        prefixIcon: const Icon(
                                          Icons.inventory_2_outlined,
                                        ),
                                      ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: quantityController,
                                        decoration: AppTheme.baseInputDecoration
                                            .copyWith(
                                              labelText: 'Quantity',
                                              prefixIcon: const Icon(
                                                Icons.numbers_rounded,
                                              ),
                                            ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Required';
                                          }
                                          final n = double.tryParse(v);
                                          if (n == null) return 'Invalid';
                                          if (n < 0) return 'Must be ≥ 0';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: unitController,
                                        decoration: AppTheme.baseInputDecoration
                                            .copyWith(
                                              labelText: 'Unit',
                                              hintText: 'e.g. piece, kg',
                                              prefixIcon: const Icon(
                                                Icons.scale_rounded,
                                              ),
                                            ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Required'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: lowStockThresholdController,
                                  decoration: AppTheme.baseInputDecoration
                                      .copyWith(
                                        labelText: 'Low Stock Alert Limit',
                                        prefixIcon: const Icon(
                                          Icons.warning_amber_rounded,
                                        ),
                                      ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v != null &&
                                        v.isNotEmpty &&
                                        double.tryParse(v) == null) {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: unitCostController,
                                  decoration: AppTheme.baseInputDecoration.copyWith(
                                    labelText: 'Unit cost — what we pay (₹)',
                                    hintText:
                                        'Optional; vendor receipts update this',
                                    prefixIcon: const Icon(
                                      Icons.payments_outlined,
                                    ),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null;
                                    }
                                    final n = double.tryParse(v.trim());
                                    if (n == null) return 'Invalid amount';
                                    if (n < 0) return 'Cannot be negative';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),

                                // Sellable Section
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.25),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: isSellable
                                        ? Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.1)
                                        : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.5),
                                  ),
                                  child: Column(
                                    children: [
                                      SwitchListTile(
                                        title: const Text(
                                          'Available for Sale in Cafe?',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          isSellable
                                              ? 'Item will appear in the cafe menu'
                                              : 'Internal stock only',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        value: isSellable,
                                        onChanged: (bool value) {
                                          setDialogState(() {
                                            isSellable = value;
                                            if (!isSellable) {
                                              priceController.clear();
                                              descriptionController.clear();
                                              selectedCategory = null;
                                              addingNewCategory = false;
                                              newCategoryController.clear();
                                            }
                                          });
                                        },
                                        secondary: Icon(
                                          isSellable
                                              ? Icons.storefront_rounded
                                              : Icons.warehouse_rounded,
                                          color: isSellable
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 4,
                                            ),
                                      ),
                                      if (isSellable) ...[
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: AppTheme.subtleDividerColor(
                                            Theme.of(context),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            children: [
                                              StockCategorySelectionField(
                                                tenant: _tenant,
                                                isMerchandise: false,
                                                selectedCategory:
                                                    selectedCategory,
                                                addingNewCategory:
                                                    addingNewCategory,
                                                newCategoryController:
                                                    newCategoryController,
                                                onCategorySelected: (newValue) {
                                                  setDialogState(() {
                                                    selectedCategory = newValue;
                                                    if (addingNewCategory) {
                                                      addingNewCategory = false;
                                                    }
                                                  });
                                                },
                                                onAddNewToggled: (isAdding) {
                                                  setDialogState(() {
                                                    addingNewCategory =
                                                        isAdding;
                                                    if (!isAdding) {
                                                      newCategoryController
                                                          .clear();
                                                    }
                                                  });
                                                },
                                              ),
                                              const SizedBox(height: 16),
                                              TextFormField(
                                                controller: priceController,
                                                decoration: AppTheme
                                                    .baseInputDecoration
                                                    .copyWith(
                                                      labelText: 'Price (₹)',
                                                      prefixIcon: const Icon(
                                                        Icons
                                                            .currency_rupee_rounded,
                                                      ),
                                                    ),
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                validator: (v) {
                                                  if (!isSellable) return null;
                                                  if (v == null || v.isEmpty) {
                                                    return 'Required';
                                                  }
                                                  final p = double.tryParse(v);
                                                  if (p == null) {
                                                    return 'Invalid';
                                                  }
                                                  if (p <= 0) {
                                                    return 'Must be > 0';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 16),
                                              TextFormField(
                                                controller:
                                                    descriptionController,
                                                decoration: AppTheme
                                                    .baseInputDecoration
                                                    .copyWith(
                                                      labelText: 'Description',
                                                      hintText:
                                                          'Optional details for menu...',
                                                      prefixIcon: const Icon(
                                                        Icons
                                                            .description_rounded,
                                                      ),
                                                    ),
                                                maxLines: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.25),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Linked stock (vendor receipts)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Receiving stock for this item also updates quantity and last cost on linked items (one hop).',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ...linkedStockItemIds.map(
                                            (lid) => InputChip(
                                              label: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 200,
                                                    ),
                                                child: LinkedStockItemLabel(
                                                  id: lid,
                                                  tenant: _tenant,
                                                ),
                                              ),
                                              onDeleted: () => setDialogState(
                                                () => linkedStockItemIds.remove(
                                                  lid,
                                                ),
                                              ),
                                            ),
                                          ),
                                          ActionChip(
                                            avatar: const Icon(
                                              Icons.add,
                                              size: 18,
                                            ),
                                            label: const Text('Link item'),
                                            onPressed: () async {
                                              final picked =
                                                  await showLinkedStockItemPicker(
                                                    context: context,
                                                    tenant: _tenant,
                                                    excludeIds: {
                                                      docId,
                                                      ...linkedStockItemIds,
                                                    },
                                                  );
                                              if (picked != null) {
                                                setDialogState(() {
                                                  linkedStockItemIds.add(
                                                    picked.id,
                                                  );
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (item != null)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Delete'),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _confirmDeleteStockItem(item);
                              },
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(AppStrings.cancel),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              isNewItem ? 'Add Item' : 'Save Changes',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                // Handle category logic
                                String? finalCategory;
                                if (isSellable) {
                                  if (addingNewCategory) {
                                    final newCatName = newCategoryController
                                        .text
                                        .trim();
                                    if (newCatName.isEmpty) {
                                      context.showErrorSnackbar(
                                        'Please enter category name',
                                      );
                                      return;
                                    }
                                    final query = await _tenant
                                        .categories()
                                        .where('name', isEqualTo: newCatName)
                                        .where(
                                          'isMerchandise',
                                          isEqualTo: false,
                                        )
                                        .limit(1)
                                        .get();

                                    if (query.docs.isEmpty) {
                                      await _tenant.categories().add({
                                        'name': newCatName,
                                        'isMerchandise': false,
                                      });
                                    }
                                    finalCategory = newCatName;
                                  } else {
                                    finalCategory = selectedCategory;
                                  }
                                }

                                final stockData =
                                    {
                                      'name': nameController.text.trim(),
                                      'quantity': double.parse(
                                        quantityController.text,
                                      ),
                                      'unit': unitController.text.trim(),
                                      'lowStockThreshold': double.parse(
                                        lowStockThresholdController.text,
                                      ),
                                      'lastUpdated':
                                          FieldValue.serverTimestamp(),
                                      'isSellable': isSellable,
                                      'price':
                                          isSellable &&
                                              priceController.text.isNotEmpty
                                          ? double.tryParse(
                                              priceController.text,
                                            )
                                          : null,
                                      'description':
                                          isSellable &&
                                              descriptionController
                                                  .text
                                                  .isNotEmpty
                                          ? descriptionController.text.trim()
                                          : null,
                                      'category': isSellable
                                          ? finalCategory
                                          : null,
                                      'isMerchandise': false,
                                      'imageUrl': null,
                                      'linkedStockItemIds': linkedStockItemIds,
                                    }..removeWhere(
                                      (key, value) =>
                                          value == null && key != 'price',
                                    );

                                // Validate duplicate name
                                final newName = nameController.text.trim();
                                final bool nameChanged =
                                    isNewItem ||
                                    newName.toLowerCase() !=
                                        item.name.toLowerCase();
                                if (nameChanged) {
                                  final dupQuery = await _tenant
                                      .stockItems()
                                      .where('isMerchandise', isEqualTo: false)
                                      .where('name', isEqualTo: newName)
                                      .limit(1)
                                      .get();
                                  if (dupQuery.docs.isNotEmpty) {
                                    if (stateContext.mounted) {
                                      stateContext.showErrorSnackbar(
                                        'An item with this name already exists.',
                                      );
                                    }
                                    return;
                                  }
                                }

                                try {
                                  if (!isNewItem) {
                                    final newQty = double.parse(
                                      quantityController.text,
                                    );
                                    if ((newQty - item.quantity).abs() > 1e-9) {
                                      final u =
                                          FirebaseAuth.instance.currentUser;
                                      await StockService.setQuantity(
                                        tenant: _tenant,
                                        itemId: docId,
                                        quantity: newQty,
                                        reason: 'Manual stock edit (cafe)',
                                        updatedById: u?.uid,
                                        updatedByName:
                                            u?.displayName ?? u?.email,
                                      );
                                      StockHelper.invalidateCache(docId);
                                    }
                                  }
                                  await _tenant
                                      .stockItems()
                                      .doc(docId)
                                      .set(stockData, SetOptions(merge: true));

                                  final costTrim = unitCostController.text
                                      .trim();
                                  final desiredCost = costTrim.isEmpty
                                      ? null
                                      : double.tryParse(costTrim);
                                  if (costTrim.isNotEmpty &&
                                      desiredCost == null) {
                                    if (stateContext.mounted) {
                                      stateContext.showErrorSnackbar(
                                        'Invalid unit cost.',
                                      );
                                    }
                                    return;
                                  }
                                  try {
                                    final u = FirebaseAuth.instance.currentUser;
                                    await StockCostService.syncManualUnitCost(
                                      tenant: _tenant,
                                      itemId: docId,
                                      desiredUnitCost: desiredCost,
                                      updatedById: u?.uid,
                                      updatedByName: u?.displayName ?? u?.email,
                                    );
                                    StockHelper.invalidateCache(docId);
                                  } on Exception catch (e) {
                                    if (stateContext.mounted) {
                                      stateContext.showErrorSnackbar(
                                        e.userMessage,
                                      );
                                    }
                                    return;
                                  }

                                  final savedSnap = await _tenant
                                      .stockItems()
                                      .doc(docId)
                                      .get();
                                  if (savedSnap.exists) {
                                    await PublicVenueSyncService.syncPublicMenuFromStockItem(
                                      _tenant,
                                      StockItem.fromFirestore(savedSnap),
                                    );
                                  }

                                  if (stateContext.mounted) {
                                    stateContext.showSuccessSnackbar(
                                      'Stock item ${isNewItem ? 'added' : 'updated'} successfully.',
                                    );
                                  }
                                  if (context.mounted) Navigator.pop(context);
                                } on Exception catch (e) {
                                  if (stateContext.mounted) {
                                    stateContext.showErrorSnackbar(
                                      e.userMessage,
                                    );
                                  }
                                } catch (e) {
                                  if (stateContext.mounted) {
                                    stateContext.showErrorSnackbar('Error: $e');
                                  }
                                }
                              }
                            },
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
  }

  Future<void> _confirmDeleteStockItem(StockItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _tenant.stockItems().doc(item.id).delete();
        await PublicVenueSyncService.removePublicMenuMirrorForStockId(
          _tenant,
          item.id,
        );
        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.primaryContainer,
              content: Text(
                '"${item.name}" deleted from stock.',
                style: TextStyle(color: cs.onPrimaryContainer),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.errorContainer,
              content: Text(
                'Error deleting stock item: $e',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _showRestockDialog(StockItem item) async {
    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController();

    final double? qtyToAdd = await showDialog<double>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.add_circle_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add Stock',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adding to: ${item.name}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: qtyController,
                    autofocus: true,
                    decoration: AppTheme.baseInputDecoration.copyWith(
                      labelText: 'Quantity to Add',
                      suffixText: item.unit,
                      prefixIcon: const Icon(Icons.exposure_plus_1_rounded),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final val = double.tryParse(v);
                      if (val == null || val <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(AppStrings.cancel),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(
                              context,
                              double.parse(qtyController.text),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Add Stock'),
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

    if (qtyToAdd != null) {
      await _updateItemQuantity(item, qtyToAdd);
    }
  }

  // ========= Global Add Stock =========
  Future<void> _showGlobalRestockDialog() async {
    final stateContext = context;
    final itemsSnapshot = await _tenant
        .stockItems()
        .where('isMerchandise', isEqualTo: false)
        .orderBy('name')
        .get();

    final List<StockItem> items = itemsSnapshot.docs
        .map((d) => StockItem.fromFirestore(d))
        .toList();

    if (items.isEmpty) {
      if (stateContext.mounted) {
        stateContext.showInfoSnackbar('No items found. Create items first.');
      }
      return;
    }

    StockItem? selectedItem;
    final qtyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    if (!stateContext.mounted) return;
    final double? qtyToAdd = await showDialog<double>(
      context: stateContext,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_rounded,
                          color: Theme.of(dialogContext).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Quick Restock',
                          style: Theme.of(dialogContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Builder(
                      builder: (ctx) {
                        final th = Theme.of(ctx);
                        final stockChoices = items
                            .map(
                              (e) => DropdownMenuItem<StockItem>(
                                value: e,
                                child: Text(e.name),
                              ),
                            )
                            .toList();
                        return DropdownButtonFormField<StockItem>(
                          key: ValueKey<String?>(selectedItem?.id),
                          initialValue: selectedItem,
                          isExpanded: true,
                          decoration: AppTheme.baseInputDecoration.copyWith(
                            labelText: 'Select Item',
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                          items: stockChoices,
                          selectedItemBuilder: (context) =>
                              AppTheme.dropdownSelectedItemBuilders(
                                th,
                                stockChoices,
                              ),
                          onChanged: (val) =>
                              setState(() => selectedItem = val),
                          validator: (v) =>
                              selectedItem == null ? 'Required' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: qtyController,
                      decoration: AppTheme.baseInputDecoration.copyWith(
                        labelText: 'Quantity to Add',
                        suffixText: selectedItem?.unit,
                        prefixIcon: const Icon(
                          Icons.add_circle_outline_rounded,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(AppStrings.cancel),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(
                                dialogContext,
                                double.parse(qtyController.text),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              dialogContext,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              dialogContext,
                            ).colorScheme.onPrimary,
                          ),
                          child: const Text('Add Stock'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (qtyToAdd != null && selectedItem != null) {
      await _updateItemQuantity(selectedItem!, qtyToAdd);
    }
  }

  // ========= Damage Item =========
  Future<void> _showDamageItemDialog() async {
    final stateContext = context;
    final itemsSnapshot = await _tenant
        .stockItems()
        .where('isMerchandise', isEqualTo: false)
        .orderBy('name')
        .get();

    final List<StockItem> items = itemsSnapshot.docs
        .map((d) => StockItem.fromFirestore(d))
        .toList();

    if (items.isEmpty) {
      if (stateContext.mounted) {
        stateContext.showInfoSnackbar('No items found.');
      }
      return;
    }

    StockItem? selectedItem;
    final qtyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    if (!stateContext.mounted) return;
    final double? qtyToSubtract = await showDialog<double>(
      context: stateContext,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          color: Theme.of(dialogContext).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Report Damage',
                          style: Theme.of(dialogContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Builder(
                      builder: (ctx) {
                        final th = Theme.of(ctx);
                        final stockChoices = items
                            .map(
                              (e) => DropdownMenuItem<StockItem>(
                                value: e,
                                child: Text(e.name),
                              ),
                            )
                            .toList();
                        return DropdownButtonFormField<StockItem>(
                          key: ValueKey<String?>(selectedItem?.id),
                          initialValue: selectedItem,
                          isExpanded: true,
                          decoration: AppTheme.baseInputDecoration.copyWith(
                            labelText: 'Select Item',
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                          items: stockChoices,
                          selectedItemBuilder: (context) =>
                              AppTheme.dropdownSelectedItemBuilders(
                                th,
                                stockChoices,
                              ),
                          onChanged: (val) =>
                              setState(() => selectedItem = val),
                          validator: (v) =>
                              selectedItem == null ? 'Required' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: qtyController,
                      decoration: AppTheme.baseInputDecoration.copyWith(
                        labelText: 'Quantity Damaged',
                        suffixText: selectedItem?.unit,
                        prefixIcon: const Icon(
                          Icons.remove_circle_outline_rounded,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) return 'Must be > 0';
                        if (selectedItem != null &&
                            val > selectedItem!.quantity) {
                          return 'Only ${selectedItem!.quantity} in stock';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(AppStrings.cancel),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(
                                dialogContext,
                                double.parse(qtyController.text),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              dialogContext,
                            ).colorScheme.tertiary,
                            foregroundColor: Theme.of(
                              dialogContext,
                            ).colorScheme.onTertiary,
                          ),
                          child: const Text('Update Stock'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (qtyToSubtract != null && selectedItem != null) {
      await _updateItemQuantity(selectedItem!, -qtyToSubtract);
    }
  }

  Future<void> _updateItemQuantity(StockItem item, double delta) async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      await StockService.updateQuantity(
        tenant: _tenant,
        itemId: item.id,
        adjustment: delta,
        reason: delta > 0 ? 'Quick restock' : 'Damage / loss',
        updatedById: u?.uid,
        updatedByName: u?.displayName ?? u?.email,
      );
      StockHelper.invalidateCache(item.id);

      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        final action = delta > 0 ? 'Added' : 'Removed';
        final bg = delta > 0 ? cs.primaryContainer : cs.tertiaryContainer;
        final fg = delta > 0 ? cs.onPrimaryContainer : cs.onTertiaryContainer;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$action ${delta.abs().toStringAsFixed(item.unit == 'piece' || item.unit == 'pcs' ? 0 : 2)} ${item.unit} ${delta > 0 ? 'to' : 'from'} "${item.name}"',
              style: TextStyle(color: fg),
            ),
            backgroundColor: bg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        context.showErrorSnackbar(e.userMessage);
      }
    }
  }
}
