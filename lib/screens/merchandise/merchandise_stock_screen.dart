import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/permission_id.dart';
import '../../firestore/tenant_firestore.dart';
import '../../models/stock_item.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import 'dart:typed_data';
import '../../utils/app_logger.dart';
import '../../utils/snackbar_helper.dart';
import '../../services/stock_cost_service.dart';
import '../../services/stock_helper.dart';
import '../../services/stock_service.dart';
import '../../utils/business_validators.dart';
import '../../widgets/linked_stock_picker.dart';
import '../../widgets/stock_category_selection_field.dart';
import '../inventory/inventory_hub_screen.dart';
import '../../widgets/glass_modal_bottom_sheet.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class MerchandiseStockScreen extends ConsumerStatefulWidget {
  const MerchandiseStockScreen({super.key});

  @override
  ConsumerState<MerchandiseStockScreen> createState() =>
      _MerchandiseStockScreenState();
}

class _MerchandiseStockScreenState
    extends ConsumerState<MerchandiseStockScreen> {
  TenantRef get _tenant {
    final t = ref.read(tenantRefProvider);
    if (t == null) throw StateError('Company required');
    return t;
  }

  String _searchTerm = '';
  String _selectedCategory = 'All';
  bool _showLowStockOnly = false;
  final TextEditingController _searchController = TextEditingController();
  Uint8List? _selectedImageData;
  String? _selectedImageExt;

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
    final isMobile = AppTheme.isMobile(context);
    if (!ref.watchResolvedPermissions().can(
      PermissionIds.opsMerchandiseManage,
    )) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stock')),
        body: const Center(
          child: Text(
            'You do not have access to merchandise stock management.',
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-merchandise-stock',
        onPressed: _showAddOptionsBottomSheet,
        label: Text(
          'Create New Item',
          style: TextStyle(fontSize: isMobile ? 13 : 14),
        ),
        icon: Icon(Icons.add_rounded, size: isMobile ? 20 : 24),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(
              isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
            ),
            child: TextField(
              controller: _searchController,
              decoration: AppTheme.baseInputDecoration.copyWith(
                labelText: 'Search Merchandise',
                labelStyle: TextStyle(fontSize: isMobile ? 13 : 14),
                hintText: 'Enter item name...',
                hintStyle: TextStyle(fontSize: isMobile ? 13 : 14),
                prefixIcon: Icon(Icons.search, size: isMobile ? 20 : 24),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 14,
                ),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: isMobile ? 20 : 24),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _tenant
                  .stockItems()
                  .where(
                    'isMerchandise',
                    isEqualTo: true,
                  ) // Filter for merchandise
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var stockItems = snapshot.data!.docs
                    .map((doc) => StockItem.fromFirestore(doc))
                    .toList();

                // Build dynamic category list
                final List<String> categories = [
                  'All',
                  ...{
                    for (var it in stockItems)
                      if (it.category != null && it.category!.isNotEmpty)
                        it.category!,
                  },
                ];

                if (_searchTerm.isNotEmpty) {
                  stockItems = stockItems
                      .where(
                        (item) => item.name.toLowerCase().contains(_searchTerm),
                      )
                      .toList();
                }

                // Apply category filter
                if (_selectedCategory != 'All') {
                  stockItems = stockItems
                      .where((item) => item.category == _selectedCategory)
                      .toList();
                }

                // Low stock filter
                if (_showLowStockOnly) {
                  stockItems = stockItems
                      .where(
                        (it) =>
                            it.quantity <= it.lowStockThreshold &&
                            it.lowStockThreshold > 0,
                      )
                      .toList();
                }

                // Summary chips
                final int totalItems = stockItems.length;
                final int lowStockCount = stockItems
                    .where(
                      (it) =>
                          it.quantity <= it.lowStockThreshold &&
                          it.lowStockThreshold > 0,
                    )
                    .length;

                final theme = Theme.of(context);
                final cs = theme.colorScheme;

                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: isMobile
                            ? AppTheme.kSpacingSmall
                            : AppTheme.kSpacingMedium,
                        right: isMobile
                            ? AppTheme.kSpacingSmall
                            : AppTheme.kSpacingMedium,
                        bottom: AppTheme.kSpacingSmall,
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Chip(
                                      avatar: const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        'Total: $totalItems',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      avatar: Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: lowStockCount > 0
                                            ? cs.onErrorContainer
                                            : cs.onPrimaryContainer,
                                      ),
                                      label: Text(
                                        'Low Stock: $lowStockCount',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: lowStockCount > 0
                                          ? cs.errorContainer
                                          : cs.primaryContainer,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _showGlobalRestockDialog,
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Add Stock',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(10, 36),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _showDamageItemDialog,
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Damage',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: cs.tertiary,
                                          foregroundColor: cs.onTertiary,
                                          minimumSize: const Size(10, 36),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
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
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(10, 36),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Chip(
                                  avatar: const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 18,
                                  ),
                                  label: Text('Total: $totalItems'),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  avatar: Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: lowStockCount > 0
                                        ? cs.onErrorContainer
                                        : cs.onPrimaryContainer,
                                  ),
                                  label: Text('Low Stock: $lowStockCount'),
                                  backgroundColor: lowStockCount > 0
                                      ? cs.errorContainer
                                      : cs.primaryContainer,
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  onPressed: _showGlobalRestockDialog,
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text('Add Stock'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(10, 36),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _showDamageItemDialog,
                                  icon: const Icon(Icons.remove_circle_outline),
                                  label: const Text('Damage Item'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.tertiary,
                                    foregroundColor: cs.onTertiary,
                                    minimumSize: const Size(10, 36),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
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
                                  label: const Text('Vendor'),
                                ),
                              ],
                            ),
                    ),
                    // Filter Row
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile
                            ? AppTheme.kSpacingSmall
                            : AppTheme.kSpacingMedium,
                        vertical: 4,
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Builder(
                                  builder: (ctx) {
                                    final th = Theme.of(ctx);
                                    final categoryFilterItems = categories
                                        .map(
                                          (cat) => DropdownMenuItem<String>(
                                            value: cat,
                                            child: Text(
                                              cat[0].toUpperCase() +
                                                  cat.substring(1),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList();
                                    return DropdownButtonFormField<String>(
                                      initialValue: _selectedCategory,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Category',
                                        labelStyle: const TextStyle(
                                          fontSize: 13,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.kBorderRadiusSmall,
                                          ),
                                        ),
                                      ),
                                      items: categoryFilterItems,
                                      selectedItemBuilder: (context) =>
                                          AppTheme.dropdownSelectedItemBuilders(
                                            th,
                                            categoryFilterItems,
                                          ),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(
                                            () => _selectedCategory = val,
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _showLowStockOnly,
                                      onChanged: (val) {
                                        setState(
                                          () =>
                                              _showLowStockOnly = val ?? false,
                                        );
                                      },
                                    ),
                                    const Text(
                                      'Low Stock Only',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                DropdownButton<String>(
                                  value: _selectedCategory,
                                  items: categories
                                      .map(
                                        (cat) => DropdownMenuItem<String>(
                                          value: cat,
                                          child: Text(
                                            cat[0].toUpperCase() +
                                                cat.substring(1),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedCategory = val);
                                    }
                                  },
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _showLowStockOnly,
                                      onChanged: (val) {
                                        setState(
                                          () =>
                                              _showLowStockOnly = val ?? false,
                                        );
                                      },
                                    ),
                                    const Text('Low Stock Only'),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    Expanded(
                      child: stockItems.isEmpty
                          ? Center(
                              child: Text(
                                _searchTerm.isNotEmpty
                                    ? 'No merchandise items match your search.'
                                    : _showLowStockOnly
                                    ? 'No items are currently low on stock.'
                                    : 'No merchandise found. Add some to get started!',
                                style: TextStyle(
                                  fontSize: isMobile ? 15 : 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Builder(
                              builder: (context) {
                                final hPad = isMobile
                                    ? AppTheme.kSpacingSmall
                                    : AppTheme.kSpacingMedium;
                                return ListView.separated(
                                  physics: AppTheme.scrollPhysicsFor(context),
                                  padding: EdgeInsets.fromLTRB(
                                    hPad,
                                    0,
                                    hPad,
                                    88,
                                  ),
                                  itemCount: stockItems.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                  itemBuilder: (context, index) {
                                    return _buildStockListRow(
                                      stockItems[index],
                                      isMobile,
                                    );
                                  },
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
    );
  }

  Widget _buildStockListRow(StockItem item, bool isMobile) {
    final isLowStock =
        item.quantity <= item.lowStockThreshold && item.lowStockThreshold > 0;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final qtyStr =
        '${item.quantity.toStringAsFixed(item.unit == 'piece' || item.unit == 'pcs' ? 0 : 2)} ${item.unit}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEditItemDialog(context, item: item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 8 : 10,
            horizontal: 4,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: isMobile ? 20 : 22,
                backgroundColor: isLowStock
                    ? cs.errorContainer.withValues(alpha: 0.5)
                    : cs.secondaryContainer.withValues(alpha: 0.6),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: isLowStock ? cs.error : cs.primary,
                  size: isMobile ? 20 : 22,
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 13 : 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.category != null && item.category!.isNotEmpty) ...[
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
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                        if (item.isSellable && item.price != null)
                          Text(
                            '₹${item.price!.toStringAsFixed(2)}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
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
                tooltip: 'Add stock',
                iconSize: isMobile ? 22 : 24,
                onPressed: () => _showRestockDialog(item),
                icon: Icon(Icons.add_circle_outline_rounded, color: cs.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditItemDialog(
    BuildContext scaffoldContext, {
    StockItem? item,
  }) async {
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
    bool isSellable = item?.isSellable ?? true;
    final priceController = TextEditingController(
      text: item?.price?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    final imageUrlController = TextEditingController(
      text: item?.imageUrl ?? '',
    );
    String? selectedCategory = item?.category;
    bool addingNewCategory = false;
    final newCategoryController = TextEditingController();

    if (unitController.text.isEmpty) {
      unitController.text = 'piece';
    }

    final String docId = item?.id ?? _tenant.stockItems().doc().id;
    final linkedStockItemIds = List<String>.from(
      item?.linkedStockItemIds ?? [],
    );

    await showDialog<void>(
      context: scaffoldContext,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                item == null ? 'Add New Merchandise' : 'Edit Merchandise',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: AppTheme.baseInputDecoration.copyWith(
                          labelText: 'Item Name',
                          prefixIcon: const Icon(Icons.shopping_bag_outlined),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter item name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: quantityController,
                              decoration: AppTheme.baseInputDecoration.copyWith(
                                labelText: 'Quantity',
                                prefixIcon: const Icon(Icons.numbers_outlined),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Enter quantity';
                                }
                                if (double.tryParse(v) == null) {
                                  return 'Invalid number';
                                }
                                if (double.parse(v) < 0) {
                                  return 'Cannot be negative';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: unitController,
                              decoration: AppTheme.baseInputDecoration.copyWith(
                                labelText: 'Unit (e.g., piece, kg)',
                                prefixIcon: const Icon(Icons.category_outlined),
                              ),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Enter unit' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: lowStockThresholdController,
                        decoration: AppTheme.baseInputDecoration.copyWith(
                          labelText: 'Low Stock Threshold',
                          prefixIcon: const Icon(Icons.warning_amber_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v != null &&
                              v.isNotEmpty &&
                              double.tryParse(v) == null) {
                            return 'Invalid number';
                          }
                          if (v != null &&
                              v.isNotEmpty &&
                              double.parse(v) < 0) {
                            return 'Cannot be negative';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: unitCostController,
                        decoration: AppTheme.baseInputDecoration.copyWith(
                          labelText: 'Unit cost — what we pay (₹)',
                          hintText: 'Optional; vendor receipts update this',
                          prefixIcon: const Icon(Icons.payments_outlined),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = double.tryParse(v.trim());
                          if (n == null) return 'Invalid amount';
                          if (n < 0) return 'Cannot be negative';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppTheme.subtleDividerColor(Theme.of(context)),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text('Is this item sellable?'),
                        value: isSellable,
                        onChanged: (val) => setDialogState(() {
                          isSellable = val;
                          if (!val) {
                            selectedCategory = null;
                            addingNewCategory = false;
                            newCategoryController.clear();
                          }
                        }),
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        secondary: Icon(
                          isSellable
                              ? Icons.storefront_outlined
                              : Icons.no_encryption_gmailerrorred_outlined,
                        ),
                      ),
                      if (isSellable) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: priceController,
                          decoration: AppTheme.baseInputDecoration.copyWith(
                            labelText: 'Price (₹)',
                            prefixIcon: const Icon(Icons.price_change_outlined),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (!isSellable) return null;
                            if (v == null || v.isEmpty) return 'Enter price';
                            if (double.tryParse(v) == null) {
                              return 'Invalid price';
                            }
                            if (double.parse(v) <= 0) {
                              return 'Price must be > 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        StockCategorySelectionField(
                          tenant: _tenant,
                          isMerchandise: true,
                          selectedCategory: selectedCategory,
                          addingNewCategory: addingNewCategory,
                          newCategoryController: newCategoryController,
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
                              addingNewCategory = isAdding;
                              if (!isAdding) {
                                newCategoryController.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descriptionController,
                          decoration: AppTheme.baseInputDecoration.copyWith(
                            labelText: 'Description (Optional)',
                            prefixIcon: const Icon(Icons.description_outlined),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: imageUrlController,
                          decoration: AppTheme.baseInputDecoration.copyWith(
                            labelText: 'Image URL (Optional)',
                            prefixIcon: const Icon(Icons.image_outlined),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.upload_file_rounded),
                              tooltip: 'Upload Image',
                              onPressed: () async {
                                final result = await FilePicker.platform
                                    .pickFiles(
                                      type: FileType.image,
                                      withData: true,
                                    );
                                if (result != null && result.files.isNotEmpty) {
                                  final file = result.files.single;
                                  if (file.bytes != null) {
                                    _selectedImageData = file.bytes!;
                                    _selectedImageExt = file.extension
                                        ?.toLowerCase();
                                    imageUrlController.text =
                                        'New image selected: ${file.name}';
                                  }
                                }
                              },
                            ),
                          ),
                          keyboardType: TextInputType.url,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Linked stock (vendor receipts)',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
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
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...linkedStockItemIds.map(
                                  (lid) => InputChip(
                                    label: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 200,
                                      ),
                                      child: LinkedStockItemLabel(
                                        id: lid,
                                        tenant: _tenant,
                                      ),
                                    ),
                                    onDeleted: () => setDialogState(
                                      () => linkedStockItemIds.remove(lid),
                                    ),
                                  ),
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.add, size: 18),
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
                                        linkedStockItemIds.add(picked.id);
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      // Check for duplicate item name within merchandise stock (isMerchandise == true)
                      final newName = nameController.text.trim();
                      final bool isNewItem = item == null;
                      final bool nameChanged =
                          isNewItem ||
                          newName.toLowerCase() != item.name.toLowerCase();
                      if (nameChanged) {
                        final dupQuery = await _tenant
                            .stockItems()
                            .where('isMerchandise', isEqualTo: true)
                            .where('name', isEqualTo: newName)
                            .limit(1)
                            .get();
                        if (dupQuery.docs.isNotEmpty) {
                          if (scaffoldContext.mounted) {
                            scaffoldContext.showWarningSnackbar(
                              'An item with this name already exists.',
                            );
                          }
                          return;
                        }
                      }

                      // Determine category
                      String? finalCategory;
                      if (isSellable) {
                        if (addingNewCategory) {
                          final newCat = newCategoryController.text.trim();
                          if (newCat.isEmpty) {
                            if (scaffoldContext.mounted) {
                              scaffoldContext.showErrorSnackbar(
                                'Please enter category name',
                              );
                            }
                            return;
                          }
                          finalCategory = newCat;
                          await _tenant.categories().add({
                            'name': newCat,
                            'isMerchandise': true,
                          });
                        } else {
                          finalCategory = selectedCategory;
                        }
                      }

                      final newItem = StockItem(
                        id: docId,
                        name: nameController.text,
                        quantity: double.tryParse(quantityController.text) ?? 0,
                        unit: unitController.text,
                        lastUpdated: Timestamp.now(),
                        lowStockThreshold:
                            double.tryParse(lowStockThresholdController.text) ??
                            0,
                        isSellable: isSellable,
                        price: isSellable
                            ? (double.tryParse(priceController.text) ?? 0)
                            : null,
                        description: isSellable
                            ? descriptionController.text
                            : null,
                        imageUrl: isSellable ? imageUrlController.text : null,
                        category: isSellable ? finalCategory : null,
                        isMerchandise: true,
                        lastUnitCost: null,
                        linkedStockItemIds: linkedStockItemIds,
                      );

                      String? finalImageUrl = item?.imageUrl;
                      if (_selectedImageData != null) {
                        final ext = _selectedImageExt ?? 'png';
                        try {
                          if (!context.mounted) return;
                          unawaited(
                            showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          );

                          finalImageUrl = await StorageService()
                              .uploadStockImage(
                                _selectedImageData!,
                                itemId: docId,
                                isMerchandise: true,
                                fileExt: ext,
                              );
                        } catch (e, st) {
                          AppLogger.error(
                            'Image upload failed',
                            error: e,
                            stackTrace: st,
                            tag: 'MerchandiseStock',
                          );
                          if (context.mounted) Navigator.pop(context);
                          if (scaffoldContext.mounted) {
                            scaffoldContext.showErrorSnackbar(
                              'Image upload failed: $e',
                            );
                          }
                          return;
                        } finally {
                          if (context.mounted && Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        }
                      }

                      if (!isNewItem) {
                        final newQty =
                            double.tryParse(quantityController.text) ?? 0;
                        if ((newQty - item.quantity).abs() > 1e-9) {
                          try {
                            final u = FirebaseAuth.instance.currentUser;
                            await StockService.setQuantity(
                              tenant: _tenant,
                              itemId: docId,
                              quantity: newQty,
                              reason: 'Manual stock edit (merchandise)',
                              updatedById: u?.uid,
                              updatedByName: u?.displayName ?? u?.email,
                            );
                            StockHelper.invalidateCache(docId);
                          } on Exception catch (e) {
                            if (scaffoldContext.mounted) {
                              scaffoldContext.showErrorSnackbar(e.userMessage);
                            }
                            return;
                          }
                        }
                      }

                      final stockData = newItem.toFirestore();
                      stockData['imageUrl'] = finalImageUrl;

                      await _tenant
                          .stockItems()
                          .doc(docId)
                          .set(stockData, SetOptions(merge: true));

                      final costTrim = unitCostController.text.trim();
                      final desiredCost = costTrim.isEmpty
                          ? null
                          : double.tryParse(costTrim);
                      if (costTrim.isNotEmpty && desiredCost == null) {
                        if (scaffoldContext.mounted) {
                          scaffoldContext.showErrorSnackbar(
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
                        if (scaffoldContext.mounted) {
                          scaffoldContext.showErrorSnackbar(e.userMessage);
                        }
                        return;
                      }

                      if (scaffoldContext.mounted) {
                        scaffoldContext.showSuccessSnackbar(
                          '${stockData['name']} ${item == null ? 'added' : 'updated'} successfully!',
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: Text(item == null ? 'Add Item' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ======== Global Add Stock ========
  Future<void> _showGlobalRestockDialog() async {
    final stateContext = context;
    final itemsSnapshot = await _tenant
        .stockItems()
        .where('isMerchandise', isEqualTo: true)
        .orderBy('name')
        .get();

    final List<StockItem> items = itemsSnapshot.docs
        .map((d) => StockItem.fromFirestore(d))
        .toList();

    if (items.isEmpty) {
      if (stateContext.mounted) {
        stateContext.showInfoSnackbar('No merchandise items found.');
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

  // ======== Damage Item ========
  Future<void> _showDamageItemDialog() async {
    final stateContext = context;
    final itemsSnapshot = await _tenant
        .stockItems()
        .where('isMerchandise', isEqualTo: true)
        .orderBy('name')
        .get();

    final List<StockItem> items = itemsSnapshot.docs
        .map((d) => StockItem.fromFirestore(d))
        .toList();

    if (items.isEmpty) {
      if (stateContext.mounted) {
        stateContext.showInfoSnackbar('No merchandise items found.');
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
        final bg = delta > 0 ? cs.primaryContainer : cs.tertiaryContainer;
        final fg = delta > 0 ? cs.onPrimaryContainer : cs.onTertiaryContainer;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${delta > 0 ? 'Added' : 'Removed'} ${delta.abs().toStringAsFixed(item.unit == 'piece' || item.unit == 'pcs' ? 0 : 2)} ${item.unit} ${delta > 0 ? 'to' : 'from'} "${item.name}"',
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

  // ======= Add Options Bottom Sheet (Create New / Bulk) =======
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
                  _showEditItemDialog(context);
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

  /// Dialog for bulk adding merchandise items in CSV-like format (one item per line)
  /// Note: Currently using _showBulkAddStockItemsDialog instead. Retained for future use.
  // ignore: unused_element
  Future<void> _showBulkAddMerchandiseItemsDialog() async {
    final formKey = GlobalKey<FormState>();
    final bulkController = TextEditingController();
    String? selectedFileName;
    final stateContext = context;

    await showDialog<void>(
      context: stateContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bulk Add Merchandise Stock'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter each item on a new line in the following format:\n'
                  'name, quantity, unit, price(optional), lowStock(optional)\n\n'
                  'Example:\nT-Shirt, 20, piece, 499, 5\nKeychain, 50, pcs',
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
                          hintText: 'Mug, 30, piece, 299, 3',
                        ),
                        validator: (value) {
                          if ((value == null || value.trim().isEmpty) &&
                              (selectedFileName == null)) {
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
                          selectedFileName = file.name;
                          if (file.bytes != null) {
                            final content = String.fromCharCodes(file.bytes!);
                            bulkController.text = content.trim();
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
              final existingStockMap = <String, String>{};

              for (var rawLine in lines) {
                final line = rawLine.trim();
                if (line.isEmpty) continue;
                final parts = line.split(',').map((e) => e.trim()).toList();
                if (parts.length < 3) continue; // invalid line

                final name = parts[0];
                final quantity = double.tryParse(parts[1]) ?? 0;
                final unit = parts[2].isNotEmpty ? parts[2] : 'piece';
                final double? price = parts.length > 3
                    ? double.tryParse(parts[3])
                    : null;
                final lowStock = parts.length > 4
                    ? double.tryParse(parts[4]) ?? 0
                    : 0;

                if (name.isEmpty || quantity <= 0) {
                  continue; // skip invalid entry
                }

                final nameKey = name.toLowerCase();
                if (existingStockMap.containsKey(nameKey)) {
                  final docId = existingStockMap[nameKey]!;
                  final docRef = _tenant.stockItems().doc(docId);
                  try {
                    final u = FirebaseAuth.instance.currentUser;
                    await StockService.updateQuantity(
                      tenant: _tenant,
                      itemId: docId,
                      adjustment: quantity,
                      reason: 'Bulk import (CSV)',
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
                    'unit': unit,
                    'lowStockThreshold': lowStock,
                    'lastUpdated': FieldValue.serverTimestamp(),
                    'isSellable': true,
                    'price': price,
                  });
                  updatedCount++;
                  existingStockMap[nameKey] = docId;
                } else {
                  // Add new item
                  final docRef = _tenant.stockItems().doc();
                  batch.set(docRef, {
                    'name': name,
                    'quantity': quantity,
                    'unit': unit,
                    'lowStockThreshold': lowStock,
                    'lastUpdated': FieldValue.serverTimestamp(),
                    'isSellable': true,
                    'price': price,
                    'isMerchandise': true,
                  });
                  successCount++;
                  existingStockMap[nameKey] = docRef.id;
                }
              }

              if (successCount == 0 && updatedCount == 0) {
                if (!stateContext.mounted) return;
                stateContext.showWarningSnackbar('No valid items found.');
                return;
              }

              try {
                await batch.commit();
                if (!stateContext.mounted) return;
                final message = successCount > 0 && updatedCount > 0
                    ? '$successCount items added, $updatedCount items updated.'
                    : successCount > 0
                    ? '$successCount items added to stock.'
                    : '$updatedCount items updated.';
                stateContext.showSuccessSnackbar(message);
                Navigator.pop(dialogContext);
              } catch (e) {
                if (!stateContext.mounted) return;
                stateContext.showErrorSnackbar('Error adding items: $e');
              }
            },
            child: const Text('Add Items'),
          ),
        ],
      ),
    );
  }

  // ======= Add Options Bottom Sheet =======
  void _showBulkAddStockItemsDialog() async {
    final formKey = GlobalKey<FormState>();
    final bulkController = TextEditingController();
    final stateContext = context;

    await showDialog<void>(
      context: stateContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bulk Add Merchandise'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Each line sets total on-hand quantity for that item name.\n'
                  'New items are created; existing merchandise rows are updated and logged in stock history.\n'
                  'Format: name, quantity, unit, lowStock(optional)\n\n'
                  'Example:\nT-Shirt, 20, piece, 5',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: bulkController,
                        maxLines: 10,
                        decoration: AppTheme.baseInputDecoration.copyWith(
                          hintText: 'Cap, 15, piece, 3',
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
                            bulkController.text = currentText.isEmpty
                                ? fileContent
                                : '$currentText\n$fileContent';
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

              // Existing merchandise items map
              final existingSnapshot = await _tenant
                  .stockItems()
                  .where('isMerchandise', isEqualTo: true)
                  .get();
              if (!stateContext.mounted) return;
              final existingMap = {
                for (var doc in existingSnapshot.docs)
                  ((doc.data()['name'] as String?) ?? '').toLowerCase(): doc.id,
              };

              for (var raw in lines) {
                final line = raw.trim();
                if (line.isEmpty) continue;
                final parts = line.split(',').map((e) => e.trim()).toList();
                if (parts.length < 3) continue;

                final name = parts[0];
                final quantity = double.tryParse(parts[1]) ?? 0;
                final unit = parts[2].isNotEmpty ? parts[2] : 'piece';
                final lowStock = parts.length > 3
                    ? double.tryParse(parts[3]) ?? 0
                    : 0;

                if (name.isEmpty || quantity < 0) continue;

                final data = {
                  'name': name,
                  'quantity': quantity,
                  'unit': unit,
                  'lowStockThreshold': lowStock,
                  'lastUpdated': FieldValue.serverTimestamp(),
                  'isSellable': false,
                  'isMerchandise': true,
                };

                final key = name.toLowerCase();
                if (existingMap.containsKey(key)) {
                  final docId = existingMap[key]!;
                  final docRef = _tenant.stockItems().doc(docId);
                  try {
                    final u = FirebaseAuth.instance.currentUser;
                    await StockService.setQuantity(
                      tenant: _tenant,
                      itemId: docId,
                      quantity: quantity,
                      reason: 'Bulk import: set on-hand (merchandise)',
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
                    'isMerchandise': true,
                  });
                  updatedCount++;
                } else {
                  batch.set(_tenant.stockItems().doc(), data);
                  successCount++;
                }
              }

              if (successCount == 0 && updatedCount == 0) {
                if (!stateContext.mounted) return;
                stateContext.showWarningSnackbar(
                  'No valid items found to add.',
                );
                return;
              }

              try {
                await batch.commit();
                if (!stateContext.mounted) return;
                final message = successCount > 0 && updatedCount > 0
                    ? '$successCount added, $updatedCount updated.'
                    : successCount > 0
                    ? '$successCount item(s) added successfully.'
                    : '$updatedCount item(s) updated.';
                stateContext.showSuccessSnackbar(message);
                Navigator.pop(dialogContext);
              } catch (e) {
                if (!stateContext.mounted) return;
                stateContext.showErrorSnackbar('Error adding items: $e');
              }
            },
            child: const Text('Add Items'),
          ),
        ],
      ),
    );
  }

  // ======= Per-item Restock Dialog =======
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

  // ======= Delete (existing helper, for future admin functionality) =======
  // ignore: unused_element
  Future<void> _confirmDeleteMerchandiseItem(StockItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _tenant.stockItems().doc(item.id).delete();
        if (mounted) {
          context.showSuccessSnackbar('"${item.name}" deleted successfully.');
        }
      } catch (e) {
        if (mounted) {
          context.showErrorSnackbar('Error deleting item: $e');
        }
      }
    }
  }
}
