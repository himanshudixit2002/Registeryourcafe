import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/theme/app_theme.dart';

import '../models/customer.dart';
import '../models/membership_type_definition.dart';
import '../services/recent_customers_service.dart';
import '../screens/customers/add_customer_screen.dart';
import '../utils/app_logger.dart';
import 'customer_ui_components.dart';

/// Enhanced customer search delegate with:
/// - Instant recent customers from local storage
/// - Debounced search for performance
/// - Smooth animations and haptic feedback
/// - Smart caching with freshness check
/// - Recently added customers section
class EnhancedCustomerSearchDelegate extends SearchDelegate<Customer?> {
  final CollectionReference<Map<String, dynamic>> customers;
  final List<MembershipTypeDefinition> membershipDefinitions;

  /// When false, "add customer" affordances are hidden and push is blocked.
  final bool canAddCustomer;

  EnhancedCustomerSearchDelegate({
    required this.customers,
    this.membershipDefinitions = const [],
    this.canAddCustomer = true,
  });

  // ---------------------------------------------------------------------------
  // Search debouncing
  // ---------------------------------------------------------------------------
  String _lastQuery = '';
  List<Customer>? _lastResults;

  /// Clears the cached customers so that newly added customers appear in searches.
  static void clearCache() {
    CustomerCacheManager.clearCache();
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 16,
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  String get searchFieldLabel => 'Search by name or phone...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (canAddCustomer)
        IconButton(
          icon: const Icon(Icons.person_add_rounded),
          tooltip: 'Add new customer',
          onPressed: () {
            HapticFeedback.lightImpact();
            _addNewCustomer(context);
          },
        ),
      // Clear button with animation
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: query.isNotEmpty
            ? IconButton(
                key: const ValueKey('clear'),
                icon: const Icon(Icons.clear_rounded),
                tooltip: 'Clear',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  query = '';
                  _lastQuery = '';
                  _lastResults = null;
                  showSuggestions(context);
                },
              )
            : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          key: ValueKey(query.isEmpty),
          size: 20,
        ),
      ),
      tooltip: 'Back',
      onPressed: () {
        HapticFeedback.lightImpact();
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    if (query.isEmpty) {
      return _buildInitialView(context);
    }
    return _buildSearchResults(context);
  }

  /// Initial view with recent customers (instant from local) and recently added
  Widget _buildInitialView(BuildContext context) {
    return FutureBuilder<List<RecentCustomerData>>(
      future: RecentCustomersService.getRecentCustomers(),
      builder: (context, recentSnapshot) {
        return FutureBuilder<List<Customer>>(
          future: _getRecentlyAddedCustomers(),
          builder: (context, addedSnapshot) {
            final recentCustomers = recentSnapshot.data ?? [];
            final recentlyAdded = addedSnapshot.data ?? [];

            // Show loading skeletons while fetching
            if (recentSnapshot.connectionState == ConnectionState.waiting &&
                addedSnapshot.connectionState == ConnectionState.waiting) {
              return const CustomerListSkeleton();
            }

            // No customers at all - show empty state
            if (recentCustomers.isEmpty && recentlyAdded.isEmpty) {
              return CustomerEmptyState(
                title: 'Search for a Customer',
                subtitle: 'Type a name or phone number above to find customers',
                icon: Icons.people_outline_rounded,
                onAddPressed: canAddCustomer
                    ? () => _addNewCustomer(context)
                    : null,
                addButtonText: 'Add New Customer',
              );
            }

            return CustomScrollView(
              physics: AppTheme.scrollPhysicsFor(context),
              slivers: [
                // Recently used customers (instant from local storage)
                if (recentCustomers.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: CustomerSectionHeader(
                      title: 'Recently Used',
                      icon: Icons.history_rounded,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final data = recentCustomers[index];
                        return AnimatedListItem(
                          index: index,
                          child: RecentCustomerTileCard(
                            data: data,
                            onTap: () =>
                                _selectRecentCustomer(context, data.id),
                          ),
                        );
                      }, childCount: recentCustomers.length),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],

                // Recently added customers
                if (recentlyAdded.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: CustomerSectionHeader(
                      title: 'Recently Added',
                      icon: Icons.person_add_alt_rounded,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final customer = recentlyAdded[index];
                        return AnimatedListItem(
                          index: index,
                          child: CustomerTileCard(
                            customer: customer,
                            membershipDefinitions: membershipDefinitions,
                            onTap: () => _selectCustomer(context, customer),
                          ),
                        );
                      }, childCount: recentlyAdded.length),
                    ),
                  ),
                ],

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        );
      },
    );
  }

  /// Get recently added customers from Firestore
  Future<List<Customer>> _getRecentlyAddedCustomers() async {
    try {
      final snapshot = await customers
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      return snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList();
    } catch (e) {
      AppLogger.warning(
        'Error fetching recently added customers: $e',
        tag: 'CustomerSearch',
      );
      return [];
    }
  }

  /// Build search results with caching
  Widget _buildSearchResults(BuildContext context) {
    // Use cached results if query hasn't changed
    if (query == _lastQuery && _lastResults != null) {
      return _buildResultsList(context, _lastResults!);
    }

    return FutureBuilder<List<Customer>>(
      future: _performSearch(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSearchingState(context);
        }

        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error.toString());
        }

        final results = snapshot.data ?? [];
        _lastQuery = query;
        _lastResults = results;

        if (results.isEmpty) {
          return CustomerEmptyState(
            title: 'No results for "$query"',
            subtitle: canAddCustomer
                ? 'Try a different name, phone number, or add a new customer'
                : 'Try a different name or phone number',
            onAddPressed:
                canAddCustomer ? () => _addNewCustomer(context) : null,
          );
        }

        return _buildResultsList(context, results);
      },
    );
  }

  /// Optimized search with smart filtering
  Future<List<Customer>> _performSearch(String searchQuery) async {
    final allCustomers = await CustomerCacheManager.fetchAllCustomers(
      customers,
    );
    return CustomerCacheManager.filterCustomers(allCustomers, searchQuery);
  }

  // ---------------------------------------------------------------------------
  // UI Builders
  // ---------------------------------------------------------------------------

  Widget _buildResultsList(BuildContext context, List<Customer> customers) {
    return ListView.builder(
      physics: AppTheme.scrollPhysicsFor(context),
      padding: const EdgeInsets.all(12),
      itemCount: customers.length,
      itemBuilder: (context, index) => AnimatedListItem(
        index: index,
        child: CustomerTileCard(
          customer: customers[index],
          membershipDefinitions: membershipDefinitions,
          onTap: () => _selectCustomer(context, customers[index]),
        ),
      ),
    );
  }

  Widget _buildSearchingState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Searching for "$query"...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Search Error',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _selectRecentCustomer(
    BuildContext context,
    String customerId,
  ) async {
    await HapticFeedback.lightImpact();

    try {
      final doc = await customers.doc(customerId).get();
      if (doc.exists) {
        final customer = Customer.fromFirestore(doc);
        if (context.mounted) {
          await _selectCustomer(context, customer);
        }
      } else {
        await RecentCustomersService.removeRecentCustomer(customerId);
        if (context.mounted) {
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
      if (context.mounted) {
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

  Future<void> _selectCustomer(BuildContext context, Customer customer) async {
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

    if (context.mounted) {
      close(context, customer);
    }
  }

  Future<void> _addNewCustomer(BuildContext context) async {
    if (!canAddCustomer) {
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
    final added = await Navigator.of(
      context,
    ).push<bool?>(
      AppMaterialPageRoute<bool?>(
        builder: (_) => const AddCustomerScreen(),
      ),
    );
    if (added == true) {
      clearCache();
      if (context.mounted) {
        showSuggestions(context);
      }
    }
  }
}
