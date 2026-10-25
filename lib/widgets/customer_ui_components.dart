import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer.dart';
import '../models/membership_type_definition.dart';
import '../services/recent_customers_service.dart';
import 'shimmer_skeleton.dart';
import 'glass_panel.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

// =============================================================================
// CUSTOMER CACHE MANAGER
// =============================================================================

/// Centralized cache manager for customer data across the app.
/// Eliminates duplicate cache logic in CustomerSelectionDialog,
/// PlayersSelectionDialog, and EnhancedCustomerSearchDelegate.
class CustomerCacheManager {
  CustomerCacheManager._();

  static List<Customer>? _cache;
  static DateTime? _cacheTime;
  static const Duration _cacheValidity = Duration(minutes: 3);

  /// Check if cache is still valid
  static bool get isCacheValid {
    if (_cache == null || _cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!) < _cacheValidity;
  }

  /// Get cached customers or null if cache is invalid
  static List<Customer>? get cachedCustomers => isCacheValid ? _cache : null;

  /// Update the cache with new data
  static void updateCache(List<Customer> customers) {
    _cache = customers;
    _cacheTime = DateTime.now();
  }

  /// Clear the cache (call when customers are updated externally)
  static void clearCache() {
    _cache = null;
    _cacheTime = null;
  }

  /// Fetch all customers with caching
  static Future<List<Customer>> fetchAllCustomers(
    CollectionReference<Map<String, dynamic>> customersRef, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && isCacheValid && _cache != null) {
      return _cache!;
    }

    final snapshot = await customersRef.orderBy('name').get();
    final customerList = snapshot.docs
        .map((doc) => Customer.fromFirestore(doc))
        .toList();
    updateCache(customerList);
    return customerList;
  }

  /// Filter customers by search query with relevance sorting
  static List<Customer> filterCustomers(
    List<Customer> customers,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return customers;

    final filtered = customers.where((customer) {
      final nameMatches = customer.name.toLowerCase().contains(normalizedQuery);
      final phoneMatches = customer.phoneNumber.contains(query);
      final membershipMatches =
          customer.membershipId?.toLowerCase().contains(normalizedQuery) ??
          false;
      return nameMatches || phoneMatches || membershipMatches;
    }).toList();

    // Sort by relevance
    filtered.sort((a, b) {
      final aNameLower = a.name.toLowerCase();
      final bNameLower = b.name.toLowerCase();

      // Exact match priority
      if (aNameLower == normalizedQuery) return -1;
      if (bNameLower == normalizedQuery) return 1;

      // Starts-with priority
      final aStartsWith = aNameLower.startsWith(normalizedQuery);
      final bStartsWith = bNameLower.startsWith(normalizedQuery);
      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;

      return aNameLower.compareTo(bNameLower);
    });

    return filtered;
  }
}

// =============================================================================
// CUSTOMER UI WIDGETS
// =============================================================================

/// Builds a customer avatar with initials
class CustomerAvatar extends StatelessWidget {
  final String name;
  final Color? backgroundColor;
  final double size;
  final double borderRadius;
  final bool isCircle;

