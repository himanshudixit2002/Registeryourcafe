import 'package:flutter/material.dart';
import 'package:registeryourcafe/providers/ledger_provider.dart';
import 'package:registeryourcafe/providers/tenant_provider.dart';
import 'package:registeryourcafe/firestore/tenant_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../refund/unified_refund_screen.dart';
import 'package:registeryourcafe/services/order_id_service.dart';
import '../../models/merchandise_order.dart';
import '../../models/customer.dart';
import '../../models/stock_item.dart';
import '../../models/table.dart';
import '../../models/session.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import './merchandise_stock_screen.dart';
import 'dart:async'; // For Timer if we add duration display, not strictly needed for now
import '../../widgets/dialogs/customer_selection_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/auth/permission_id.dart';
import 'package:registeryourcafe/providers/auth_provider.dart';
import 'package:registeryourcafe/providers/permissions_provider.dart';
import '../../services/printer_service.dart';
import '../../widgets/dialogs/item_revenue_dialog.dart';
import 'package:registeryourcafe/utils/credit_verification.dart';
import 'package:registeryourcafe/utils/app_logger.dart';
import 'package:registeryourcafe/services/credit_service.dart';
import '../../widgets/glass_panel.dart';
import 'package:flutter/services.dart';
import '../../widgets/floating_cart_button.dart';
import '../../widgets/cart_bottom_sheet.dart';
import '../../widgets/glass_modal_bottom_sheet.dart';
import './components/merchandise_order_card.dart';
import '../../widgets/customer_association_section.dart';
import '../../services/stock_helper.dart';
import 'package:registeryourcafe/utils/firestore_utils.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/constants/app_strings.dart';
import 'package:registeryourcafe/utils/snackbar_helper.dart';

class MerchandiseScreen extends ConsumerStatefulWidget {
  const MerchandiseScreen({super.key});

  @override
  ConsumerState<MerchandiseScreen> createState() => _MerchandiseScreenState();
}

