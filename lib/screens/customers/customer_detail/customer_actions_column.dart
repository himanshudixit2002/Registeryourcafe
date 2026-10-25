import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/customer.dart';
import '../../../models/membership_type_definition.dart';
import '../../../models/venue_kind.dart';
import '../../../models/venue_ui_config.dart';
import '../../../providers/company_module_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import 'customer_credit_transactions_section.dart';
import 'customer_credits_membership_card.dart';
import 'customer_games_leaderboard_section.dart';
import 'customer_loyalty_section.dart';

/// Right column (or below profile): games, loyalty, credits card, transaction history.
class CustomerActionsColumn extends ConsumerWidget {
  const CustomerActionsColumn({
    super.key,
    required this.customer,
    required this.membershipDefs,
    required this.canCustomersAdmin,
    required this.onUpdateMembership,
    required this.onAddCreditsManual,
    required this.onReconcileCredits,
  });

  final Customer customer;
  final List<MembershipTypeDefinition> membershipDefs;
  final bool canCustomersAdmin;
  final CustomerUpdateMembershipFn onUpdateMembership;
  final CustomerManualCreditsFn onAddCreditsManual;
  final ReconcileCreditsFn onReconcileCredits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(workspaceModuleVisibilityProvider);
    final venueKind = ref.watch(venueKindProvider);
    final showGames = venueKind == VenueKind.gamingCafe;
    final showLoyalty = modules.loyalty;

    return Column(
      children: [
        if (showGames) ...[
          CustomerGamesLeaderboardSection(customer: customer),
          const SizedBox(height: AppTheme.kSpacingMedium),
        ],
        if (venueKind.isDiningOrRestaurant) ...[
          _DiningGuestSummary(venueKind: venueKind),
          const SizedBox(height: AppTheme.kSpacingMedium),
        ],
        if (showLoyalty) ...[
          CustomerLoyaltySection(customer: customer),
          const SizedBox(height: AppTheme.kSpacingMedium),
        ],
        CustomerCreditsMembershipCard(
          customer: customer,
          membershipDefs: membershipDefs,
          canEdit: canCustomersAdmin,
          onUpdateMembership: onUpdateMembership,
          onAddCreditsManual: onAddCreditsManual,
        ),
        const SizedBox(height: AppTheme.kSpacingMedium),
        CustomerCreditTransactionsSection(
          customer: customer,
          canCustomersAdmin: canCustomersAdmin,
          onReconcileCredits: onReconcileCredits,
        ),
      ],
    );
  }
}

class _DiningGuestSummary extends StatelessWidget {
  final VenueKind venueKind;

  const _DiningGuestSummary({required this.venueKind});

  @override
  Widget build(BuildContext context) {
    final isRestaurant = venueKind == VenueKind.restaurantCafe;

    return SectionCard(
      title: isRestaurant ? 'Guest Preferences' : 'Visit Summary',
      icon: isRestaurant ? Icons.restaurant_menu : Icons.event_seat,
      child: Column(
        children: [
          _Row(icon: Icons.history, label: isRestaurant ? 'Reservation history' : 'Visit history', value: 'Available in bookings tab'),
          const SizedBox(height: 8),
          if (isRestaurant) ...[
            _Row(icon: Icons.no_food, label: 'Dietary preferences', value: 'Not set'),
            const SizedBox(height: 8),
            _Row(icon: Icons.star_outline, label: 'VIP status', value: 'Regular'),
          ] else ...[
            _Row(icon: Icons.restaurant, label: 'Favorite orders', value: 'Based on order history'),
            const SizedBox(height: 8),
            _Row(icon: Icons.event_seat_outlined, label: 'Preferred seating', value: 'No preference'),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
