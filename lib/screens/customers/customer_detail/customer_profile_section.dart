import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/customer.dart';
import '../../../models/membership_type_definition.dart'
    show MembershipTypeDefinition, membershipDisplayName;
import '../../../providers/ledger_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/key_value_text.dart';

/// Profile header, contact, membership IDs, and membership/credits summary.
class CustomerProfileSection extends ConsumerWidget {
  const CustomerProfileSection({
    super.key,
    required this.customer,
    required this.canSeeCreditCode,
    required this.membershipDefs,
  });

  final Customer customer;
  final bool canSeeCreditCode;
  final List<MembershipTypeDefinition> membershipDefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final hasAlert =
        customer.hasLowCreditAlert || customer.hasMembershipExpiryAlert;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.1),
                theme.colorScheme.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: hasAlert
                ? Border.all(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.6),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: isMobile ? 28 : 36,
                  backgroundColor: theme.colorScheme.surface,
                  child: Text(
                    customer.name.isNotEmpty
                        ? customer.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customer.name,
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasAlert) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: theme.colorScheme.onTertiaryContainer,
                              size: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Joined ${DateFormat.yMMMd().format(customer.createdAt)}',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 16 : 24),
        SectionCard(
          title: 'Contact Information',
          icon: Icons.contact_phone_rounded,
          child: Column(
            children: [
              KeyValueText(
                icon: Icons.phone_rounded,
                title: 'Phone',
                value: customer.phoneNumber,
              ),
              if (customer.email != null && customer.email!.isNotEmpty)
                KeyValueText(
                  icon: Icons.email_rounded,
                  title: 'Email',
                  value: customer.email!,
                ),
              if (customer.pincode != null && customer.pincode!.isNotEmpty)
                KeyValueText(
                  icon: Icons.location_on_rounded,
                  title: 'Pincode',
                  value: customer.pincode!,
                ),
              if (canSeeCreditCode && customer.creditCode.isNotEmpty)
                KeyValueText(
                  icon: Icons.password_rounded,
                  title: 'Credit Code',
                  value: customer.creditCode,
                ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        if (customer.membershipHistory.isNotEmpty)
          SectionCard(
            title: 'Membership IDs',
            icon: Icons.badge_rounded,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: customer.membershipHistory.map((m) {
                final bool active = m.active;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (active)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.check_circle,
                            size: 14,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      Text(
                        m.id,
                        style: TextStyle(
                          decoration: active
                              ? null
                              : TextDecoration.lineThrough,
                          color: active
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        SizedBox(height: isMobile ? 12 : 16),
        SectionCard(
          title: 'Membership & Credits',
          icon: Icons.credit_card_rounded,
          child: Column(
            children: [
              KeyValueText(
                icon: Icons.card_membership_rounded,
                title: 'Plan',
                value: membershipDisplayName(
                  customer.membershipTypeId,
                  membershipDefs,
                ),
              ),
              if (customer.membershipExpiry != null)
                KeyValueText(
                  icon: Icons.calendar_today_rounded,
                  title: 'Expires',
                  value: DateFormat.yMMMd().format(customer.membershipExpiry!),
                  valueStyle: customer.hasMembershipExpiryAlert
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
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
                      return KeyValueText(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Credits',
                        value: '₹${balance.toStringAsFixed(0)}',
                        valueStyle: TextStyle(
                          color: balance < 500
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                    loading: () => KeyValueText(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Credits',
                      value: '₹${customer.credits.toStringAsFixed(0)}',
                      valueStyle: TextStyle(
                        color: customer.hasLowCreditAlert
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                    ),
                    error: (e, s) => KeyValueText(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Credits',
                      value: '₹${customer.credits.toStringAsFixed(0)}',
                      valueStyle: TextStyle(
                        color: customer.hasLowCreditAlert
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
              if (customer.lastCreditTopUpDate.millisecondsSinceEpoch != 0)
                KeyValueText(
                  icon: Icons.history_rounded,
                  title: 'Last Top-Up',
                  value:
                      '₹${customer.lastCreditTopUpAmount.toStringAsFixed(0)} on ${DateFormat.yMMMd().format(customer.lastCreditTopUpDate)}',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
