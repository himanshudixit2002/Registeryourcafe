import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

import '../../models/customer.dart';
import '../../models/membership_type_definition.dart';
import '../../auth/permission_id.dart';
import '../../providers/customer_provider.dart';
import '../../providers/membership_type_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../screens/customers/add_customer_screen.dart';
import '../../theme/app_theme.dart';
import '../../services/recent_customers_service.dart';
import '../customer_ui_components.dart';

/// Enhanced customer selection dialog with:
/// - Instant recent customers from local storage
/// - Smart caching for faster subsequent loads
/// - Smooth animations and haptic feedback
/// - Mobile-optimized UI
class CustomerSelectionDialog extends ConsumerStatefulWidget {
  final CollectionReference<Map<String, dynamic>> customers;

  const CustomerSelectionDialog({super.key, required this.customers});

  @override
  ConsumerState<CustomerSelectionDialog> createState() =>
      _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState
    extends ConsumerState<CustomerSelectionDialog> {
  String _searchQuery = '';
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  List<RecentCustomerData> _recentCustomers = [];
  bool _isLoading = true;
  bool _showRecent = true;
  bool _useFirestoreFallback =
      false; // Use Firestore when local storage is empty (web)

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load recent customers instantly from local storage
    try {
      _recentCustomers = await RecentCustomersService.getRecentCustomers();
      _useFirestoreFallback = _recentCustomers.isEmpty;
    } catch (e) {
      // On error (e.g., web storage issues), use Firestore fallback
      _recentCustomers = [];
      _useFirestoreFallback = true;
    }
    if (mounted) setState(() {});

    // Then load all customers (from cache or Firestore)
    await _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _allCustomers = await CustomerCacheManager.fetchAllCustomers(
        widget.customers,
      );
      _filteredCustomers = _allCustomers;

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.errorContainer,
            content: Text(
              'Error fetching customers: ${e.toString()}',
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        );
      }
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      _searchQuery = query;
      _showRecent = query.isEmpty;
      _filteredCustomers = CustomerCacheManager.filterCustomers(
        _allCustomers,
        query,
      );
    });
  }

  Future<void> _selectCustomer(Customer customer) async {
    await HapticFeedback.mediumImpact();

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

    if (mounted) {
      Navigator.of(context).pop(customer);
    }
  }

  Future<void> _selectRecentCustomer(RecentCustomerData data) async {
    await HapticFeedback.lightImpact();

    try {
      final doc = await widget.customers.doc(data.id).get();
      if (doc.exists) {
        final customer = Customer.fromFirestore(doc);
        if (context.mounted) {
          await _selectCustomer(customer);
        }
      } else {
        await RecentCustomersService.removeRecentCustomer(data.id);
        if (mounted) {
          setState(() {
            _recentCustomers.removeWhere((c) => c.id == data.id);
          });
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.inverseSurface,
              content: Text(
                'Customer no longer exists',
                style: TextStyle(color: cs.onInverseSurface),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.errorContainer,
            content: Text(
              'Error loading customer: $e',
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        );
      }
    }
  }

  Future<void> _addNewCustomer() async {
    if (!ref.readResolvedPermissions().can(PermissionIds.navCustomers)) {
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.errorContainer,
          content: Text(
            'You do not have permission to add customers.',
            style: TextStyle(color: cs.onErrorContainer),
          ),
        ),
      );
      return;
    }
    final newCustomerData = await Navigator.of(context).push<Object?>(
      AppMaterialPageRoute<Object?>(
        builder: (_) => const AddCustomerScreen(returnCustomer: true),
      ),
    );
    if (newCustomerData is Customer) {
      await _selectCustomer(newCustomerData);
    } else if (newCustomerData == true) {
      CustomerCacheManager.clearCache();
      await _fetchCustomers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < AppTheme.kMobileBreakpoint;
    final dialogWidth = isMobile
        ? size.width * 0.95
        : (size.width * 0.7).clamp(400.0, 550.0);
    final dialogHeight = isMobile ? size.height * 0.85 : size.height * 0.75;
    final membershipDefs =
        ref.watch(activeMembershipTypeDefinitionsProvider).valueOrNull ?? [];
    final canAddCustomer =
        ref.watchResolvedPermissions().can(PermissionIds.navCustomers);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 16 : 40,
      ),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            CustomerDialogHeader(
              title: 'Select Customer',
              subtitle: '${_allCustomers.length} customers available',
              icon: Icons.person_search_rounded,
              onClose: () => Navigator.of(context).pop(null),
              isMobile: isMobile,
            ),
            CustomerSearchBar(
              onChanged: _filterCustomers,
              autofocus: !isMobile,
              value: _searchQuery,
              onClear: () => _filterCustomers(''),
              isMobile: isMobile,
            ),
            Expanded(child: _buildContent(theme, isMobile, membershipDefs)),
            CustomerDialogFooter(
              onAdd: _addNewCustomer,
              onCancel: () => Navigator.of(context).pop(null),
              isMobile: isMobile,
              showAddButton: canAddCustomer,
            ),
          ],
        ),
      ),
    );
  }

  /// Firestore fallback section - shows recently ADDED customers
  Widget _buildFirestoreRecentSection(
    ThemeData theme,
    bool isMobile,
    List<MembershipTypeDefinition> membershipDefs,
  ) {
    final recentAsync = ref.watch(recentlyAddedCustomersProvider);

    return recentAsync.when(
      data: (customers) {
        if (customers.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final displayCustomers = customers.take(5).toList(); // Show top 5
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: CustomerSectionHeader(
                title: 'Recently Added',
                icon: Icons.person_add_rounded,
                padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 12, 16, 8),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => AnimatedListItem(
                    index: index,
                    child: CustomerTileCard(
                      customer: displayCustomers[index],
                      membershipDefinitions: membershipDefs,
                      onTap: () => _selectCustomer(displayCustomers[index]),
                    ),
                  ),
                  childCount: displayCustomers.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    bool isMobile,
    List<MembershipTypeDefinition> membershipDefs,
  ) {
    if (_isLoading && _recentCustomers.isEmpty && !_useFirestoreFallback) {
      return const CustomerListSkeleton();
    }

    return CustomScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      slivers: [
        // Recent customers section - from local storage
        if (_showRecent && _recentCustomers.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: CustomerSectionHeader(
              title: 'Recently Used',
              icon: Icons.history_rounded,
              padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 12, 16, 8),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => AnimatedListItem(
                  index: index,
                  child: RecentCustomerTileCard(
                    data: _recentCustomers[index],
                    onTap: () => _selectRecentCustomer(_recentCustomers[index]),
                  ),
                ),
                childCount: _recentCustomers.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],

        // Firestore fallback - show recently added customers (for web)
        if (_showRecent && _useFirestoreFallback) ...[
          _buildFirestoreRecentSection(theme, isMobile, membershipDefs),
        ],

        // All/Filtered customers
        SliverToBoxAdapter(
          child: CustomerSectionHeader(
            title: _searchQuery.isEmpty ? 'All Customers' : 'Search Results',
            icon: _searchQuery.isEmpty
                ? Icons.people_outline_rounded
                : Icons.search_rounded,
            padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 12, 16, 8),
          ),
        ),

        if (_isLoading)
          const SliverToBoxAdapter(child: CustomerListSkeleton())
        else if (_filteredCustomers.isEmpty)
          SliverFillRemaining(
            child: CustomerEmptyState(
              title: _searchQuery.isEmpty
                  ? 'No customers found'
                  : 'No results for "$_searchQuery"',
              subtitle: 'Try a different search or add a new customer',
              onAddPressed: _addNewCustomer,
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => AnimatedListItem(
                  index: index,
                  child: CustomerTileCard(
                    customer: _filteredCustomers[index],
                    membershipDefinitions: membershipDefs,
                    onTap: () => _selectCustomer(_filteredCustomers[index]),
                  ),
                ),
                childCount: _filteredCustomers.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
