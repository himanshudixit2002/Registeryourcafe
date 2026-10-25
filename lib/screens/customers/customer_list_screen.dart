import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/customer.dart';
import '../../models/membership_type_definition.dart';
import '../../models/venue_ui_config.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/membership_type_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/constrained_page_content.dart';
import '../../widgets/responsive_scaffold.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/app_card.dart';
import '../../services/recent_customers_service.dart';
import 'customer_detail_screen.dart';
import 'add_customer_screen.dart';
import 'all_credit_transactions_screen.dart';
import 'package:registeryourcafe/auth/permission_id.dart';
import 'package:registeryourcafe/providers/permissions_provider.dart';
import 'package:registeryourcafe/providers/user_ui_prefs_provider.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  String _searchQuery = '';

  /// `null` = all tiers; otherwise filter by [MembershipTypeDefinition.id].
  String? _selectedMembershipFilterId;
  bool _showLowCreditOnly = false;
  bool _showExpiringMembershipsOnly = false;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // Low credit threshold constant (₹)
  static const double _lowCreditThreshold = 500.0;

  // Recent customers from local storage
  List<RecentCustomerData> _recentCustomers = [];
  bool _showRecentSection = true;
  bool _useFirestoreFallback =
      false; // Use Firestore when local storage is empty

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecentCustomers());
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        // Hide recent section when searching
        _showRecentSection = _searchQuery.isEmpty;
        // Ensure the list scrolls back to the top so that freshly
        // filtered / searched results (which are rendered right after
        // the filters widget) are visible without the user having to
        // manually scroll.
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    });
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadRecentCustomers() async {
    try {
      final recent = await RecentCustomersService.getRecentCustomers();
      if (mounted) {
        setState(() {
          _recentCustomers = recent;
          // If local storage is empty, fall back to Firestore recently added
          _useFirestoreFallback = recent.isEmpty;
        });
      }
    } catch (e) {
      // On error (e.g., web storage issues), use Firestore fallback
      if (mounted) {
        setState(() {
          _recentCustomers = [];
          _useFirestoreFallback = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(customerListProvider.notifier).fetchMore();
    }
  }

  List<Customer> _getFilteredCustomers(List<Customer> customers) {
    return customers.where((customer) {
      final query = _searchQuery.toLowerCase();
      final nameMatch = customer.name.toLowerCase().contains(query);
      final phoneMatch = customer.phoneNumber.contains(query);
      final emailMatch = customer.email?.toLowerCase().contains(query) ?? false;
      final membershipIdMatch =
          (customer.membershipId?.toLowerCase().contains(query) ?? false);
      final membershipMatch =
          _selectedMembershipFilterId == null ||
          normalizeMembershipTypeId(customer.membershipTypeId) ==
              normalizeMembershipTypeId(_selectedMembershipFilterId);
      // Determine if customer is low on credit by threshold OR alert flag
      final bool isLowCredit =
          customer.credits < _lowCreditThreshold || customer.hasLowCreditAlert;
      final lowCreditMatch = !_showLowCreditOnly || isLowCredit;
      final expiringMatch =
          !_showExpiringMembershipsOnly || customer.hasMembershipExpiryAlert;
      return (nameMatch || phoneMatch || emailMatch || membershipIdMatch) &&
          membershipMatch &&
          lowCreditMatch &&
          expiringMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perms = ref.watchResolvedPermissions();
    final bool canCustomersAdmin = perms.can(PermissionIds.opsCustomersAdmin);
    final bool canSeeCreditCode = perms.can(PermissionIds.navCustomers);
    final customersAsyncValue = ref.watch(customerListProvider);
    final compactLists = ref.watch(userUiPrefsProvider).compactListDensity;
    final membershipDefs =
        ref.watch(activeMembershipTypeDefinitionsProvider).valueOrNull ?? [];
    // Removed unused local provider values to reduce warnings

    // --------------------------------------------------------------------
    // Remote search: fetch matching customers from Firestore when the user
    // enters a query. This prevents pagination issues where the desired
    // customer might exist beyond the currently loaded page.
    // --------------------------------------------------------------------
    final bool isSearchingRemotely = _searchQuery.trim().isNotEmpty;
    final AsyncValue<List<Customer>>? searchResultsAsync = isSearchingRemotely
        ? ref.watch(searchCustomersProvider(_searchQuery.trim()))
        : null;

    if (!perms.can(PermissionIds.navCustomers)) {
      return ResponsiveScaffold(
        title: ref.watch(venueKindProvider).customerTabLabel,
        useAppBar: false,
        body: Center(child: Text('You do not have access to ${ref.watch(venueKindProvider).customerPlural}.')),
      );
    }

    final allCustomers = customersAsyncValue.valueOrNull ?? [];
    final filteredCustomers = _getFilteredCustomers(allCustomers);

    return ResponsiveScaffold(
      title: ref.watch(venueKindProvider).customerTabLabel,
      useAppBar: false,
      floatingActionButton: canCustomersAdmin
          ? FloatingActionButton.extended(
              heroTag: 'fab-shell-customers',
              onPressed: () {
                Navigator.push<Object?>(
                  context,
                  AppMaterialPageRoute<Object?>(
                    builder: (context) => const AddCustomerScreen(),
                  ),
                ).then((success) {
                  if (success == true) {
                    ref.read(customerListProvider.notifier).refresh();
                  }
                });
              },
              label: const Text('New Customer'),
              icon: const Icon(Icons.add),
            )
          : null,
      actions: [
        if (canCustomersAdmin && !AppTheme.isMobile(context))
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            icon: const Icon(Icons.attach_money_rounded),
            label: const Text('All Transactions'),
            onPressed: () {
              Navigator.push(
                context,
                AppMaterialPageRoute<void>(
                  builder: (context) => const AllCreditTransactionsScreen(),
                ),
              );
            },
          ),
        if (canCustomersAdmin && AppTheme.isMobile(context))
          IconButton(
            icon: const Icon(Icons.attach_money_rounded),
            tooltip: 'All Transactions',
            onPressed: () {
              Navigator.push(
                context,
                AppMaterialPageRoute<void>(
                  builder: (context) => const AllCreditTransactionsScreen(),
                ),
              );
            },
          ),
      ],
      body: ConstrainedPageContent(
        child: RefreshIndicator(
          onRefresh: () async {
            await HapticFeedback.mediumImpact();
            await ref.read(customerListProvider.notifier).refresh();
            await _loadRecentCustomers();
          },
          color: theme.colorScheme.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: AppTheme.scrollPhysicsFor(context),
            slivers: [
              SliverToBoxAdapter(child: _buildFilters(theme, membershipDefs)),
              // ----------------------------------------------------------------
              // Recent Customers Section - Show recently used customers first
              // Uses local storage on mobile, Firestore fallback on web
              // ----------------------------------------------------------------
              if (_showRecentSection && !isSearchingRemotely)
                _useFirestoreFallback
                    ? _buildFirestoreRecentSection(
                        theme,
                        canSeeCreditCode,
                        membershipDefs,
                      )
                    : (_recentCustomers.isNotEmpty
                          ? _buildRecentCustomersSection(
                              theme,
                              canSeeCreditCode,
                            )
                          : const SliverToBoxAdapter(child: SizedBox.shrink())),
              // ----------------------------------------------------------------
              // When searching remotely, prioritise those results over the locally
              // paginated dataset.
              // ----------------------------------------------------------------
              if (isSearchingRemotely && searchResultsAsync != null) ...[
                searchResultsAsync.when(
                  data: (results) {
                    if (results.isEmpty) {
                      // Fallback to the locally-loaded (paginated) dataset. This
                      // ensures we still show results that might already be in
                      // memory even if the remote prefix search failed due to
                      // case-sensitivity or partial phone match.
                      if (customersAsyncValue.hasValue) {
                        return _buildCustomerSliver(
                          filteredCustomers,
                          theme,
                          canSeeCreditCode,
                          compactLists,
                          membershipDefs,
                        );
                      }
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('No matching customers found.'),
                        ),
                      );
                    }
                    final filteredRemote = _getFilteredCustomers(results);
                    return _buildCustomerSliver(
                      filteredRemote,
                      theme,
                      canSeeCreditCode,
                      compactLists,
                      membershipDefs,
                    );
                  },
                  loading: () => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      childCount: 8,
                    ),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Error: $e')),
                  ),
                ),
              ] else ...[
                if (customersAsyncValue.hasValue)
                  _buildCustomerSliver(
                    filteredCustomers,
                    theme,
                    canSeeCreditCode,
                    compactLists,
                    membershipDefs,
                  )
                else if (customersAsyncValue.isLoading)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      childCount: 8,
                    ),
                  )
                else if (customersAsyncValue.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'Error: ${customersAsyncValue.error.toString()}',
                      ),
                    ),
                  ),
                _buildLoadingIndicator(context, customersAsyncValue),
              ],
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(
    ThemeData theme,
    List<MembershipTypeDefinition> membershipDefs,
  ) {
    final isSmallScreen = AppTheme.isMobile(context);
    final tierChips = List<MembershipTypeDefinition>.from(membershipDefs)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar
        Padding(
          padding: EdgeInsets.fromLTRB(
            isSmallScreen ? 12 : 16,
            isSmallScreen ? 12 : 16,
            isSmallScreen ? 12 : 16,
            isSmallScreen ? 8 : 12,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
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
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isSmallScreen
                    ? 'Search customers...'
                    : 'Search by name, phone, email, membership ID...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: isSmallScreen ? 14 : 15,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: isSmallScreen ? 20 : 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 12 : 14,
                  horizontal: 16,
                ),
              ),
              style: TextStyle(fontSize: isSmallScreen ? 14 : 15),
            ),
          ),
        ),
        // Filter chips - horizontal scrolling
        SizedBox(
          height: isSmallScreen ? 42 : 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
            children: [
              // Membership type chips
              AppFilterChip(
                label: 'All',
                isSelected: _selectedMembershipFilterId == null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMembershipFilterId = null);
                },
              ),
              ...tierChips.map(
                (d) => AppFilterChip(
                  label: d.name,
                  isSelected: _selectedMembershipFilterId == d.id,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedMembershipFilterId = d.id);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Divider
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: theme.colorScheme.outline.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 8),
              // Alert filters
              AppFilterChip(
                label: 'Low Credit',
                icon: Icons.credit_card_off_rounded,
                isSelected: _showLowCreditOnly,
                selectedColor: theme.colorScheme.error,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _showLowCreditOnly = !_showLowCreditOnly;
                    if (_showLowCreditOnly) {
                      _showExpiringMembershipsOnly = false;
                    }
                  });
                },
              ),
              AppFilterChip(
                label: 'Expiring',
                icon: Icons.event_busy_rounded,
                isSelected: _showExpiringMembershipsOnly,
                selectedColor: theme.colorScheme.error,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _showExpiringMembershipsOnly =
                        !_showExpiringMembershipsOnly;
                    if (_showExpiringMembershipsOnly) {
                      _showLowCreditOnly = false;
                    }
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Build Firestore-based recent section (fallback for web)
  /// Shows recently CREATED customers from Firestore
  Widget _buildFirestoreRecentSection(
    ThemeData theme,
    bool canSeeCreditCode,
    List<MembershipTypeDefinition> membershipDefs,
  ) {
    final recentAsync = ref.watch(recentlyAddedCustomersProvider);
    final isSmallScreen = AppTheme.isMobile(context);

    return recentAsync.when(
      data: (customers) {
        if (customers.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section header
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isSmallScreen ? 12 : 16,
                  8,
                  isSmallScreen ? 12 : 16,
                  8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_add_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recently Added',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${customers.length} new',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Horizontal scroll of customers
              SizedBox(
                height: isSmallScreen ? 110 : 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: AppTheme.scrollPhysicsFor(context),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                  ),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return _buildFirestoreCustomerChip(
                      theme,
                      customer,
                      isSmallScreen,
                      membershipDefs,
                    );
                  },
                ),
              ),
              // Divider
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'All Customers',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  /// Build a chip for Firestore customer (fallback version)
  Widget _buildFirestoreCustomerChip(
    ThemeData theme,
    Customer customer,
    bool isSmallScreen,
    List<MembershipTypeDefinition> membershipDefs,
  ) {
    final def = lookupMembershipType(membershipDefs, customer.membershipTypeId);
    final chipColor = def?.color ?? theme.colorScheme.primary;
    final label = membershipDisplayName(
      customer.membershipTypeId,
      membershipDefs,
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: () async {
            await HapticFeedback.lightImpact();
            // Record as recent and navigate
            await RecentCustomersService.recordRecentCustomer(
              RecentCustomerData(
                id: customer.id,
                name: customer.name,
                phoneNumber: customer.phoneNumber,
                membershipId: customer.membershipId,
                credits: customer.credits,
                lastUsed: DateTime.now(),
              ),
            );
            if (!mounted) return;
            await Navigator.push(
              context,
              AppMaterialPageRoute<void>(
                builder: (context) =>
                    CustomerDetailScreen(customerId: customer.id),
              ),
            );
            await ref.read(customerListProvider.notifier).refresh();
            await _loadRecentCustomers();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: isSmallScreen ? 100 : 110,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                        theme.colorScheme.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.surface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Name
                Text(
                  customer.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                // Membership badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: chipColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build the Recent Customers section - shows recently used customers at the top
  Widget _buildRecentCustomersSection(ThemeData theme, bool canSeeCreditCode) {
    final isSmallScreen = AppTheme.isMobile(context);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header with toggle
          Padding(
            padding: EdgeInsets.fromLTRB(
              isSmallScreen ? 12 : 16,
              8,
              isSmallScreen ? 12 : 16,
              8,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Customers',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_recentCustomers.length} recent',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          // Recent customers horizontal scroll
          SizedBox(
            height: isSmallScreen ? 110 : 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: AppTheme.scrollPhysicsFor(context),
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12),
              itemCount: _recentCustomers.length,
              itemBuilder: (context, index) {
                final data = _recentCustomers[index];
                return _buildRecentCustomerChip(theme, data, isSmallScreen);
              },
            ),
          ),
          // Divider
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'All Customers',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a compact chip-like card for recent customers
  Widget _buildRecentCustomerChip(
    ThemeData theme,
    RecentCustomerData data,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: () => _navigateToRecentCustomer(data),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: isSmallScreen ? 100 : 110,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                        theme.colorScheme.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      data.name.isNotEmpty ? data.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: theme.colorScheme.surface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Name
                Text(
                  data.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                // Credits
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: data.credits > 0
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '₹${data.credits.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: data.credits > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Navigate to a recent customer, fetching fresh data from Firestore
  Future<void> _navigateToRecentCustomer(RecentCustomerData data) async {
    await HapticFeedback.lightImpact();
    if (!mounted) return;

    // Navigate directly to customer detail
    final result = await Navigator.push<bool?>(
      context,
      AppMaterialPageRoute<bool?>(
        builder: (context) => CustomerDetailScreen(customerId: data.id),
      ),
    );

    // Refresh on return
    if (result == true || result == null) {
      await ref.read(customerListProvider.notifier).refresh();
      await _loadRecentCustomers();
    }
  }

  Widget _buildCustomerSliver(
    List<Customer> filteredCustomers,
    ThemeData theme,
    bool canSeeCreditCode,
    bool compactLists,
    List<MembershipTypeDefinition> membershipDefs,
  ) {
    if (filteredCustomers.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No customers match the current filters.')),
      );
    }

    final isDesktop = AppTheme.isDesktop(context);

    if (isDesktop) {
      // Use a Grid for wider screens
      return SliverPadding(
        padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260, // allows more columns on wide screens
            mainAxisSpacing: AppTheme.kSpacingMedium,
            crossAxisSpacing: AppTheme.kSpacingMedium,
            childAspectRatio: 1.3,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final customer = filteredCustomers[index];
            return _buildCustomerCard(
              customer,
              theme,
              canSeeCreditCode,
              compactLists,
              membershipDefs,
            );
          }, childCount: filteredCustomers.length),
        ),
      );
    } else {
      // Use a List for narrower screens - mobile optimized cards
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        sliver: SliverList(
          key: const ValueKey('customer_list'),
          delegate: SliverChildBuilderDelegate((context, index) {
            final customer = filteredCustomers[index];
            return _buildMobileCustomerCard(
              customer,
              theme,
              canSeeCreditCode,
              compactLists,
              membershipDefs,
            );
          }, childCount: filteredCustomers.length),
        ),
      );
    }
  }

  Widget _buildMobileCustomerCard(
    Customer customer,
    ThemeData theme,
    bool canSeeCreditCode,
    bool compactLists,
    List<MembershipTypeDefinition> membershipDefs,
  ) {
    final bool isLowCredit =
        customer.credits < _lowCreditThreshold || customer.hasLowCreditAlert;
    final bool hasAlert = isLowCredit || customer.hasMembershipExpiryAlert;

    return Padding(
      padding: EdgeInsets.only(bottom: compactLists ? 4 : 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          onTap: () async {
            await HapticFeedback.lightImpact();
            // Record as recent customer
            await RecentCustomersService.recordRecentCustomer(
              RecentCustomerData(
                id: customer.id,
                name: customer.name,
                phoneNumber: customer.phoneNumber,
                membershipId: customer.membershipId,
                credits: customer.credits,
                lastUsed: DateTime.now(),
              ),
            );
            if (!mounted) return;
            await Navigator.push(
              context,
              AppMaterialPageRoute<void>(
                builder: (context) =>
                    CustomerDetailScreen(customerId: customer.id),
              ),
            );
            await ref.read(customerListProvider.notifier).refresh();
            await _loadRecentCustomers();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.all(compactLists ? 8 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasAlert
                    ? theme.colorScheme.tertiary.withValues(alpha: 0.4)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: compactLists ? 40 : 48,
                  height: compactLists ? 40 : 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                        theme.colorScheme.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.surface,
                        fontWeight: FontWeight.bold,
                        fontSize: compactLists ? 15 : 18,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: compactLists ? 8 : 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasAlert)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer
                                    .withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: compactLists ? 2 : 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            customer.phoneNumber,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (customer.membershipId != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.badge_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                customer.membershipId!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (canSeeCreditCode &&
                          customer.creditCode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.key_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              customer.creditCode,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Credits & Membership
                Consumer(
                  builder: (context, ref, _) {
                    final txsAsync = ref.watch(
                      customerCreditLedgerProvider(customer.id),
                    );
                    return txsAsync.when(
                      data: (txs) {
                        final totalAdded = txs
                            .where((t) => t.amount >= 0)
                            .fold<double>(0, (p, t) => p + t.amount);
                        final totalUsed = txs
                            .where((t) => t.amount < 0)
                            .fold<double>(0, (p, t) => p + t.amount.abs());
                        final balance = totalAdded - totalUsed;
                        return _buildCreditsColumn(
                          customer,
                          balance,
                          theme,
                          membershipDefs,
                        );
                      },
                      loading: () => _buildCreditsColumn(
                        customer,
                        customer.credits,
                        theme,
                        membershipDefs,
                      ),
                      error: (e, s) => _buildCreditsColumn(
                        customer,
                        customer.credits,
                        theme,
                        membershipDefs,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.75,
                  ),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreditsColumn(
    Customer customer,
    double balance,
    ThemeData theme,
    List<MembershipTypeDefinition> membershipDefs,
  ) {
    final bool isLow = balance < _lowCreditThreshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isLow
                ? theme.colorScheme.error.withValues(alpha: 0.1)
                : theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '₹${balance.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isLow
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          membershipDisplayName(customer.membershipTypeId, membershipDefs),
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator(
    BuildContext context,
    AsyncValue<List<Customer>> customersAsyncValue,
  ) {
    // Show loading indicator at the bottom if we're loading more and have existing data.
    // The `when` clause handles the initial loading screen.
    if (customersAsyncValue.isLoading && customersAsyncValue.hasValue) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.kSpacingMedium),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    // Show an error message at the bottom if fetching more failed.
    if (customersAsyncValue.hasError &&
        !customersAsyncValue.isLoading &&
        customersAsyncValue.hasValue) {
      final cs = Theme.of(context).colorScheme;
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
            child: Column(
              children: [
                Text(
                  'Could not load more customers.',
                  style: TextStyle(color: cs.error),
                ),
                const SizedBox(height: AppTheme.kSpacingSmall),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text(AppStrings.retry),
                  onPressed: () =>
                      ref.read(customerListProvider.notifier).fetchMore(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.tertiaryContainer,
                    foregroundColor: cs.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildCustomerCard(
    Customer customer,
    ThemeData theme,
    bool canSeeCreditCode,
    bool compactLists,
    List<MembershipTypeDefinition> membershipDefs,
  ) {
    final bool isLowCredit =
        customer.credits < _lowCreditThreshold || customer.hasLowCreditAlert;
    final bool hasAlert = isLowCredit || customer.hasMembershipExpiryAlert;
    return AnimatedCard(
      key: ValueKey('${customer.id}_grid_card'), // Added key
      onTap: () async {
        // Record as recent customer
        await RecentCustomersService.recordRecentCustomer(
          RecentCustomerData(
            id: customer.id,
            name: customer.name,
            phoneNumber: customer.phoneNumber,
            membershipId: customer.membershipId,
            credits: customer.credits,
            lastUsed: DateTime.now(),
          ),
        );
        if (!mounted) return;
        await Navigator.push(
          context,
          AppMaterialPageRoute<void>(
            builder: (context) => CustomerDetailScreen(customerId: customer.id),
          ),
        );
        await ref.read(customerListProvider.notifier).refresh();
        await _loadRecentCustomers();
      },
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(
              compactLists ? AppTheme.kSpacingXSmall : AppTheme.kSpacingSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0] : '?',
                      ),
                    ),
                    const SizedBox(width: AppTheme.kSpacingMedium), // Const
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            customer.phoneNumber,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (customer.membershipId != null)
                            Text(
                              // Made const
                              'ID: ${customer.membershipId}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ), // Const style
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (canSeeCreditCode &&
                              customer.creditCode.isNotEmpty)
                            Text(
                              // Made const
                              'Code: ${customer.creditCode}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ), // Const style
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(), // Const
                Divider(
                  thickness: 1,
                  color: AppTheme.subtleDividerColor(theme),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Membership',
                          style: TextStyle(fontSize: 12),
                        ), // Const
                        Text(
                          membershipDisplayName(
                            customer.membershipTypeId,
                            membershipDefs,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final txsAsync = ref.watch(
                          customerCreditLedgerProvider(customer.id),
                        );
                        return txsAsync.when(
                          data: (txs) {
                            final totalAdded = txs
                                .where((t) => t.amount >= 0)
                                .fold<double>(0, (p, t) => p + t.amount);
                            final totalUsed = txs
                                .where((t) => t.amount < 0)
                                .fold<double>(0, (p, t) => p + t.amount.abs());
                            final balance = totalAdded - totalUsed;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Credits',
                                  style: TextStyle(fontSize: 12),
                                ), // Const
                                Text(
                                  ' \u20B9${balance.toStringAsFixed(0)}',
                                  key: ValueKey(
                                    '${customer.id}_grid_balance',
                                  ), // Key
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: (balance < _lowCreditThreshold)
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Credits',
                                style: TextStyle(fontSize: 12),
                              ), // Const
                              Text(
                                ' \u20B9${customer.credits.toStringAsFixed(0)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      (customer.credits < _lowCreditThreshold)
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          error: (e, s) => Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Credits',
                                style: TextStyle(fontSize: 12),
                              ), // Const
                              Text(
                                ' \u20B9${customer.credits.toStringAsFixed(0)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      (customer.credits < _lowCreditThreshold)
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasAlert)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.tertiary,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}
