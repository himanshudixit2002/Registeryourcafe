import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../refund/unified_refund_screen.dart';
import '../../theme/app_theme.dart';
import '../../models/cafe_order.dart';
import '../../models/customer.dart';
import '../../models/table.dart';
import '../../models/session.dart';
import '../../widgets/enhanced_customer_search.dart';
import './stock_screen.dart';
import '../../models/stock_item.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../widgets/loading_indicator.dart';
import 'components/category_filter_bar.dart';
import 'components/historical_order_card.dart';
import 'components/product_grid.dart';
import '../../widgets/info_placeholder.dart';
import 'package:registeryourcafe/screens/cafe/components/kitchen_column.dart';
import 'package:registeryourcafe/screens/cafe/guest_cafe_orders_screen.dart';
import 'package:registeryourcafe/providers/guest_cafe_order_provider.dart';
import 'package:registeryourcafe/services/kitchen_service.dart';
import 'package:unicons/unicons.dart';
import '../customers/add_customer_screen.dart';
import 'package:registeryourcafe/services/printer_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/models/venue_ui_config.dart';
import 'package:registeryourcafe/providers/auth_provider.dart';
import 'package:registeryourcafe/providers/company_module_provider.dart';
import 'package:registeryourcafe/providers/membership_type_provider.dart';
import 'package:registeryourcafe/providers/tenant_provider.dart';
import 'package:registeryourcafe/providers/ledger_provider.dart';
import 'package:registeryourcafe/auth/permission_id.dart';
import 'package:registeryourcafe/providers/permissions_provider.dart';
import 'package:registeryourcafe/providers/user_ui_prefs_provider.dart';
import 'package:registeryourcafe/services/order_id_service.dart';
import 'package:registeryourcafe/services/credit_service.dart';
import 'package:registeryourcafe/utils/credit_verification.dart';
import 'package:registeryourcafe/utils/app_logger.dart';
import 'package:registeryourcafe/utils/firestore_utils.dart';
import 'package:flutter/services.dart';
import '../../widgets/floating_cart_button.dart';
import '../../widgets/cart_bottom_sheet.dart';
import '../../widgets/glass_modal_bottom_sheet.dart';
import '../../widgets/customer_association_section.dart';
import '../../services/stock_helper.dart';
import '../../widgets/glass_panel.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/constants/app_strings.dart';
import 'package:registeryourcafe/widgets/safe_network_avatar.dart';
import '../../utils/snackbar_helper.dart';
import 'kitchen_display_screen.dart';

class CafeScreen extends ConsumerStatefulWidget {
  final Customer? presetCustomer;
  final SnookerTable? presetTable;
  final TableSession? presetSession;
  final bool lockTableAssignment;

  const CafeScreen({
    super.key,
    this.presetCustomer,
    this.presetTable,
    this.presetSession,
    this.lockTableAssignment = false,
  });

  @override
  ConsumerState<CafeScreen> createState() => _CafeScreenState();
}