class _MerchandiseScreenState extends ConsumerState<MerchandiseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MerchandiseOrderItem> currentOrderItems = [];
  Customer? selectedCustomer;
  SnookerTable? selectedTable;
  TableSession? _selectedTableSession;
  DateTimeRange? _selectedDateRange;
  String? _selectedOrderStatusFilter;
  bool _tableLocked = false; // when assigned from active session
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.navMerchandise)) {
      return const Scaffold(
        body: Center(child: Text('You do not have access to merchandise.')),
      );
    }

    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);
    final canManageMerch = ref.watchResolvedPermissions().can(
      PermissionIds.opsMerchandiseManage,
    );
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 16,
            vertical: isMobile ? 4 : 8,
          ),
          height: isMobile ? 36 : 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
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
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.w500,
            ),
            padding: EdgeInsets.all(isMobile ? 2 : 4),
            tabs: [
              Tab(text: isMobile ? 'Shop' : 'Shop'),
              Tab(text: isMobile ? 'History' : 'History'),
              const Tab(text: 'Stock'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildShopAndOrders(),
              _buildOrderHistory(),
              canManageMerch
                  ? const MerchandiseStockScreen()
                  : const Center(child: Text('Access Denied')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShopAndOrders() {
    final bool isMobile = AppTheme.isMobile(context);
    final merchandiseSection = Expanded(
      flex: isMobile
          ? 1
          : 2, // Takes full width on mobile if in Column, 2/3 on larger
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Merchandise',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.kSpacingMedium),
            _buildSearchField(),
            const SizedBox(height: AppTheme.kSpacingMedium),
            Expanded(child: _buildMerchandiseGrid()),
          ],
        ),
      ),
    );

    final cartSection = Expanded(
      flex: 1, // Takes full width on mobile if in Column, 1/3 on larger
      child: AppSurface(
        margin: EdgeInsets.all(
          isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
        ).copyWith(top: AppTheme.kSpacingMedium),
        borderRadius: AppTheme.kBorderRadiusLarge,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
              child: Text(
                'Current Cart', // Changed from Current Order to Current Cart
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.subtleDividerColor(Theme.of(context)),
            ),
            _buildOrderAssociationSection(),
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.subtleDividerColor(Theme.of(context)),
            ),
            Expanded(child: _buildCurrentOrderList()),
            Divider(
              height: 1,
              thickness: 1,
              indent: AppTheme.kSpacingMedium,
              endIndent: AppTheme.kSpacingMedium,
              color: AppTheme.subtleDividerColor(Theme.of(context)),
            ),
            _buildOrderSummaryAndActions(),
          ],
        ),
      ),
    );

    if (isMobile) {
      // For mobile, use full screen shop with floating cart button
      final theme = Theme.of(context);
      return Stack(
        children: [
          // Full-screen merchandise section
          Padding(
            padding: const EdgeInsets.all(AppTheme.kSpacingSmall),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shop',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Quick customer assign chip
                    if (selectedCustomer != null)
                      GestureDetector(
                        onTap: _showMobileCartSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selectedCustomer!.name.split(' ').first,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.kSpacingSmall),
                _buildSearchField(),
                const SizedBox(height: AppTheme.kSpacingSmall),
                Expanded(child: _buildMerchandiseGrid()),
              ],
            ),
          ),
          // Floating cart button
          FloatingCartButton(
            itemCount: currentOrderItems.fold(
              0,
              (totalQty, item) => totalQty + item.quantity,
            ),
            total: _calculateTotal(),
            onTap: _showMobileCartSheet,
          ),
        ],
      );
    } else {
      // For tablet/desktop, use Row
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [merchandiseSection, cartSection],
      );
    }
  }

  Widget _buildMerchandiseGrid() {
    final bool isMobile = AppTheme.isMobile(context);
    final TenantRef? tenant = ref.watch(tenantRefProvider);
    if (tenant == null) {
      return const Center(
        child: Text('Sign in with a company account to view merchandise.'),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: tenant
          .stockItems()
          .where('isMerchandise', isEqualTo: true)
          .where('isSellable', isEqualTo: true)
          .orderBy('category')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading merchandise: ${snapshot.error}'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          final cs = Theme.of(context).colorScheme;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 60,
                  color: cs.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No merchandise available.',
                  style: TextStyle(
                    fontSize: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add merchandise items in Stock Management.',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final merchandiseItems = snapshot.data!.docs
            .map((doc) => StockItem.fromFirestore(doc))
            .where((item) {
              if (_searchQuery.isEmpty) return true;
              final query = _searchQuery.toLowerCase();
              return item.name.toLowerCase().contains(query) ||
                  (item.description?.toLowerCase().contains(query) ?? false) ||
                  (item.category?.toLowerCase().contains(query) ?? false);
            })
            .toList();

        final hPad = isMobile
            ? AppTheme.kSpacingSmall
            : AppTheme.kSpacingMedium;
        return ListView.separated(
          physics: AppTheme.scrollPhysicsFor(context),
          padding: EdgeInsets.fromLTRB(
            hPad,
            0,
            hPad,
            isMobile ? 88 : AppTheme.kSpacingLarge,
          ),
          itemCount: merchandiseItems.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          itemBuilder: (context, index) {
            final item = merchandiseItems[index];
            return RepaintBoundary(
              key: ValueKey(item.id),
              child: _buildMerchandiseCard(item),
            );
          },
        );
      },
    );
  }

  Widget _buildMerchandiseCard(StockItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canManageMerch = ref.watchResolvedPermissions().can(
      PermissionIds.opsMerchandiseManage,
    );

    var isEffectivelyAvailable =
        item.isSellable &&
        item.quantity > 0 &&
        item.price != null &&
        item.price! > 0;
    var statusMessage = '';

    if (!item.isSellable) {
      isEffectivelyAvailable = false;
      statusMessage = 'Not available for sale';
    } else if (item.price == null || item.price! <= 0) {
      isEffectivelyAvailable = false;
      statusMessage = 'Price not set';
    } else if (item.quantity <= 0) {
      isEffectivelyAvailable = false;
      statusMessage = 'Out of stock';
    }

    final accent = colorScheme.primary;
    final sem = AppSemanticColors.of(context);
    Color stockTint;
    final isLowStock =
        item.quantity > 0 && item.quantity <= 5 && isEffectivelyAvailable;
    if (item.quantity <= 0) {
      stockTint = colorScheme.outline;
    } else if (isLowStock) {
      stockTint = colorScheme.error;
    } else {
      stockTint = sem.success;
    }
    final qtyLabel = item.quantity > 999
        ? '999+'
        : item.quantity.toStringAsFixed(
            item.unit == 'piece' || item.unit == 'pcs' ? 0 : 1,
          );

    final hasDescription =
        item.description != null && item.description!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEffectivelyAvailable ? () => _addToOrder(item) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 44,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: accent,
                  size: 22,
                ),
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
                        item.category!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.category!.trim(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (hasDescription) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description!.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.price != null && item.price! > 0)
                          Text(
                            '₹${item.price!.toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          )
                        else
                          Text(
                            'No price',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        _merchQtyChip(
                          context,
                          label: qtyLabel,
                          color: stockTint,
                          warn: isLowStock,
                        ),
                        if (isLowStock && isEffectivelyAvailable)
                          Text(
                            'Only ${item.quantity.toStringAsFixed(0)} left',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (!isEffectivelyAvailable)
                          Text(
                            statusMessage,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canManageMerch)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      tooltip: 'Analytics',
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => ItemRevenueDialog(item: item),
                        );
                      },
                      icon: Icon(
                        Icons.bar_chart_rounded,
                        size: 20,
                        color: accent,
                      ),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: isEffectivelyAvailable
                        ? () => _addToOrder(item)
                        : null,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _merchQtyChip(
    BuildContext context, {
    required String label,
    required Color color,
    required bool warn,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            warn ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToOrder(StockItem item) async {
    if (item.price == null || item.price! <= 0) {
      StockHelper.showStockError(
        context,
        'This item cannot be added as its price is not set.',
      );
      return;
    }

    // Get current cart quantity for this item
    final existingIndex = currentOrderItems.indexWhere(
      (orderItem) => orderItem.itemId == item.id,
    );
    final currentCartQty = existingIndex != -1
        ? currentOrderItems[existingIndex].quantity
        : 0;

    // Validate using StockHelper
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    final error = await StockHelper.validateAddToCart(
      tenant: tenant,
      itemId: item.id,
      currentCartQuantity: currentCartQty,
    );

    if (error != null) {
      if (mounted) {
        await HapticFeedback.heavyImpact();
        if (!mounted) return;
        StockHelper.showStockError(context, error);
      }
      return;
    }

    // Add to cart with haptic feedback
    await HapticFeedback.lightImpact();

    setState(() {
      if (existingIndex != -1) {
        currentOrderItems[existingIndex] = MerchandiseOrderItem(
          itemId: item.id,
          name: item.name,
          price: item.price!,
          quantity: currentOrderItems[existingIndex].quantity + 1,
        );
      } else {
        currentOrderItems.add(
          MerchandiseOrderItem(
            itemId: item.id,
            name: item.name,
            price: item.price!,
            quantity: 1,
          ),
        );
      }
    });

    // Show success feedback
    if (mounted) {
      StockHelper.showAddedToCart(context, item.name);
    }
  }

  Widget _buildOrderAssociationSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.kSpacingMedium,
        vertical: AppTheme.kSpacingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAssociationCard(
            isSelected: selectedCustomer != null,
            icon: selectedCustomer == null
                ? Icons.person_add_alt_1_outlined
                : Icons.account_circle_rounded,
            title: selectedCustomer == null
                ? 'Customer'
                : selectedCustomer!.name,
            subtitle: selectedCustomer == null
                ? 'Tap to assign a customer'
                : (_selectedTableSession != null
                      ? 'Active Session on ${selectedTable?.name}'
                      : 'Credits: ₹${selectedCustomer!.credits.toStringAsFixed(2)}'),
            buttonText: 'Assign',
            buttonIcon: Icons.person_search_rounded,
            onPressed: () {
              _assignCustomer();
            },
            onClear: selectedCustomer != null
                ? () {
                    setState(() {
                      selectedCustomer = null;
                      _selectedTableSession = null;
                      if (_tableLocked) {
                        selectedTable = null;
                        _tableLocked = false;
                      }
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildAssociationCard({
    required bool isSelected,
    required IconData icon,
    required String title,
    String? subtitle,
    required String buttonText,
    required IconData buttonIcon,
    VoidCallback? onPressed,
    VoidCallback? onClear,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outline.withValues(alpha: 0.5);

    return AppSurface(
      borderRadius: AppTheme.kBorderRadiusMedium,
      borderColor: borderColor,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.kSpacingMedium,
              vertical: AppTheme.kSpacingSmall,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: AppTheme.kSpacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: onClear,
                    tooltip: 'Clear Selection',
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _assignCustomer() async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    final Customer? customer = await showDialog<Customer?>(
      context: context,
      builder: (_) => CustomerSelectionDialog(customers: tenant.customers()),
    );
    if (customer != null) {
      final sessionData = await _fetchCustomerActiveSessionAndTable(
        customer.id,
      );
      setState(() {
        selectedCustomer = customer;
        if (sessionData != null) {
          _selectedTableSession = sessionData['session'] as TableSession?;
          selectedTable = sessionData['table'] as SnookerTable?;
          _tableLocked = true;
        } else {
          _selectedTableSession = null;
          if (_tableLocked) {
            // previously locked, now unlocked as customer has no session
            selectedTable = null;
          }
          _tableLocked = false;
        }
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchCustomerActiveSessionAndTable(
    String customerId,
  ) async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return null;
    final sessionSnap = await tenant
        .sessions()
        .where('customerId', isEqualTo: customerId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (sessionSnap.docs.isEmpty) return null;

    final sessionDoc = sessionSnap.docs.first;
    final session = TableSession.fromFirestore(sessionDoc);
    final tableId = session.tableId;

    if (tableId.isEmpty) return null;

    final tableDoc = await tenant.tables().doc(tableId).get();
    if (!tableDoc.exists) return null;

    final table = SnookerTable.fromJson({
      ...tableDoc.data()!,
      'id': tableDoc.id,
    });

    return {'session': session, 'table': table};
  }

  Widget _buildCurrentOrderList() {
    final theme = Theme.of(context);
    if (currentOrderItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 60,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Your cart is empty',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Add items to your cart to get started.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: AppTheme.scrollPhysicsFor(context),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      itemCount: currentOrderItems.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: AppTheme.subtleDividerColor(theme),
      ),
      itemBuilder: (context, index) {
        final item = currentOrderItems[index];
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return AppSurface(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          borderRadius: AppTheme.kBorderRadiusSmall,
          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Quantity stepper
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: colorScheme.primaryContainer,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      splashRadius: 16,
                      onPressed: () => _decrementQuantity(index),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        item.quantity.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      splashRadius: 16,
                      onPressed: () => _incrementQuantity(index),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${item.price.toStringAsFixed(2)} each',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _decrementQuantity(int index) {
    setState(() {
      if (currentOrderItems[index].quantity > 1) {
        currentOrderItems[index] = MerchandiseOrderItem(
          itemId: currentOrderItems[index].itemId,
          name: currentOrderItems[index].name,
          price: currentOrderItems[index].price,
          quantity: currentOrderItems[index].quantity - 1,
        );
      } else {
        currentOrderItems.removeAt(index);
      }
    });
  }

  Future<void> _incrementQuantity(int index) async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    final orderItem = currentOrderItems[index];
    final stockDoc = await tenant.stockItems().doc(orderItem.itemId).get();
    if (!stockDoc.exists) return;
    final available = parseFirestoreInt(stockDoc.data()?['quantity']);
    if (orderItem.quantity >= available) {
      if (mounted) {
        SnackbarHelper.showWarning(
          context,
          'Only $available available in stock.',
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }

    setState(() {
      currentOrderItems[index] = MerchandiseOrderItem(
        itemId: orderItem.itemId,
        name: orderItem.name,
        price: orderItem.price,
        quantity: orderItem.quantity + 1,
      );
    });
  }

  /// Shows the mobile cart bottom sheet with order items and actions
  void _showMobileCartSheet() {
    HapticFeedback.mediumImpact();
    final attachToSession =
        _selectedTableSession != null && !_selectedTableSession!.isPTL;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CartBottomSheet<MerchandiseOrderItem>(
        title: 'Your Cart',
        items: currentOrderItems,
        getItemName: (item) => item.name,
        getItemPrice: (item) => item.price,
        getItemQuantity: (item) => item.quantity,
        getItemId: (item) => item.itemId,
        getStockQuantity: _getStockQuantity,
        onQuantityChanged: (index, newQuantity) {
          setState(() {
            if (newQuantity <= 0) {
              currentOrderItems.removeAt(index);
            } else {
              currentOrderItems[index] = MerchandiseOrderItem(
                itemId: currentOrderItems[index].itemId,
                name: currentOrderItems[index].name,
                price: currentOrderItems[index].price,
                quantity: newQuantity,
              );
            }
          });
          Navigator.pop(context);
          _showMobileCartSheet(); // Refresh the sheet
        },
        associationSection: _buildMobileAssociationSection(),
        total: _calculateTotal(),
        canProceed: selectedCustomer != null && currentOrderItems.isNotEmpty,
        proceedButtonText: selectedCustomer == null
            ? 'Select Customer First'
            : attachToSession
            ? 'Add to Session'
            : 'Proceed to Payment',
        onProceed: () {
          Navigator.pop(context);
          _showPaymentOptionsDialog();
        },
        onClearCart: () {
          Navigator.pop(context);
          setState(() {
            currentOrderItems.clear();
          });
        },
      ),
    );
  }

  /// Builds a compact association section for mobile cart sheet
  /// Uses the shared CustomerAssociationSection widget
  Widget _buildMobileAssociationSection() {
    return CustomerAssociationSection(
      selectedCustomer: selectedCustomer,
      selectedTable: selectedTable,
      selectedTableSession: _selectedTableSession,
      creditsText: selectedCustomer != null
          ? 'Credits: ₹${selectedCustomer!.credits.toStringAsFixed(2)}'
          : null,
      onSelectCustomer: () {
        Navigator.pop(context);
        _assignCustomer();
      },
      onClearCustomer: () {
        setState(() {
          selectedCustomer = null;
          _selectedTableSession = null;
          if (_tableLocked) {
            selectedTable = null;
            _tableLocked = false;
          }
        });
        Navigator.pop(context);
        _showMobileCartSheet();
      },
    );
  }

  /// Helper to get stock quantity for an item using cached StockHelper
  Future<int?> _getStockQuantity(String itemId) async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return null;
    return StockHelper.getStockQuantity(tenant, itemId);
  }

  double _calculateTotal() {
    return currentOrderItems.fold(
      0,
      (total, item) => total + (item.price * item.quantity),
    );
  }

  Widget _buildOrderSummaryAndActions() {
    final total = _calculateTotal();
    final hasCustomer = selectedCustomer != null;
    // Allow attaching only when active session exists AND it is not PTL.
    final attachToSession =
        _selectedTableSession != null && !_selectedTableSession!.isPTL;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(
              !hasCustomer
                  ? Icons.person_search_rounded
                  : attachToSession
                  ? Icons.link
                  : Icons.payment,
            ),
            label: Text(
              !hasCustomer
                  ? 'Select Customer'
                  : attachToSession
                  ? 'Add to Session'
                  : 'Proceed to Payment',
            ),
            onPressed: (currentOrderItems.isNotEmpty && hasCustomer)
                ? _showPaymentOptionsDialog
                : null,
            style:
                ElevatedButton.styleFrom(
                  backgroundColor: attachToSession
                      ? Theme.of(context).colorScheme.secondary
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  // textStyle will be merged from global theme
                ).merge(
                  Theme.of(context).elevatedButtonTheme.style?.copyWith(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 16),
                    ), // Explicitly keep larger padding
                    textStyle: WidgetStateProperty.all(
                      Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ), // Explicitly keep larger font size
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentOptionsDialog() async {
    if (selectedCustomer == null) {
      if (mounted) {
        context.showWarningSnackbar(
          'Please select a customer before proceeding.',
        );
      }
      return;
    }
    // Attach only if there is an active session AND it is not PTL (Loser-Pays)
    final attachToSession =
        _selectedTableSession != null && !_selectedTableSession!.isPTL;

    if (attachToSession) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => GlassModalSheetChrome(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Order for ${selectedCustomer?.name ?? 'Customer'} on ${selectedTable?.name ?? 'Table'}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.subtleDividerColor(Theme.of(ctx)),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Add to Active Session'),
                subtitle: const Text('Total Bill will be updated.'),
                onTap: () => Navigator.pop(ctx, 'attach'),
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Pay Separately Now'),
                subtitle: const Text(
                  'Complete this transaction independently.',
                ),
                onTap: () => Navigator.pop(ctx, 'pay'),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      if (choice == 'attach') {
        await _submitOrder(PaymentMethod.cash, attachToSession: true);
        if (!mounted) return;
        return;
      } else if (choice != 'pay') {
        return;
      }
    }

    if (!mounted) return;
    final totalAmount = _calculateTotal();
    final canPayWithCredits =
        selectedCustomer != null && selectedCustomer!.credits >= totalAmount;

    final PaymentMethod? selectedPaymentMethod = await showDialog<PaymentMethod>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: const Text('Cash'),
                leading: const Icon(Icons.money),
                onTap: () => Navigator.pop(context, PaymentMethod.cash),
              ),
              ListTile(
                title: const Text('UPI'),
                leading: const Icon(Icons.mobile_friendly),
                onTap: () => Navigator.pop(context, PaymentMethod.upi),
              ),
              if (selectedCustomer != null)
                ListTile(
                  title: Builder(
                    builder: (context) {
                      final txsAsync = ref.watch(
                        customerCreditLedgerProvider(selectedCustomer!.id),
                      );
                      return txsAsync.when(
                        data: (txs) {
                          final add = txs
                              .where((t) => t.amount >= 0)
                              .fold<double>(0, (p, t) => p + t.amount);
                          final use = txs
                              .where((t) => t.amount < 0)
                              .fold<double>(0, (p, t) => p + t.amount.abs());
                          final bal = add - use;
                          return Text(
                            'Use Credits (Available: ₹${bal.toStringAsFixed(2)})',
                          );
                        },
                        loading: () => Text(
                          'Use Credits (Available: ₹${selectedCustomer!.credits.toStringAsFixed(2)})',
                        ),
                        error: (e, s) => Text(
                          'Use Credits (Available: ₹${selectedCustomer!.credits.toStringAsFixed(2)})',
                        ),
                      );
                    },
                  ),
                  leading: const Icon(Icons.account_balance_wallet),
                  onTap: () => Navigator.pop(context, PaymentMethod.credits),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (selectedPaymentMethod != null) {
      final dynamic paymentInfo = selectedPaymentMethod;

      // Determine if credits are involved to trigger code verification
      bool creditsInvolved = false;
      if (selectedPaymentMethod == PaymentMethod.credits) {
        creditsInvolved = true;
      } else if (selectedPaymentMethod is Map) {
        final paymentMap = Map<String, dynamic>.from(
          selectedPaymentMethod as Map,
        );
        final creditAmt = parseFirestoreDouble(
          paymentMap['Credits'] ?? paymentMap['credits'] ?? 0,
        );
        creditsInvolved =
            (paymentMap.containsKey('Credits') ||
                paymentMap.containsKey('credits')) &&
            creditAmt > 0;
      }

      if (creditsInvolved) {
        final verified = await _verifyCreditCode(context);
        if (!mounted) return;
        if (!verified) {
          return; // Verification failed
        }
      }

      // Disallow partial credit payments: must have enough credits if choosing credits
      if (selectedPaymentMethod == PaymentMethod.credits &&
          !canPayWithCredits) {
        if (mounted) {
          context.showErrorSnackbar(
            'Insufficient credits to place this order. Choose another payment method.',
          );
        }
        return;
      }

      try {
        await _submitOrder(paymentInfo);
      } catch (e) {
        if (mounted) {
          context.showErrorSnackbar(
            'Error processing payment: ${e.toString()}',
          );
        }
      }
    }
  }

  // Helper to verify credit code using shared utility
  Future<bool> _verifyCreditCode(BuildContext context) async {
    if (selectedCustomer == null || selectedCustomer!.creditCode.isEmpty) {
      return true; // skip if no code
    }
    return CreditVerification.verifyCreditCode(context, selectedCustomer!);
  }

  Future<void> _submitOrder(
    dynamic paymentData, {
    bool attachToSession = false,
  }) async {
    if (selectedCustomer == null) {
      if (mounted) {
        context.showWarningSnackbar(
          'Customer must be selected to place an order.',
        );
      }
      return;
    }

    if (currentOrderItems.isEmpty) {
      if (mounted) {
        context.showWarningSnackbar('Cannot submit an empty order.');
      }
      return;
    }

    final totalAmount = _calculateTotal();
    double? newlyCalculatedCreditsForSelectedCustomer;

    // Determine payment details
    PaymentMethod? primaryMethod;
    Map<String, double> paymentBreakdown = {};
    double creditsUsedInPayment = 0.0;

    if (paymentData is PaymentMethod) {
      primaryMethod = paymentData;
      if (primaryMethod == PaymentMethod.credits) {
        paymentBreakdown = {'credits': totalAmount};
        creditsUsedInPayment = totalAmount;
      }
    } else if (paymentData is Map) {
      paymentBreakdown = Map<String, double>.from(paymentData);
      creditsUsedInPayment =
          paymentBreakdown['credits'] ?? paymentBreakdown['Credits'] ?? 0.0;
      // Handle both capitalized and lowercase keys for backward compatibility
      if (paymentBreakdown.containsKey('Cash') ||
          paymentBreakdown.containsKey('cash')) {
        primaryMethod = PaymentMethod.cash;
      } else if (paymentBreakdown.containsKey('UPI') ||
          paymentBreakdown.containsKey('upi')) {
        primaryMethod = PaymentMethod.upi;
      } else {
        primaryMethod = PaymentMethod.credits;
      }
    }

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );

    try {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) {
        Navigator.pop(context);
        if (mounted) {
          context.showErrorSnackbar(
            'No company context. Please sign in again.',
          );
        }
        return;
      }
      final batch = tenant.db.batch();
      final currentUser = ref.read(appUserProvider).value;

      final String orderId = await OrderIdService.generate(
        tenant,
        OrderCategory.merchandise,
      );
      final orderRef = tenant.merchandiseOrders().doc(orderId);

      final orderData = {
        'items': currentOrderItems.map((item) => item.toFirestore()).toList(),
        'status': attachToSession ? 'pending' : 'delivered',
        'createdAt': FieldValue.serverTimestamp(),
        'total': totalAmount,
        'paymentMethod': attachToSession
            ? null
            : (primaryMethod != null
                  ? primaryMethod.toString().split('.').last
                  : 'split'),
        if (paymentBreakdown.isNotEmpty) 'paymentBreakdown': paymentBreakdown,
        if (creditsUsedInPayment > 0) 'creditsUsed': creditsUsedInPayment,
        'customerId': selectedCustomer?.id,
        'customerName': selectedCustomer?.name,
        'tableId': selectedTable?.id,
        'tableName': selectedTable?.name,
        'sessionId': attachToSession ? _selectedTableSession?.id : null,
        'isBilled': !attachToSession,
        'billedAt': attachToSession ? null : FieldValue.serverTimestamp(),
        'performedById': currentUser?.uid,
        'performedByName': currentUser?.name,
        'performedByRole': currentUser?.role.name,
      };

      batch.set(orderRef, orderData);

      // Store order ID for credit debit reference
      final String orderIdForCredits = orderRef.id;

      // Atomically update stock for each item in the order
      for (final orderItem in currentOrderItems) {
        final stockItemRef = tenant.stockItems().doc(orderItem.itemId);
        batch.update(stockItemRef, {
          'quantity': FieldValue.increment(-(orderItem.quantity.toDouble())),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      if (attachToSession && _selectedTableSession != null) {
        final sessionRef = tenant.sessions().doc(_selectedTableSession!.id);
        batch.update(sessionRef, {
          'merchandiseOrderIds': FieldValue.arrayUnion([orderRef.id]),
          'totalMerchandiseAmount': FieldValue.increment(totalAmount),
          'totalBillAmount': FieldValue.increment(totalAmount),
          'hasUnbilledOrders': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Process credits payment atomically AFTER batch commit (only immediate payments)
      // This uses a Firestore transaction to prevent negative balances
      if (!attachToSession &&
          creditsUsedInPayment > 0 &&
          selectedCustomer != null) {
        final debitResult = await CreditService.safeDebitCredits(
          tenant: tenant,
          customerId: selectedCustomer!.id,
          amount: creditsUsedInPayment,
          reference: CreditReference.merchandiseOrder(orderIdForCredits),
          performedBy: currentUser,
        );

        if (!debitResult.success) {
          // Credit debit failed - update order to mark it as needing attention
          await tenant.merchandiseOrders().doc(orderIdForCredits).update({
            'creditDebitFailed': true,
            'creditDebitError': debitResult.error,
            'status': 'payment_pending',
          });

          if (!mounted) return;
          Navigator.pop(context); // Dismiss loading indicator
          SnackbarHelper.showError(
            context,
            debitResult.error ??
                'Insufficient credits. Please use another payment method.',
            duration: const Duration(seconds: 5),
          );
          return;
        }

        newlyCalculatedCreditsForSelectedCustomer = debitResult.newBalance;
      }

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading indicator

      // Print customer bill immediately if order is settled now (not attached to session)
      if (!attachToSession) {
        try {
          final billItems = currentOrderItems
              .map(
                (it) => {
                  'name': it.name,
                  'price': it.price,
                  'quantity': it.quantity,
                },
              )
              .toList();
          await PrinterService.printDocument(
            jobType: PrintJobType.kotOnly,
            id: orderRef.id,
            items: billItems,
            customerName: selectedCustomer?.name,
            tableName: selectedTable?.name,
          );
          await PrinterService.printDocument(
            jobType: PrintJobType.billOnly,
            id: orderRef.id,
            items: billItems,
            total: totalAmount,
            customerName: selectedCustomer?.name,
            tableName: selectedTable?.name,
            creditsUsed: creditsUsedInPayment > 0 ? creditsUsedInPayment : null,
          );
        } catch (e) {
          AppLogger.warning(
            'Error printing bill: $e',
            tag: 'MerchandiseScreen',
          );
        }
      }

      if (!attachToSession &&
          creditsUsedInPayment > 0 &&
          selectedCustomer != null &&
          newlyCalculatedCreditsForSelectedCustomer != null) {
        final updatedCustomer = selectedCustomer!.copyWith(
          credits: newlyCalculatedCreditsForSelectedCustomer,
        );
        setState(() {
          selectedCustomer = updatedCustomer;
        });
      }

      setState(() {
        currentOrderItems.clear();
      });

      if (mounted) {
        context.showSuccessSnackbar('Merchandise order placed successfully!');
      }
    } catch (e, s) {
      if (mounted) Navigator.pop(context); // Dismiss loading indicator
      AppLogger.error(
        'Error submitting merchandise order',
        error: e,
        stackTrace: s,
        tag: 'MerchandiseScreen',
      );
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Error submitting order: ${e.toString()}',
          actionLabel: AppStrings.retry,
          onAction: _showPaymentOptionsDialog,
        );
      }
    }
  }

  Widget _buildOrderHistory() {
    final isMobile = AppTheme.isMobile(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final TenantRef? tenant = ref.watch(tenantRefProvider);
    if (tenant == null) {
      return const Center(
        child: Text('Sign in with a company account to view order history.'),
      );
    }

    return Column(
      children: [
        // Compact filter bar
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 8 : 12,
          ),
          child: Row(
            children: [
              // Date filter chip
              Expanded(
                child: InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 12,
                      vertical: isMobile ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedDateRange != null
                          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                      border: Border.all(
                        color: _selectedDateRange != null
                            ? colorScheme.primary.withValues(alpha: 0.3)
                            : colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: isMobile ? 16 : 18,
                          color: _selectedDateRange != null
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        Expanded(
                          child: Text(
                            _selectedDateRange == null
                                ? 'Date Range'
                                : '${DateFormat.MMMd().format(_selectedDateRange!.start)} - ${DateFormat.MMMd().format(_selectedDateRange!.end)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: _selectedDateRange != null
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: _selectedDateRange != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: isMobile ? 11 : 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedDateRange != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDateRange = null),
                            child: Icon(
                              Icons.close_rounded,
                              size: isMobile ? 16 : 18,
                              color: colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              // Status filter dropdown
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  color: _selectedOrderStatusFilter != null
                      ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                  border: Border.all(
                    color: _selectedOrderStatusFilter != null
                        ? colorScheme.primary.withValues(alpha: 0.3)
                        : colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    hint: Text(
                      'Status',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: isMobile ? 11 : 12,
                      ),
                    ),
                    value: _selectedOrderStatusFilter,
                    isDense: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: isMobile ? 18 : 20,
                      color: _selectedOrderStatusFilter != null
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 11 : 12,
                    ),
                    items:
                        ['all', 'pending', 'delivered', 'cancelled', 'refunded']
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedOrderStatusFilter = value == 'all'
                            ? null
                            : value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _merchandiseOrderHistoryQuery(tenant).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: colorScheme.error),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_toggle_off_outlined,
                        size: isMobile ? 50 : 70,
                        color: colorScheme.outline,
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      Text(
                        'No merchandise orders found.',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_selectedDateRange != null ||
                          _selectedOrderStatusFilter != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Try adjusting your filters.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }
              final orders = snapshot.data!.docs
                  .map((doc) => MerchandiseOrder.fromFirestore(doc))
                  .toList();
              return ListView.builder(
                physics: AppTheme.scrollPhysicsFor(context),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                ).copyWith(bottom: isMobile ? 12 : 16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return MerchandiseOrderCard(
                    order: order,
                    isMobile: isMobile,
                    onRefund:
                        (!order.isRefunded && order.total > 0 && order.isBilled)
                        ? () async {
                            final result = await Navigator.of(context)
                                .push<bool>(
                                  AppMaterialPageRoute<bool>(
                                    builder: (context) => UnifiedRefundScreen(
                                      orderId: order.id,
                                      orderType: RefundOrderType.merchandise,
                                    ),
                                  ),
                                );
                            if (result == true && context.mounted) {
                              context.showSuccessSnackbar(
                                'Refund processed successfully',
                              );
                            }
                          }
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) => child!,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = DateTimeRange(
          start: picked.start,
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        );
      });
    }
  }

  Query _merchandiseOrderHistoryQuery(TenantRef tenant) {
    Query query = tenant
        .merchandiseOrders()
        // Include session-linked merchandise orders often marked as 'pending' then billed in session
        .where(
          'status',
          whereIn: [
            'pending',
            'delivered',
            'completed',
            'cancelled',
            'refunded',
          ],
        )
        .orderBy('createdAt', descending: true);

    // Date filter
    if (_selectedDateRange != null) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              _selectedDateRange!.start,
            ),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end),
          );
    }

    // Status filter – if a specific status is chosen show only that, otherwise show all
    if (_selectedOrderStatusFilter != null) {
      query = query.where('status', isEqualTo: _selectedOrderStatusFilter);
    }

    return query;
  }

  /// Search text field used above the merchandise grid
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: AppTheme.inputDecoration(
        Theme.of(context),
        'Search items',
        Icons.search,
      ).copyWith(hintText: 'Search merchandise…'),
    );
  }
}
