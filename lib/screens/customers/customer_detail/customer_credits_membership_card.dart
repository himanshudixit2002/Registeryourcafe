import 'package:flutter/material.dart';

import '../../../models/customer.dart';
import '../../../models/membership_type_definition.dart'
    show MembershipTypeDefinition, lookupMembershipType;
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_panel.dart';
import '../../../widgets/mobile_plan_selector.dart' as mps;

IconData _paymentMethodIcon(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return Icons.payments_outlined;
    case PaymentMethod.upi:
      return Icons.phone_android_rounded;
    case PaymentMethod.credits:
      return Icons.account_balance_wallet_outlined;
  }
}

typedef CustomerUpdateMembershipFn = Future<void> Function(
  BuildContext context,
  ThemeData theme,
  Customer customer,
  MembershipTypeDefinition newPlan,
  PaymentMethod? paymentMethod,
);

typedef CustomerManualCreditsFn = Future<void> Function(
  Customer customer,
  double amount,
  PaymentMethod method,
);

/// Plan selection, payment method, and confirm for credits / membership changes.
class CustomerCreditsMembershipCard extends StatefulWidget {
  const CustomerCreditsMembershipCard({
    super.key,
    required this.customer,
    required this.membershipDefs,
    this.canEdit = true,
    required this.onUpdateMembership,
    required this.onAddCreditsManual,
  });

  final Customer customer;
  final List<MembershipTypeDefinition> membershipDefs;
  final bool canEdit;
  final CustomerUpdateMembershipFn onUpdateMembership;
  final CustomerManualCreditsFn onAddCreditsManual;

  @override
  State<CustomerCreditsMembershipCard> createState() =>
      _CustomerCreditsMembershipCardState();
}

class _CustomerCreditsMembershipCardState
    extends State<CustomerCreditsMembershipCard> {
  late final TextEditingController _amountController;
  String? _selectedPlanId;
  PaymentMethod? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    if (!widget.canEdit) {
      return AppSurface(
        borderRadius: isMobile ? 16 : 12,
        padding: EdgeInsets.all(isMobile ? 14 : AppTheme.kSpacingMedium),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: theme.colorScheme.primary,
                size: isMobile ? 22 : 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credits',
                    style: TextStyle(
                      fontSize: isMobile ? 17 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.customer.credits.toStringAsFixed(0)} available',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final paidPlans =
        widget.membershipDefs.where((d) => !d.isArchived && !d.isRegular).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final planOptions = <mps.PlanOption<String?>>[
      mps.PlanOption<String?>(
        value: null,
        title: 'Quick Top-up',
        subtitle: 'Add credits without membership',
        icon: Icons.add_card_rounded,
        color: theme.colorScheme.outline,
        details: const ['Custom amount', 'No benefits'],
      ),
      ...paidPlans.map(
        (d) => mps.PlanOption<String?>(
          value: d.id,
          title: d.name,
          subtitle: '₹${d.fee} → ${d.creditsToAdd} credits',
          price: '₹${d.fee}',
          priceSubtitle: d.fee > 0
              ? '+${d.bonusPercentage.toStringAsFixed(0)}% bonus credits'
              : null,
          icon: Icons.workspace_premium_rounded,
          color: d.color,
          details: [
            if (d.discountPercentage > 0)
              '${d.discountPercentage.toStringAsFixed(0)}% table discount',
            '${d.creditsToAdd} credits',
          ],
        ),
      ),
    ];

    return AppSurface(
      borderRadius: isMobile ? 16 : 12,
      padding: EdgeInsets.all(isMobile ? 14 : AppTheme.kSpacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.2),
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.credit_card_rounded,
                  color: theme.colorScheme.primary,
                  size: isMobile ? 22 : 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Credits',
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Choose a plan or add custom amount',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : AppTheme.kSpacingMedium),
          mps.MobilePlanSelector<String?>(
            options: planOptions,
            selectedValue: _selectedPlanId,
            onChanged: (val) => setState(() => _selectedPlanId = val),
            showCompactView: !isMobile,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _selectedPlanId == null
                ? Padding(
                    padding: EdgeInsets.only(top: isMobile ? 14 : 16),
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: isMobile ? 16 : 15),
                      decoration: AppTheme.inputDecoration(
                        theme,
                        'Enter Amount',
                        Icons.currency_rupee_rounded,
                      ).copyWith(
                        hintText: 'Amount less than ₹500',
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: isMobile ? 16 : AppTheme.kSpacingMedium),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.22),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Builder(
              builder: (ctx) {
                final paymentItems = PaymentMethod.values
                    .where((m) => m != PaymentMethod.credits)
                    .map(
                      (method) => DropdownMenuItem<PaymentMethod>(
                        value: method,
                        child: Row(
                          children: [
                            Icon(
                              _paymentMethodIcon(method),
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Text(method.name.toUpperCase()),
                          ],
                        ),
                      ),
                    )
                    .toList();
                return DropdownButtonFormField<PaymentMethod>(
                  initialValue: _selectedPaymentMethod,
                  isExpanded: true,
                  items: paymentItems,
                  selectedItemBuilder: (context) =>
                      AppTheme.dropdownSelectedItemBuilders(
                        theme,
                        paymentItems,
                      ),
                  onChanged: (val) =>
                      setState(() => _selectedPaymentMethod = val),
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: isMobile ? 12 : 10,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: isMobile ? 20 : AppTheme.kSpacingLarge),
          SizedBox(
            width: double.infinity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _selectedPlanId == null
                      ? 'Add Credits'
                      : 'Confirm Membership',
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 16 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (_selectedPlanId == null) {
                    final amt = double.tryParse(_amountController.text);
                    if (amt == null || amt <= 0 || amt >= 500) {
                      final cs = theme.colorScheme;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: cs.errorContainer,
                          content: Text(
                            'Enter amount between 1 and 499',
                            style: TextStyle(color: cs.onErrorContainer),
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      return;
                    }
                    await widget.onAddCreditsManual(
                      widget.customer,
                      amt,
                      _selectedPaymentMethod ?? PaymentMethod.cash,
                    );
                  } else {
                    final def = lookupMembershipType(
                      widget.membershipDefs,
                      _selectedPlanId!,
                    );
                    if (def == null || def.isRegular) return;
                    await widget.onUpdateMembership(
                      context,
                      theme,
                      widget.customer,
                      def,
                      _selectedPaymentMethod,
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