class _CafeScreenState extends ConsumerState<CafeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CafeOrderItem> currentOrderItems = [];
  final GlobalKey<AnimatedListState> _animatedListKey =
      GlobalKey<AnimatedListState>(); // Key for AnimatedList
  Customer? selectedCustomer;
  SnookerTable? selectedTable;
  TableSession? _selectedTableSession;
  bool _tableLocked = false;
  KitchenService _kitchenService(WidgetRef r) {
    final t = r.read(tenantRefProvider);
    if (t == null) throw StateError('Company tenant required');
    return KitchenService(t);
  }

  // For Order History filtering
  DateTimeRange? _selectedDateRange;
  String? _selectedOrderStatusFilter;

  // --- Enhancement: Category filter state ---
  String _selectedCategory = 'All';
  List<String> _visibleCategories = ['All'];

  // --- Enhancement: Menu Search State ---
  String _menuSearchQuery = '';
  final TextEditingController _menuSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _menuSearchController.addListener(() {
      if (_menuSearchController.text != _menuSearchQuery) {
        // Avoid redundant setState
        setState(() {
          _menuSearchQuery = _menuSearchController.text;
        });
      }
    });
    if (widget.presetCustomer != null) {
      selectedCustomer = widget.presetCustomer;
    }
    if (widget.presetTable != null) {
      selectedTable = widget.presetTable;
    }
    if (widget.presetSession != null) {
      _selectedTableSession = widget.presetSession;
    }
    if (widget.lockTableAssignment &&
        widget.presetCustomer != null &&
        widget.presetTable != null) {
      _tableLocked = true;
    }
  }

  String _buildSelectedCustomerCredits() {
    if (selectedCustomer == null) return '';
    final ledger = ref.read(customerCreditLedgerProvider(selectedCustomer!.id));
    return ledger.when(
      data: (txs) {
        final added = txs
            .where((t) => t.amount >= 0)
            .fold<double>(0, (p, t) => p + t.amount);
        final used = txs
            .where((t) => t.amount < 0)
            .fold<double>(0, (p, t) => p + t.amount.abs());
        final bal = added - used;
        return 'Credits: ₹${bal.toStringAsFixed(2)}';
      },
      loading: () =>
          'Credits: ₹${selectedCustomer!.credits.toStringAsFixed(2)}',
      error: (e, s) =>
          'Credits: ₹${selectedCustomer!.credits.toStringAsFixed(2)}',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _menuSearchController.dispose(); // Dispose the search controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Table dining opens an embedded cafe order flow without shell "Cafe" nav.
    final fromEmbeddedTableOrder =
        widget.presetSession != null || widget.presetTable != null;
    if (!ref.watchResolvedPermissions().can(PermissionIds.navCafe) &&
        !fromEmbeddedTableOrder) {
      return Scaffold(
        body: Center(child: Text('You do not have access to the ${ref.watch(venueKindProvider).cafeTabLabel.toLowerCase()}.')),
      );
    }

    // rely on AppTheme.breakpoint methods instead of raw screenWidth
    final isMobile = AppTheme.isMobile(context);
    final compactLists = ref.watch(userUiPrefsProvider).compactListDensity;
    final canCafeAdmin = ref.watchResolvedPermissions().can(
      PermissionIds.opsCafeAdmin,
    );
    final theme = Theme.of(context);
    final venueKind = ref.watch(venueKindProvider);
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 16,
            vertical: isMobile ? 4 : 8,
          ),
          height: isMobile ? 36 : 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.onPrimary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicator: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            isScrollable: isMobile,
            tabAlignment: isMobile ? TabAlignment.start : null,
            labelStyle: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
            padding: EdgeInsets.all(isMobile ? 3 : 4),
            tabs: [
              Tab(
                height: isMobile ? 30 : 40,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu_rounded, size: isMobile ? 14 : 16),
                      const SizedBox(width: 4),
                      const Text('Menu'),
                    ],
                  ),
                ),
              ),
              Tab(
                height: isMobile ? 30 : 40,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(venueKind.cafeTabIcon, size: isMobile ? 14 : 16),
                      const SizedBox(width: 4),
                      Text(venueKind.kitchenTitle.split(' ').first),
                    ],
                  ),
                ),
              ),
              Tab(
                height: isMobile ? 30 : 40,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: isMobile ? 14 : 16),
                      const SizedBox(width: 4),
                      const Text('History'),
                    ],
                  ),
                ),
              ),
              Tab(
                height: isMobile ? 30 : 40,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: isMobile ? 14 : 16),
                      const SizedBox(width: 4),
                      const Text('Stock'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMenuAndOrders(isMobile, compactLists),
              _buildKitchenDisplay(isMobile),
              _buildOrderHistory(isMobile),
              canCafeAdmin
                  ? const StockScreen()
                  : const Center(child: Text('Access Denied')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuAndOrders(bool isMobile, bool compactLists) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) {
      return const Center(child: Text('No company context'));
    }
    final theme = Theme.of(context); // Get theme for styling search bar
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // --- Menu Search Bar ---
    final menuSearchBar = Padding(
      padding: EdgeInsets.only(
        bottom: isMobile ? 8 : AppTheme.kSpacingMedium,
        top: isMobile ? AppTheme.kSpacingXSmall : AppTheme.kSpacingSmall,
      ),
      child: TextField(
        controller: _menuSearchController,
        decoration: InputDecoration(
          hintText: 'Search menu items...',
          hintStyle: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colorScheme.primary,
            size: isMobile ? 20 : 24,
          ),
          suffixIcon: _menuSearchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: colorScheme.secondary,
                    size: isMobile ? 18 : 22,
                  ),
                  onPressed: () {
                    _menuSearchController.clear();
                    // setState(() { // Listener will handle this
                    //   _menuSearchQuery = '';
                    // });
                  },
                  tooltip: 'Clear search',
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          isDense: isMobile,
          contentPadding: EdgeInsets.symmetric(
            vertical: isMobile ? 10 : AppTheme.kSpacingSmall,
            horizontal: AppTheme.kSpacingMedium,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppTheme.kBorderRadiusLarge,
            ), // Consistent large radius
            borderSide: BorderSide.none, // No visible border unless focused
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusLarge),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusLarge),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
        style: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        // onChanged handled by listener
      ),
    );

    final menuSection = Expanded(
      flex: isMobile ? 1 : 2,
      child: Padding(
        padding: EdgeInsets.all(
          isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Menu',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            // const SizedBox(height: AppTheme.kSpacingMedium), // Spacing adjusted by search bar padding
            menuSearchBar, // Added search bar
            CategoryFilterBar(
              categories: _visibleCategories,
              selectedCategory: _selectedCategory,
              onCategorySelected: (category) {
                setState(() {
                  _selectedCategory = category;
                });
              },
            ),
            SizedBox(height: AppTheme.kSpacingSmall),
            Expanded(
              child: ProductGrid(
                tenant: tenant,
                selectedCategory: _selectedCategory,
                searchQuery: _menuSearchQuery,
                onAddToCart: _addToOrder,
                onCategoriesFetched: (categories) {
                  if (mounted &&
                      (categories.join(',') != _visibleCategories.join(','))) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _visibleCategories = categories;
                        if (!_visibleCategories.contains(_selectedCategory)) {
                          _selectedCategory = 'All';
                        }
                      });
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );

    final orderSection = Expanded(
      flex: 1, // Takes full width on mobile if in Column, 1/3 on larger
      child: AppSurface(
        margin: EdgeInsets.all(
          isMobile ? AppTheme.kSpacingXSmall : AppTheme.kSpacingMedium,
        ).copyWith(top: AppTheme.kSpacingMedium),
        borderRadius: AppTheme.kBorderRadiusLarge,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(
                isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
              ),
              child: Text(
                'Current Order',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.subtleDividerColor(theme),
            ),
            _buildOrderAssociationSection(isMobile),
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.subtleDividerColor(theme),
            ),
            Expanded(child: _buildCurrentOrderList(isMobile, compactLists)),
            Divider(
              height: 1,
              thickness: 1,
              indent: AppTheme.kSpacingMedium,
              endIndent: AppTheme.kSpacingMedium,
              color: AppTheme.subtleDividerColor(theme),
            ),
            _buildOrderSummaryAndActions(isMobile),
          ],
        ),
      ),
    );

    if (isMobile) {
      // For mobile, use full screen menu with floating cart button
      return Stack(
        children: [
          // Full-screen menu section
          Padding(
            padding: const EdgeInsets.all(AppTheme.kSpacingSmall),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selectedCustomer != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _showMobileCartSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
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
                              size: 15,
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
                  ),
                menuSearchBar,
                CategoryFilterBar(
                  categories: _visibleCategories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (category) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ProductGrid(
                    tenant: tenant,
                    selectedCategory: _selectedCategory,
                    searchQuery: _menuSearchQuery,
                    onAddToCart: _addToOrder,
                    onCategoriesFetched: (categories) {
                      if (mounted &&
                          (categories.join(',') !=
                              _visibleCategories.join(','))) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _visibleCategories = categories;
                            if (!_visibleCategories.contains(
                              _selectedCategory,
                            )) {
                              _selectedCategory = 'All';
                            }
                          });
                        });
                      }
                    },
                  ),
                ),
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
        children: [menuSection, orderSection],
      );
    }
  }

  Widget _buildOrderAssociationSection(bool isMobile) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    Widget buildAssociationCard({
      required bool isSelected,
      required IconData icon,
      required String title,
      required String? subtitle,
      required String buttonText,
      required IconData buttonIcon,
      required VoidCallback onPressed,
      required VoidCallback? onClear,
      Color? accentColor,
    }) {
      accentColor ??= colorScheme.primary; // Default to primary if null
      // Use a slightly darker/more saturated version of the accent color for better contrast on tonal buttons
      final Color tonalButtonFgColor = Color.alphaBlend(
        colorScheme.onSurface.withValues(alpha: 0.2),
        accentColor,
      );

      return AppSurface(
        margin: EdgeInsets.symmetric(
          vertical: isMobile
              ? AppTheme.kSpacingXSmall / 2
              : AppTheme.kSpacingXSmall,
        ),
        borderRadius: AppTheme.kBorderRadiusLarge,
        borderColor: isSelected
            ? accentColor.withValues(alpha: 0.7)
            : colorScheme.outline.withValues(alpha: 0.4),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed, // Allow tap to select/deselect or open search
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusLarge),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.kSpacingMedium,
                vertical: isMobile
                    ? AppTheme.kSpacingXSmall
                    : AppTheme.kSpacingSmall + 2,
              ), // Adjusted padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Align items vertically
                    children: [
                      // Enhanced Icon presentation
                      Container(
                        padding: EdgeInsets.all(
                          isMobile
                              ? AppTheme.kSpacingXSmall / 2
                              : AppTheme.kSpacingXSmall,
                        ), // Padding around icon
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.15)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: isMobile
                              ? 22
                              : 26, // Slightly smaller icon for better balance with text
                          color: isSelected
                              ? accentColor
                              : colorScheme
                                    .onSurfaceVariant, // Ensure unselected icon is clearly visible
                        ),
                      ),
                      SizedBox(width: AppTheme.kSpacingSmall),
                      Expanded(
                        child: Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            // Ensure the title color has good contrast in both selected and unselected states.
                            // Using onSurface which should be designed for the main surface colors.
                            // The accentColor will primarily be used for the icon and border in selected state.
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: AppTheme.kSpacingXSmall,
                      ), // Space before button/clear icon
                      if (isSelected && onClear != null)
                        IconButton(
                          icon: Icon(
                            Icons.highlight_off_rounded,
                            color: colorScheme.error,
                            size: isMobile ? 20 : 24,
                          ), // More prominent clear icon
                          tooltip: 'Clear Selection',
                          onPressed: onClear,
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.all(
                              isMobile
                                  ? AppTheme.kSpacingXSmall / 2
                                  : AppTheme.kSpacingXSmall / 2,
                            ),
                            visualDensity:
                                VisualDensity.compact, // Make it less bulky
                          ),
                        )
                      else if (!isSelected)
                        FilledButton.tonalIcon(
                          onPressed: onPressed,
                          icon: Icon(buttonIcon, size: isMobile ? 16 : 18),
                          label: Text(
                            buttonText,
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppTheme.kSpacingMedium,
                              vertical: isMobile
                                  ? AppTheme.kSpacingXSmall
                                  : AppTheme.kSpacingXSmall,
                            ), // Standardized padding
                            backgroundColor: accentColor.withValues(
                              alpha: 0.12,
                            ), // Slightly more opaque for better visibility
                            foregroundColor:
                                tonalButtonFgColor, // Use calculated color for better contrast
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.kBorderRadiusSmall,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (subtitle != null &&
                      subtitle
                          .isNotEmpty) // Show subtitle always if available, not just when selected
                    Padding(
                      // Adjust left padding based on whether it's selected or not, to align with title or icon
                      padding: EdgeInsets.only(
                        top: AppTheme.kSpacingXSmall,
                        left: isSelected
                            ? (AppTheme.kSpacingSmall +
                                  (isMobile ? 22 : 26) +
                                  AppTheme.kSpacingSmall +
                                  AppTheme.kSpacingSmall)
                            : AppTheme.kSpacingMedium,
                      ),
                      child: Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.85,
                          ), // Ensure good contrast
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final canAddCustomer =
        ref.watchResolvedPermissions().can(PermissionIds.navCustomers);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
        vertical: isMobile ? AppTheme.kSpacingXSmall : AppTheme.kSpacingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: AppTheme.kSpacingXSmall,
              left: isMobile
                  ? AppTheme.kSpacingXSmall / 2
                  : AppTheme.kSpacingXSmall / 2,
            ),
            child: Text(
              'Assign to:',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          buildAssociationCard(
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
                      ? 'Active Session on ${selectedTable?.name ?? '...'}'
                      : _buildSelectedCustomerCredits()),
            buttonText: 'Assign',
            buttonIcon: Icons.person_search_rounded,
            onPressed: widget.lockTableAssignment
                ? () {
                    context.showInfoSnackbar(
                      'Customer and table are fixed for this session.',
                    );
                  }
                : _assignCustomer,
            onClear: widget.lockTableAssignment
                ? null
                : (selectedCustomer != null
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
                      : null),
            accentColor: colorScheme.secondary,
          ),
          SizedBox(height: AppTheme.kSpacingSmall),
          if (!widget.lockTableAssignment && canAddCustomer)
            OutlinedButton.icon(
              icon: Icon(Icons.person_add_alt_1, size: isMobile ? 18 : 20),
              label: const Text('New Customer'),
              onPressed: () {
                Navigator.of(context).push(
                  AppMaterialPageRoute<void>(
                    builder: (context) => const AddCustomerScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.secondary,
                side: BorderSide(color: colorScheme.secondary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.kBorderRadiusMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _assignCustomer() async {
    final Customer? customer = await showSearch<Customer?>(
      context: context,
      delegate: EnhancedCustomerSearchDelegate(
        customers: ref.read(tenantRefProvider)!.customers(),
        membershipDefinitions:
            ref.read(activeMembershipTypeDefinitionsProvider).valueOrNull ?? [],
        canAddCustomer:
            ref.readResolvedPermissions().can(PermissionIds.navCustomers),
      ),
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

  /// Menu thumbnail with quantity badge for cart lines.
  Widget _cafeOrderLineLeading(
    BuildContext context,
    CafeOrderItem orderItem, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final r = compact ? 16.0 : 20.0;
    return SizedBox(
      width: r * 2 + 6,
      height: r * 2 + 6,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          SafeNetworkAvatar(
            imageUrl: orderItem.imageUrl,
            radius: r,
            fallbackIcon: Icons.local_cafe_rounded,
            fallbackBackgroundColor: theme.colorScheme.primaryContainer,
            fallbackIconColor: theme.colorScheme.onPrimaryContainer,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 1.5,
                ),
              ),
              child: Text(
                '${orderItem.quantity}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentOrderList(bool isMobile, bool compactLists) {
    if (currentOrderItems.isEmpty) {
      return const InfoPlaceholder(
        iconData: Icons.shopping_cart_outlined,
        title: 'Cart is Empty',
        message: 'Add items from the menu to get started.',
      );
    }

    final stateContext = context;
    return AnimatedList(
      key: _animatedListKey,
      physics: AppTheme.scrollPhysicsFor(stateContext),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.kSpacingXSmall : AppTheme.kSpacingSmall,
        vertical: compactLists
            ? AppTheme.kSpacingXSmall
            : AppTheme.kSpacingSmall,
      ),
      initialItemCount: currentOrderItems.length,
      itemBuilder: (itemContext, index, animation) {
        final orderItem = currentOrderItems[index];
        final theme = Theme.of(itemContext);
        final textTheme = theme.textTheme;
        final colorScheme = theme.colorScheme;

        return SizeTransition(
          sizeFactor: animation,
          child: AppSurface(
            borderRadius: AppTheme.kBorderRadiusMedium,
            margin: EdgeInsets.symmetric(
              vertical: isMobile
                  ? (compactLists
                        ? AppTheme.kSpacingXSmall / 3
                        : AppTheme.kSpacingXSmall / 2)
                  : (compactLists
                        ? AppTheme.kSpacingXSmall / 2
                        : AppTheme.kSpacingXSmall),
            ),
            padding: EdgeInsets.zero,
            child: ListTile(
              dense: compactLists,
              visualDensity: compactLists
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              contentPadding: EdgeInsets.symmetric(
                horizontal: compactLists
                    ? AppTheme.kSpacingSmall
                    : AppTheme.kSpacingMedium,
                vertical: compactLists
                    ? AppTheme.kSpacingXSmall / 2
                    : (isMobile
                          ? AppTheme.kSpacingXSmall
                          : AppTheme.kSpacingSmall),
              ),
              leading: _cafeOrderLineLeading(
                itemContext,
                orderItem,
                compact: compactLists,
              ),
              title: Text(
                orderItem.name,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: compactLists ? 14 : null,
                ),
              ),
              subtitle: Text(
                '\u20B9${orderItem.price.toStringAsFixed(2)} each',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: compactLists ? 12 : null,
                ),
              ),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\u20B9${(orderItem.price * orderItem.quantity).toStringAsFixed(2)}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontSize: compactLists ? 13 : null,
                    ),
                  ),
                  SizedBox(
                    width: compactLists
                        ? AppTheme.kSpacingSmall
                        : AppTheme.kSpacingMedium,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      size: compactLists ? 16 : (isMobile ? 18 : 20),
                    ),
                    onPressed: () => _removeFromOrder(index),
                    color: colorScheme.error,
                    tooltip: 'Remove one',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      size: compactLists ? 16 : (isMobile ? 18 : 20),
                    ),
                    onPressed: () async {
                      final tenant = ref.read(tenantRefProvider);
                      if (tenant == null) return;
                      // Get current stock quantity from Firestore
                      final stockDoc = await tenant
                          .stockItems()
                          .doc(orderItem.itemId)
                          .get();
                      if (!stateContext.mounted) return;
                      if (!stockDoc.exists) {
                        stateContext.showErrorSnackbar(
                          'Error fetching stock for ${orderItem.name}.',
                        );
                        return;
                      }

                      final currentStockQty = parseFirestoreDouble(
                        stockDoc.data()?['quantity'],
                      );
                      if (orderItem.quantity >= currentStockQty) {
                        stateContext.showWarningSnackbar(
                          'Cannot add more. Only ${currentStockQty.toInt()} ${orderItem.name} available in stock.',
                        );
                        return;
                      }

                      if (!mounted) return;
                      setState(() {
                        currentOrderItems[index] = CafeOrderItem(
                          itemId: orderItem.itemId,
                          name: orderItem.name,
                          price: orderItem.price,
                          quantity: orderItem.quantity + 1,
                          notes: orderItem.notes,
                          imageUrl: orderItem.imageUrl,
                        );
                      });

                      if (!stateContext.mounted) return;
                      final cs = Theme.of(stateContext).colorScheme;
                      ScaffoldMessenger.of(stateContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Added one more ${orderItem.name}',
                            style: TextStyle(color: cs.onInverseSurface),
                          ),
                          backgroundColor: cs.inverseSurface,
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    color: colorScheme.primary,
                    tooltip: 'Add one more',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderSummaryAndActions(bool isMobile) {
    final total = _calculateTotal();
    final hasCustomer = selectedCustomer != null;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    // Disallow attaching if the active session is in PTL mode
    final attachToSession =
        _selectedTableSession != null && !_selectedTableSession!.isPTL;

    return Container(
      decoration: BoxDecoration(
        // Use a color that stands out slightly, like surfaceContainer, or keep as surface if it fits the design
        color: colorScheme
            .surfaceContainerLow, // Or surfaceContainer for a bit more separation
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08), // Softer shadow
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        // Optionally add a top border for more definition
        // border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2), width: 1)),
      ),
      padding:
          EdgeInsets.all(
            isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
          ).copyWith(
            bottom: isMobile ? AppTheme.kSpacingMedium : AppTheme.kSpacingLarge,
          ), // More bottom padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme
                      .onSurfaceVariant, // Good for secondary financial info
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant, // Consistent with label
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.kSpacingMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface, // Main total amount
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(
            height: isMobile ? AppTheme.kSpacingMedium : AppTheme.kSpacingLarge,
          ),
          FilledButton.icon(
            icon: Icon(
              !hasCustomer
                  ? Icons.person_search_rounded
                  : attachToSession
                  ? Icons.add_link_rounded
                  : Icons.payment_rounded,
              size: isMobile ? 18 : 20,
            ),
            label: Text(
              !hasCustomer
                  ? 'Select Customer'
                  : attachToSession
                  ? 'Add to Session'
                  : 'Proceed to Payment',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme
                    .onPrimary, // Ensure text on FilledButton (primary bg) is onPrimary
              ),
            ),
            onPressed: (currentOrderItems.isNotEmpty && hasCustomer)
                ? _showPaymentOptionsDialog
                : null,
            style: FilledButton.styleFrom(
              backgroundColor:
                  colorScheme.primary, // Explicitly set primary background
              foregroundColor:
                  colorScheme.onPrimary, // Explicitly set onPrimary foreground
              padding: EdgeInsets.symmetric(
                vertical: AppTheme.kSpacingMedium,
                horizontal: isMobile
                    ? AppTheme.kSpacingMedium
                    : AppTheme.kSpacingLarge,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppTheme.kBorderRadiusLarge,
                ),
              ),
            ),
          ),
          if (currentOrderItems.isNotEmpty) ...[
            SizedBox(height: AppTheme.kSpacingSmall),
            TextButton.icon(
              icon: Icon(
                Icons.remove_shopping_cart_outlined,
                color: colorScheme.error, // Error color for icon
                size: isMobile ? 18 : 20,
              ),
              label: Text(
                'Clear Cart',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.error, // Error color for text
                  fontWeight:
                      FontWeight.bold, // Make it bold for more prominence
                ),
              ),
              onPressed: _clearCart,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile
                      ? AppTheme.kSpacingXSmall
                      : AppTheme.kSpacingSmall,
                ),
                // Optional: Add a shape for better visual consistency if other buttons have it
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.kBorderRadiusMedium,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKitchenDisplay(bool isMobile) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'kds_fab',
        tooltip: 'Kitchen Display',
        onPressed: () => Navigator.of(context).push(
          AppMaterialPageRoute<void>(
            builder: (_) => const KitchenDisplayScreen(),
          ),
        ),
        child: const Icon(Icons.kitchen),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final pending = ref.watch(pendingGuestCafeOrdersProvider);
              final count = pending.maybeWhen(
                data: (l) => l.length,
                orElse: () => 0,
              );
              if (count == 0) return const SizedBox.shrink();
              return Material(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.4),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.room_service_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  title: Text(
                    '$count guest menu order${count == 1 ? '' : 's'} pending',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text('Tap to review and send to kitchen'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GuestCafeOrdersScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(
                isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
              ),
              child: Center(
                child: KitchenColumn(
                  title: 'Kitchen Orders',
                  icon: UniconsLine.utensils,
                  headerColor: Theme.of(context).colorScheme.primary,
                  orderStream: _kitchenService(ref).activeOrdersStream,
                  onUpdateStatus: (orderId, _) {
                    _kitchenService(ref).updateOrderStatus(orderId, 'delivered');
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistory(bool isMobile) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    String statusFilterLabel() {
      final f = _selectedOrderStatusFilter;
      if (f == null) return 'All';
      return f.toUpperCase();
    }

    return Column(
      children: [
        Padding(
          padding: isMobile
              ? const EdgeInsets.fromLTRB(12, 6, 12, 6)
              : EdgeInsets.all(AppTheme.kSpacingMedium),
          child: isMobile
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          Icons.calendar_month_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        label: Text(
                          _selectedDateRange == null
                              ? 'Dates'
                              : '${DateFormat.MMMd().format(_selectedDateRange!.start)}–${DateFormat.MMMd().format(_selectedDateRange!.end)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelMedium,
                        ),
                        onPressed: _pickDateRange,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        setState(() {
                          _selectedOrderStatusFilter = value == 'all'
                              ? null
                              : value;
                        });
                      },
                      itemBuilder: (context) =>
                          ['all', 'delivered', 'cancelled', 'refunded']
                              .map(
                                (status) => PopupMenuItem<String>(
                                  value: status,
                                  child: Text(status.toUpperCase()),
                                ),
                              )
                              .toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kBorderRadiusMedium,
                          ),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_list_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusFilterLabel(),
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedDateRange != null ||
                        _selectedOrderStatusFilter != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        tooltip: 'Clear Filters',
                        icon: Icon(
                          Icons.clear_all_rounded,
                          color: colorScheme.secondary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedDateRange = null;
                            _selectedOrderStatusFilter = null;
                          });
                        },
                      ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.calendar_month_outlined, size: 20),
                        label: Text(
                          _selectedDateRange == null
                              ? 'Filter by Date'
                              : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)}',
                        ),
                        onPressed: _pickDateRange,
                        style: theme.outlinedButtonTheme.style?.copyWith(
                          padding: WidgetStateProperty.all(
                            EdgeInsets.symmetric(
                              horizontal: AppTheme.kSpacingMedium,
                              vertical: AppTheme.kSpacingSmall,
                            ),
                          ),
                          textStyle: WidgetStateProperty.all(
                            textTheme.labelLarge,
                          ),
                          side: WidgetStateProperty.all(
                            BorderSide(
                              color: colorScheme.outline.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppTheme.kSpacingSmall),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.kSpacingSmall,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppTheme.kBorderRadiusMedium,
                        ),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.7),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          hint: Text(
                            'Status',
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          value: _selectedOrderStatusFilter,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          icon: Icon(
                            Icons.filter_list_rounded,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                          items: ['all', 'delivered', 'cancelled', 'refunded']
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(
                                    status.toUpperCase(),
                                    style: textTheme.bodyMedium,
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
                          dropdownColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    if (_selectedDateRange != null ||
                        _selectedOrderStatusFilter != null)
                      Tooltip(
                        message: 'Clear Filters',
                        child: IconButton(
                          icon: Icon(
                            Icons.clear_all_rounded,
                            color: colorScheme.secondary,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedDateRange = null;
                              _selectedOrderStatusFilter = null;
                            });
                          },
                          splashRadius: 20,
                        ),
                      ),
                  ],
                ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getOrderHistoryStream().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const InfoPlaceholder(
                  iconData: Icons.error,
                  title: "Error",
                  message: "Could not load order history.",
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingIndicator();
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const InfoPlaceholder(
                  iconData: Icons.history_toggle_off,
                  title: 'No Orders Found',
                  message: 'No orders match the current filters.',
                );
              }
              final orders = snapshot.data!.docs
                  .map((doc) => CafeOrder.fromFirestore(doc))
                  .toList();
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
                  0,
                  isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
                  isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingMedium,
                ), // Adjusted padding
                itemCount: orders.length,
                itemBuilder: (context, index) =>
                    _buildHistoricalOrderCard(orders[index], isMobile),
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
      firstDate: DateTime(DateTime.now().year - 2), // Allow 2 years back
      lastDate: DateTime.now().add(
        const Duration(days: 1),
      ), // Allow up to tomorrow
      initialDateRange:
          _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      helpText: 'Select Date Range',
      cancelText: 'CANCEL',
      confirmText: 'OK',
      builder: (context, child) => child!,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        // Ensure the end of the day for the picked end date for inclusive range
        _selectedDateRange = DateTimeRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
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

  Query _getOrderHistoryStream() {
    final tenant = ref.read(tenantRefProvider)!;
    Query query = tenant
        .cafeOrders()
        // Include session-linked orders which are marked as 'completed'
        .where(
          'status',
          whereIn: ['delivered', 'cancelled', 'refunded', 'completed'],
        );

    if (_selectedDateRange != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start),
      );
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end),
      );
    }

    if (_selectedOrderStatusFilter != null) {
      query = query.where('status', isEqualTo: _selectedOrderStatusFilter);
    }

    return query.orderBy('createdAt', descending: true);
  }

  Widget _buildHistoricalOrderCard(CafeOrder order, bool isMobile) {
    final canRefund = ref.watchResolvedPermissions().can(
      PermissionIds.opsRefund,
    );

    return HistoricalOrderCard(
      order: order,
      isMobile: isMobile,
      canRefund: canRefund,
      onRefund:
          canRefund && !order.isRefunded && order.total > 0 && order.isBilled
          ? () async {
              final result = await Navigator.of(context).push<bool>(
                AppMaterialPageRoute<bool>(
                  builder: (context) => UnifiedRefundScreen(
                    orderId: order.id,
                    orderType: RefundOrderType.cafe,
                  ),
                ),
              );
              if (result == true) {
                if (!mounted) return;
                context.showSuccessSnackbar('Refund processed successfully');
              }
            }
          : null,
    );
  }

  // Helper to verify the 6-digit credit code using shared utility
  Future<bool> _verifyCreditCode(BuildContext context) async {
    if (selectedCustomer == null || selectedCustomer!.creditCode.isEmpty) {
      return true; // No code set for this customer, skip verification
    }
    return CreditVerification.verifyCreditCode(context, selectedCustomer!);
  }

  void _addToOrder(StockItem stockItem) async {
    if (stockItem.price == null || stockItem.price! <= 0) {
      if (mounted) {
        StockHelper.showStockError(
          context,
          'This item cannot be added as its price is not set.',
        );
      }
      return;
    }

    // Get current cart quantity for this item
    final existingIndex = currentOrderItems.indexWhere(
      (orderItem) => orderItem.itemId == stockItem.id,
    );
    final currentCartQty = existingIndex != -1
        ? currentOrderItems[existingIndex].quantity
        : 0;

    // Validate using StockHelper with caching
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    final error = await StockHelper.validateAddToCart(
      tenant: tenant,
      itemId: stockItem.id,
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

    if (existingIndex != -1) {
      // Item exists, update its quantity
      setState(() {
        currentOrderItems[existingIndex] = CafeOrderItem(
          itemId: stockItem.id,
          name: stockItem.name,
          price: stockItem.price!,
          quantity: currentOrderItems[existingIndex].quantity + 1,
          notes: currentOrderItems[existingIndex].notes,
          imageUrl: stockItem.imageUrl,
        );
      });
    } else {
      // Item is new, add it and animate its insertion
      final newItem = CafeOrderItem(
        itemId: stockItem.id,
        name: stockItem.name,
        price: stockItem.price!,
        quantity: 1,
        imageUrl: stockItem.imageUrl,
      );
      setState(() {
        currentOrderItems.insert(
          0,
          newItem,
        ); // Insert at the beginning for visibility
        _animatedListKey.currentState?.insertItem(
          0,
          duration: const Duration(milliseconds: 300),
        );
      });
    }

    // Show success feedback
    if (mounted) {
      StockHelper.showAddedToCart(context, stockItem.name);
    }
  }

  void _removeFromOrder(int index, {bool removeAll = false}) {
    // setState(() { // setState will be called by AnimatedList updates
    if (index < 0 || index >= currentOrderItems.length) return;

    final CafeOrderItem itemToRemove = currentOrderItems[index];

    if (removeAll || itemToRemove.quantity <= 1) {
      currentOrderItems.removeAt(index);
      _animatedListKey.currentState?.removeItem(
        index,
        (context, animation) => SlideTransition(
          // Removed item animation
          position:
              Tween<Offset>(
                begin: const Offset(-1, 0), // Slide out to the left
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
              ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: _buildRemovedOrderItemCard(
              itemToRemove,
            ), // Use a helper to build the card for animation
          ),
        ),
        duration: const Duration(milliseconds: 300),
      );
    } else {
      // Just decrease quantity, item rebuilds via setState
      currentOrderItems[index] = CafeOrderItem(
        itemId: itemToRemove.itemId,
        name: itemToRemove.name,
        price: itemToRemove.price,
        quantity: itemToRemove.quantity - 1,
        notes: itemToRemove.notes,
        imageUrl: itemToRemove.imageUrl,
      );
    }
    setState(() {}); // To rebuild summary or other dependent parts
    // });
  }

  // Helper widget for animating removed items in AnimatedList
  Widget _buildRemovedOrderItemCard(CafeOrderItem orderItem) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    return AppSurface(
      borderRadius: AppTheme.kBorderRadiusMedium,
      margin: const EdgeInsets.symmetric(vertical: AppTheme.kSpacingXSmall),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.kSpacingMedium,
          vertical: AppTheme.kSpacingSmall,
        ),
        leading: _cafeOrderLineLeading(context, orderItem, compact: false),
        title: Text(
          orderItem.name,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '₹${orderItem.price.toStringAsFixed(2)} each',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Text(
          '₹${(orderItem.price * orderItem.quantity).toStringAsFixed(2)}',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
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
      builder: (context) => CartBottomSheet<CafeOrderItem>(
        title: 'Your Order',
        items: currentOrderItems,
        getItemName: (item) => item.name,
        getItemPrice: (item) => item.price,
        getItemQuantity: (item) => item.quantity,
        getItemImageUrl: (item) => item.imageUrl,
        getItemId: (item) => item.itemId,
        getStockQuantity: _getStockQuantity,
        onQuantityChanged: (index, newQuantity) {
          setState(() {
            if (newQuantity <= 0) {
              _removeFromOrder(index);
            } else {
              currentOrderItems[index] = CafeOrderItem(
                itemId: currentOrderItems[index].itemId,
                name: currentOrderItems[index].name,
                price: currentOrderItems[index].price,
                quantity: newQuantity,
                notes: currentOrderItems[index].notes,
                imageUrl: currentOrderItems[index].imageUrl,
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
          _clearCart();
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
      creditsText: _buildSelectedCustomerCredits(),
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
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              Divider(
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
        await _submitOrder(
          PaymentMethod.cash,
          attachToSession: true,
        ); // Pass flag
        if (!mounted) return;
        return;
      } else if (choice != 'pay') {
        return; // User dismissed the sheet
      }
      // If user chose 'pay', proceed to normal payment dialog
    }

    // This part runs if not attaching to session, or if user chose "Pay Separately"
    if (!mounted) return;
    final totalAmount = _calculateTotal();
    final canPayWithCredits =
        selectedCustomer != null && selectedCustomer!.credits >= totalAmount;
    final theme = Theme.of(context); // Added for direct theme access
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final PaymentMethod? selectedPaymentMethod = await showDialog<PaymentMethod>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusLarge),
          ), // Use AppTheme
          titlePadding: const EdgeInsets.fromLTRB(
            AppTheme.kSpacingLarge,
            AppTheme.kSpacingLarge,
            AppTheme.kSpacingLarge,
            AppTheme.kSpacingSmall,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            0.0,
            AppTheme.kSpacingSmall,
            0.0,
            AppTheme.kSpacingLarge,
          ),
          title: Text(
            'Select Payment Method',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPaymentOptionTile(
                Icons.money_outlined,
                'Cash',
                PaymentMethod.cash,
                colorScheme.primary,
                theme,
              ),
              _buildPaymentOptionTile(
                Icons.account_balance_wallet_outlined,
                'UPI',
                PaymentMethod.upi,
                colorScheme.primary,
                theme,
              ), // Changed icon for UPI
              if (selectedCustomer != null)
                ListTile(
                  leading: Icon(
                    Icons.stars_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Use Credits'),
                  subtitle: Text(
                    '(Available: ₹${selectedCustomer!.credits.toStringAsFixed(2)})',
                  ),
                  onTap: () => Navigator.pop(context, PaymentMethod.credits),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.kSpacingLarge,
                    vertical: AppTheme.kSpacingSmall / 2,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.secondary,
                ),
              ),
            ),
          ],
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
          return; // Abort payment if verification fails
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
      } catch (e, stackTrace) {
        AppLogger.error(
          'Error submitting order',
          error: e,
          stackTrace: stackTrace,
          tag: 'CafeScreen',
        );
        if (mounted) {
          SnackbarHelper.showError(
            context,
            'Error processing payment: ${e.toString()}',
            actionLabel: AppStrings.retry,
            onAction: _showPaymentOptionsDialog,
            duration: const Duration(seconds: 5),
          );
        }
      }
    }
  }

  // Helper for payment option ListTiles
  Widget _buildPaymentOptionTile(
    IconData icon,
    String title,
    PaymentMethod paymentMethod,
    Color iconColor,
    ThemeData theme,
  ) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 28),
      title: Text(title, style: theme.textTheme.titleMedium),
      onTap: () => Navigator.pop(context, paymentMethod),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.kSpacingLarge,
        vertical: AppTheme.kSpacingSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusSmall),
      ), // Subtle shape
      hoverColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
    );
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
      // This should ideally be caught before calling _submitOrder
      // e.g. by disabling the payment button.
      // However, as a safeguard:
      if (mounted) {
        context.showWarningSnackbar('Cannot submit an empty order.');
      }
      // No need to throw an exception here if we are handling user feedback directly.
      return; // Return early to prevent further processing
    }

    final totalAmount = _calculateTotal();
    double? newlyCalculatedCreditsForSelectedCustomer; // track updated credits

    // Determine payment details
    PaymentMethod? primaryMethod;
    Map<String, double> paymentBreakdown = {};
    double creditsUsedInPayment = 0.0;

    if (paymentData is PaymentMethod) {
      primaryMethod = paymentData;
      if (primaryMethod == PaymentMethod.credits) {
        creditsUsedInPayment = totalAmount;
        paymentBreakdown = {'credits': totalAmount};
      }
    } else if (paymentData is Map) {
      paymentBreakdown = Map<String, double>.from(paymentData);
      creditsUsedInPayment =
          paymentBreakdown['credits'] ?? paymentBreakdown['Credits'] ?? 0.0;
      // Determine non-credit portion primary method (Cash/UPI) - handle both cases
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

    // Determine attach-to-session scenario (recomputed for safety)
    final bool isAttach = attachToSession;
    final String? activeSessionId = isAttach
        ? selectedTable?.currentSessionId
        : null;
    final currentUser = ref.read(appUserProvider).value;

    try {
      final tenant = ref.read(tenantRefProvider)!;
      // Create a batch for the transaction
      final batch = tenant.db.batch();

      // Prepare the order document with a human-readable sequential ID
      final String orderId = await OrderIdService.generate(
        tenant,
        OrderCategory.cafe,
      );
      final orderRef = tenant.cafeOrders().doc(orderId);
      final Map<String, dynamic> orderData = {
        'items': currentOrderItems.map((item) => item.toFirestore()).toList(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'total': totalAmount,
        if (paymentBreakdown.isNotEmpty) 'paymentBreakdown': paymentBreakdown,
        if (creditsUsedInPayment > 0) 'creditsUsed': creditsUsedInPayment,
        'customerId': selectedCustomer?.id,
        'customerName': selectedCustomer?.name,
        'tableId': selectedTable?.id,
        'tableName': selectedTable?.name,
        'sessionId': activeSessionId,
        'isBilled': isAttach ? false : true,
        'billedAt': isAttach ? null : FieldValue.serverTimestamp(),
        'performedById': currentUser?.uid,
        'performedByName': currentUser?.name,
        'performedByRole': currentUser?.role.name,
      };
      // Set paymentMethod only for immediate-billed orders.
      // For session-attached orders, defer to session payment mode at checkout.
      if (!isAttach) {
        if (primaryMethod != null) {
          orderData['paymentMethod'] = primaryMethod.toString().split('.').last;
        } else {
          orderData['paymentMethod'] = 'split';
        }
      } else {
        orderData['paymentMethod'] = null;
      }

      // Set the order document
      batch.set(orderRef, orderData);

      if (isAttach && activeSessionId != null) {
        final sessionRef = tenant.sessions().doc(activeSessionId);
        batch.update(sessionRef, {
          'cafeOrderIds': FieldValue.arrayUnion([orderRef.id]),
          'totalCafeAmount': FieldValue.increment(totalAmount),
          'totalBillAmount': FieldValue.increment(totalAmount),
          'hasUnbilledOrders': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Process credits payment if applicable (only immediate payments)
      // Credits will be debited atomically AFTER batch commit to prevent negative balances
      // Store the order ID to use for credit debit reference
      final String orderIdForCredits = orderRef.id;

      // Process stock deductions
      for (final orderItem in currentOrderItems) {
        if (orderItem.itemId.isEmpty) {
          throw Exception(
            "Order item ${orderItem.name} is missing a valid item ID!",
          );
        }

        // Get current stock item data
        final stockItemRef = tenant.stockItems().doc(orderItem.itemId);
        final stockItemDoc = await stockItemRef.get();

        if (!stockItemDoc.exists) {
          throw Exception(
            "Stock item for ${orderItem.name} (ID: ${orderItem.itemId}) not found!",
          );
        }

        final stockData = stockItemDoc.data()!;
        final currentStockQuantity = parseFirestoreDouble(
          stockData['quantity'],
        );
        final consumedQuantity = orderItem.quantity.toDouble();

        if (currentStockQuantity < consumedQuantity) {
          final unit = stockData['unit'] as String? ?? 'units';
          throw Exception(
            "Not enough stock for ${orderItem.name}. Required: $consumedQuantity, Available: $currentStockQuantity ($unit)",
          );
        }

        final newStockQuantity = currentStockQuantity - consumedQuantity;
        batch.update(stockItemRef, {
          'quantity': newStockQuantity,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Commit all changes (order + stock updates)
      await batch.commit();

      // Process credits payment atomically AFTER batch commit (only immediate payments)
      // This uses a Firestore transaction to prevent negative balances
      if (!isAttach && creditsUsedInPayment > 0 && selectedCustomer != null) {
        final debitResult = await CreditService.safeDebitCredits(
          tenant: tenant,
          customerId: selectedCustomer!.id,
          amount: creditsUsedInPayment,
          reference: CreditReference.cafeOrder(orderIdForCredits),
          performedBy: currentUser,
        );

        if (!debitResult.success) {
          // Credit debit failed - we need to refund/cancel the order
          // Update order to mark it as needing attention
          await tenant.cafeOrders().doc(orderIdForCredits).update({
            'creditDebitFailed': true,
            'creditDebitError': debitResult.error,
            'status': 'payment_pending',
          });

          if (mounted) {
            SnackbarHelper.showError(
              context,
              debitResult.error ??
                  'Insufficient credits. Please use another payment method.',
              duration: const Duration(seconds: 5),
            );
          }
          // Don't clear the cart - allow user to retry with different payment
          return;
        }

        newlyCalculatedCreditsForSelectedCustomer = debitResult.newBalance;
      }

      // --- Print Documents ---
      try {
        final printItems = currentOrderItems
            .map(
              (it) => {
                'name': it.name,
                'price': it.price,
                'quantity': it.quantity,
              },
            )
            .toList();

        if (isAttach) {
          // If attaching to a session, only print the KOT for the kitchen.
          await PrinterService.printDocument(
            jobType: PrintJobType.kotOnly,
            id: orderRef.id,
            items: printItems,
            customerName: selectedCustomer?.name,
            tableName: selectedTable?.name,
          );
        } else {
          // For immediate sales, print a combined Bill and KOT.
          await PrinterService.printDocument(
            jobType: PrintJobType.billWithKot,
            id: orderRef.id,
            items: printItems,
            total: totalAmount,
            customerName: selectedCustomer?.name,
            tableName: selectedTable?.name,
            creditsUsed: creditsUsedInPayment > 0 ? creditsUsedInPayment : null,
          );
        }
      } catch (e) {
        AppLogger.warning('Error during printing: $e', tag: 'CafeScreen');
      }

      // Update local state after successful transaction
      if (creditsUsedInPayment > 0 &&
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
        if (!attachToSession) {
          selectedCustomer = null;
          selectedTable = null;
        }
      });
      _animatedListKey.currentState?.setState(() {});

      if (mounted) {
        context.showSuccessSnackbar(
          isAttach
              ? 'Order added to session successfully!'
              : 'Order submitted and paid successfully!',
        );
      }
    } catch (e, s) {
      AppLogger.error(
        'Error submitting order',
        error: e,
        stackTrace: s,
        tag: 'CafeScreen',
      );
      rethrow;
    }
  }

  Future<void> _clearCart() async {
    if (currentOrderItems.isEmpty) {
      if (mounted) {
        context.showInfoSnackbar('Cart is already empty!');
      }
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Clear Cart'),
          content: const Text(
            'Are you sure you want to remove all items from your cart?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(AppStrings.cancel),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text(
                'Clear Cart',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      // Animate removal for all items
      for (int i = currentOrderItems.length - 1; i >= 0; i--) {
        final itemToRemove = currentOrderItems[i];
        // Remove from data source first
        currentOrderItems.removeAt(i);
        // Then animate removal from AnimatedList
        _animatedListKey.currentState?.removeItem(
          i,
          (context, animation) => SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(-1, 0), // Slide out to the left
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutQuart,
                  ),
                ),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
              child: _buildRemovedOrderItemCard(
                itemToRemove,
              ), // Use existing helper for removed item appearance
            ),
          ),
          duration: const Duration(
            milliseconds: 150,
          ), // Faster animation for clear all
        );
      }
      // Final setState to update summary and other UI elements if not handled by removeItem animation callbacks
      setState(() {});

      if (mounted) {
        context.showSuccessSnackbar('Cart cleared!');
      }
    }
  }
}
