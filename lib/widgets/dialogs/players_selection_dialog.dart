import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

import '../../auth/permission_id.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../screens/customers/add_customer_screen.dart';
import '../../theme/app_theme.dart';
import '../../services/recent_customers_service.dart';
import '../../utils/app_logger.dart';
import '../customer_ui_components.dart';
import '../glass_panel.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

/// Enhanced multi-player selection dialog with:
/// - Recent customers from local storage
/// - Smart caching for faster loads
/// - Multi-select with chips display
/// - Smooth animations
class PlayersSelectionDialog extends ConsumerStatefulWidget {
  final int requiredPlayers;
  final CollectionReference<Map<String, dynamic>> customers;

  const PlayersSelectionDialog({
    super.key,
    required this.requiredPlayers,
    required this.customers,
  });

  @override
  ConsumerState<PlayersSelectionDialog> createState() =>
      _PlayersSelectionDialogState();
}

class _PlayersSelectionDialogState
    extends ConsumerState<PlayersSelectionDialog> {
  String _searchQuery = '';
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  List<RecentCustomerData> _recentCustomers = [];
  final List<Customer> _selected = [];
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

    // Then load all customers
    await _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      _allCustomers = await CustomerCacheManager.fetchAllCustomers(
        widget.customers,
      );
      _filteredCustomers = _allCustomers;
    } catch (e, st) {
      AppLogger.error(
        '_fetchCustomers failed',
        tag: 'PlayersSelection',
        error: e,
        stackTrace: st,
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _filter(String q) {
    setState(() {
      _searchQuery = q;
      _showRecent = q.isEmpty;
      _filteredCustomers = CustomerCacheManager.filterCustomers(
        _allCustomers,
        q,
      );
    });
  }

  void _toggle(Customer c) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(c)) {
        _selected.remove(c);
      } else {
        if (_selected.length < widget.requiredPlayers) {
          _selected.add(c);
        }
      }
    });
  }

  Future<void> _selectFromRecent(RecentCustomerData data) async {
    await HapticFeedback.lightImpact();
    try {
      final doc = await widget.customers.doc(data.id).get();
      if (doc.exists) {
        final customer = Customer.fromFirestore(doc);
        _toggle(customer);
      } else {
        await RecentCustomersService.removeRecentCustomer(data.id);
        if (mounted) {
          setState(() {
            _recentCustomers.removeWhere((c) => c.id == data.id);
          });
        }
      }
    } catch (e, st) {
      AppLogger.error(
        '_selectFromRecent failed',
        tag: 'PlayersSelection',
        error: e,
        stackTrace: st,
      );
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
    final newCust = await Navigator.of(
      context,
    ).push<bool?>(
      AppMaterialPageRoute<bool?>(
        builder: (_) => const AddCustomerScreen(),
      ),
    );
    if (newCust == true) {
      CustomerCacheManager.clearCache();
      await _fetchCustomers();
    }
  }

  void _confirmSelection() {
    HapticFeedback.mediumImpact();
    // Record selected customers as recent
    for (final customer in _selected) {
      RecentCustomersService.recordRecentCustomer(
        RecentCustomerData(
          id: customer.id,
          name: customer.name,
          phoneNumber: customer.phoneNumber,
          membershipId: customer.membershipId,
          credits: customer.credits,
          lastUsed: DateTime.now(),
        ),
      );
    }
    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < AppTheme.kMobileBreakpoint;
    final canAddCustomer =
        ref.watchResolvedPermissions().can(PermissionIds.navCustomers);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical: isMobile ? 24 : 48,
      ),
      child: Container(
        width: isMobile ? size.width * 0.95 : 520,
        height: isMobile ? size.height * 0.85 : 650,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            CustomerDialogHeader(
              title:
                  'Select ${widget.requiredPlayers} Player${widget.requiredPlayers > 1 ? 's' : ''}',
              subtitle:
                  '${_selected.length}/${widget.requiredPlayers} selected',
              icon: Icons.people_rounded,
              onClose: () => Navigator.of(context).pop(),
              isMobile: isMobile,
            ),
            _buildSelectedChips(theme),
            CustomerSearchBar(
              onChanged: _filter,
              hintText: 'Search players...',
              value: _searchQuery,
              isMobile: isMobile,
            ),
            Expanded(child: _buildContent(theme, isMobile)),
            CustomerDialogFooter(
              onAdd: _addNewCustomer,
              onCancel: () => Navigator.pop(context),
              showAddButton: canAddCustomer,
              onConfirm: _confirmSelection,
              confirmText: _selected.length == widget.requiredPlayers
                  ? AppStrings.confirm
                  : 'Confirm (${_selected.length}/${widget.requiredPlayers})',
              canConfirm: _selected.length == widget.requiredPlayers,
              isMobile: isMobile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChips(ThemeData theme) {
    if (_selected.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _selected
            .map(
              (c) => Chip(
                avatar: CustomerAvatar(
                  name: c.name,
                  size: 24,
                  borderRadius: 12,
                  backgroundColor: theme.colorScheme.primary,
                ),
                label: Text(
                  c.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => _toggle(c),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isMobile) {
    if (_isLoading && _recentCustomers.isEmpty && !_useFirestoreFallback) {
      return const CustomerListSkeleton(itemHeight: 56, count: 4);
    }

    return CustomScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      slivers: [
        // Recent customers from local storage
        if (_showRecent && _recentCustomers.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: CustomerSectionHeader(
              title: 'Recent',
              icon: Icons.history_rounded,
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final data = _recentCustomers[index];
                final isAlreadySelected = _selected.any((c) => c.id == data.id);
                return AnimatedListItem(
                  index: index,
                  child: _buildRecentTile(theme, data, isAlreadySelected),
                );
              }, childCount: _recentCustomers.length),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],

        // Firestore fallback - show recently added customers (for web)
        if (_showRecent && _useFirestoreFallback) ...[
          _buildFirestoreRecentSection(theme),
        ],

        // All customers
        SliverToBoxAdapter(
          child: CustomerSectionHeader(
            title: _searchQuery.isEmpty ? 'All Players' : 'Results',
            icon: Icons.people_outline_rounded,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          ),
        ),

        if (_isLoading)
          const SliverToBoxAdapter(
            child: CustomerListSkeleton(itemHeight: 56, count: 4),
          )
        else if (_filteredCustomers.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No players found')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final customer = _filteredCustomers[index];
                final isSelected = _selected.contains(customer);
                return AnimatedListItem(
                  index: index,
                  child: _buildPlayerTile(theme, customer, isSelected),
                );
              }, childCount: _filteredCustomers.length),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  /// Firestore fallback section - shows recently ADDED customers
  Widget _buildFirestoreRecentSection(ThemeData theme) {
    final recentAsync = ref.watch(recentlyAddedCustomersProvider);

    return recentAsync.when(
      data: (customers) {
        if (customers.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final displayCustomers = customers.take(5).toList();
        return SliverMainAxisGroup(
          slivers: [
            const SliverToBoxAdapter(
              child: CustomerSectionHeader(
                title: 'Recently Added',
                icon: Icons.person_add_rounded,
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final customer = displayCustomers[index];
                  final isSelected = _selected.contains(customer);
                  return AnimatedListItem(
                    index: index,
                    child: _buildPlayerTile(theme, customer, isSelected),
                  );
                }, childCount: displayCustomers.length),
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

  Widget _buildRecentTile(
    ThemeData theme,
    RecentCustomerData data,
    bool isSelected,
  ) {
    return AppSurface(
      margin: const EdgeInsets.only(bottom: 4),
      borderRadius: 10,
      padding: EdgeInsets.zero,
      borderColor: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.outline.withValues(alpha: 0.1),
      child: ListTile(
        dense: true,
        leading: CustomerAvatar(
          name: data.name,
          size: 36,
          borderRadius: 18,
          backgroundColor: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.secondaryContainer,
        ),
        title: Text(
          data.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(data.phoneNumber, style: theme.textTheme.bodySmall),
        trailing: isSelected
            ? Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              )
            : Icon(
                Icons.add_circle_outline_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                size: 22,
              ),
        onTap: isSelected ? null : () => _selectFromRecent(data),
      ),
    );
  }

  Widget _buildPlayerTile(ThemeData theme, Customer customer, bool isSelected) {
    final canSelect = _selected.length < widget.requiredPlayers || isSelected;

    return AppSurface(
      margin: const EdgeInsets.only(bottom: 4),
      borderRadius: 10,
      padding: EdgeInsets.zero,
      borderColor: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.outline.withValues(alpha: 0.1),
      child: ListTile(
        dense: true,
        leading: CustomerAvatar(
          name: customer.name,
          size: 36,
          borderRadius: 18,
          backgroundColor: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.primaryContainer,
        ),
        title: Text(
          customer.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(customer.phoneNumber, style: theme.textTheme.bodySmall),
        trailing: isSelected
            ? Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              )
            : Icon(
                canSelect
                    ? Icons.add_circle_outline_rounded
                    : Icons.block_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                size: 22,
              ),
        onTap: canSelect ? () => _toggle(customer) : null,
      ),
    );
  }
}