  const CustomerAvatar({
    super.key,
    required this.name,
    this.backgroundColor,
    this.size = 40,
    this.borderRadius = 10,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.primaryContainer;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Membership type badge with color coding
class MembershipBadge extends StatelessWidget {
  final String membershipTypeId;
  final List<MembershipTypeDefinition> definitions;
  final bool compact;

  const MembershipBadge({
    super.key,
    required this.membershipTypeId,
    this.definitions = const [],
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    if (membershipIsRegular(membershipTypeId, definitions)) {
      return const SizedBox.shrink();
    }

    final def = lookupMembershipType(definitions, membershipTypeId);
    final badgeColor = def?.color ?? const Color(0xFFCD7F32);
    final label = membershipDisplayName(membershipTypeId, definitions);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 8 : 10,
          fontWeight: FontWeight.bold,
          color: badgeColor.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

/// Credits display chip with color coding
class CreditsChip extends StatelessWidget {
  final double credits;
  final bool compact;

  const CreditsChip({super.key, required this.credits, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = credits > 0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: isPositive
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '₹${credits.toStringAsFixed(0)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: compact ? 11 : 12,
          color: isPositive
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
      ),
    );
  }
}

/// Animated list item wrapper with staggered entrance
class AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final int baseDelayMs;
  final int incrementMs;
  final double offsetY;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDelayMs = 150,
    this.incrementMs = 30,
    this.offsetY = 15,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(
        milliseconds: baseDelayMs + (index * incrementMs).clamp(0, 300),
      ),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, offsetY * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}

/// Section header for customer lists
class CustomerSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final EdgeInsetsGeometry? padding;

  const CustomerSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading skeletons for customer lists
class CustomerListSkeleton extends StatelessWidget {
  final int count;
  final double itemHeight;
  final double borderRadius;

  const CustomerListSkeleton({
    super.key,
    this.count = 4,
    this.itemHeight = 64,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          count,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ShimmerSkeleton(
              height: itemHeight,
              borderRadius: borderRadius,
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget for customer lists
class CustomerEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onAddPressed;
  final String? addButtonText;

  const CustomerEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.person_search_rounded,
    this.onAddPressed,
    this.addButtonText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (onAddPressed != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: Text(addButtonText ?? 'Add Customer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard customer tile card for selection dialogs
class CustomerTileCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showMembership;
  final bool showCredits;
  final Widget? trailing;
  final List<MembershipTypeDefinition> membershipDefinitions;

  const CustomerTileCard({
    super.key,
    required this.customer,
    this.onTap,
    this.isSelected = false,
    this.showMembership = true,
    this.showCredits = true,
    this.trailing,
    this.membershipDefinitions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurface(
      margin: const EdgeInsets.only(bottom: 6),
      borderRadius: 12,
      borderColor: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.outline.withValues(alpha: 0.1),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CustomerAvatar(
                  name: customer.name,
                  backgroundColor: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              customer.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showMembership)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: MembershipBadge(
                                membershipTypeId: customer.membershipTypeId,
                                definitions: membershipDefinitions,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        customer.phoneNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      if (customer.membershipId != null)
                        Text(
                          'ID: ${customer.membershipId}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (showCredits)
                  CreditsChip(credits: customer.credits),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recent customer tile card for selection dialogs
class RecentCustomerTileCard extends StatelessWidget {
  final RecentCustomerData data;
  final VoidCallback? onTap;
  final bool isSelected;

  const RecentCustomerTileCard({
    super.key,
    required this.data,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurface(
      margin: const EdgeInsets.only(bottom: 6),
      borderRadius: 12,
      borderColor: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.outline.withValues(alpha: 0.1),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CustomerAvatar(
                  name: data.name,
                  backgroundColor: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        data.phoneNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CreditsChip(credits: data.credits),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog header with icon, title, subtitle, and close button
class CustomerDialogHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onClose;
  final bool isMobile;

  const CustomerDialogHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onClose,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.primary,
              size: isMobile ? 22 : 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 18 : 20,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose,
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
  }
}

/// Search bar for customer dialogs
class CustomerSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool autofocus;
  final String? value;
  final VoidCallback? onClear;
  final bool isMobile;

  const CustomerSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Search by name, phone, or ID...',
    this.autofocus = false,
    this.value,
    this.onClear,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 12,
      ),
      child: TextField(
        autofocus: autofocus,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          suffixIcon: (value?.isNotEmpty ?? false) && onClear != null
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

/// Footer with add and cancel buttons
class CustomerDialogFooter extends StatelessWidget {
  final VoidCallback? onAdd;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final String? confirmText;
  final bool canConfirm;
  final bool isMobile;
  final bool showAddButton;

  const CustomerDialogFooter({
    super.key,
    this.onAdd,
    required this.onCancel,
    this.onConfirm,
    this.confirmText,
    this.canConfirm = true,
    this.isMobile = false,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          if (showAddButton && onAdd != null) ...[
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                onAdd!();
              },
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text(isMobile ? 'Add' : 'Add Customer'),
            ),
            const Spacer(),
          ] else
            const Spacer(),
          TextButton(onPressed: onCancel, child: const Text(AppStrings.cancel)),
          if (onConfirm != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: canConfirm ? onConfirm : null,
              child: Text(confirmText ?? AppStrings.confirm),
            ),
          ],
        ],
      ),
    );
  }
}
