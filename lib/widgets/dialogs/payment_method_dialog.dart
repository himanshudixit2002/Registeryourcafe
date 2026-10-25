import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/customer.dart';
import '../../models/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_modal_bottom_sheet.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class PaymentSelectionResult {
  final PaymentMethod? method;
  final Map<String, double>? breakdown;
  final bool attachToSession;

  const PaymentSelectionResult({
    this.method,
    this.breakdown,
    this.attachToSession = false,
  });

  bool get isCredits => method == PaymentMethod.credits;
  bool get isCancelled =>
      method == null && breakdown == null && !attachToSession;
}

/// Enhanced payment method dialog with:
/// - Bottom sheet on mobile for better UX
/// - Large touch targets
/// - Haptic feedback
/// - Smooth animations
class PaymentMethodDialog extends StatelessWidget {
  final double? totalAmount;
  final TableSession? session;
  final Customer? customer;
  final bool hasActiveSession;
  final String? sessionTableName;

  /// When set (e.g. table checkout after %-discounts), used for header total and
  /// credit sufficiency instead of [session.calculateTotalBillAmount].
  final double? payableAfterDiscounts;

  const PaymentMethodDialog({
    super.key,
    this.totalAmount,
    this.session,
    this.customer,
    this.hasActiveSession = false,
    this.sessionTableName,
    this.payableAfterDiscounts,
  }) : assert(
         totalAmount != null || session != null,
         'Either totalAmount or session must be provided',
       );

  double get effectiveTotal {
    if (payableAfterDiscounts != null) return payableAfterDiscounts!;
    if (totalAmount != null) return totalAmount!;
    if (session != null) {
      // Active session: [totalBillAmount] is only a running sum of attached orders;
      // completed session: it is final payable after checkout.
      if (session!.status == SessionStatus.active) {
        return session!.calculateTotalBillAmount();
      }
      return session!.totalBillAmount ?? session!.calculateTotalBillAmount();
    }
    return 0.0;
  }

  static Future<PaymentSelectionResult?> show(
    BuildContext context, {
    double? totalAmount,
    TableSession? session,
    Customer? customer,
    bool hasActiveSession = false,
    String? sessionTableName,
    double? payableAfterDiscounts,
  }) async {
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    // If has active session, show attach option first
    if (hasActiveSession && session == null) {
      final choice = await _showAttachSessionSheet(
        context,
        customer,
        sessionTableName,
        isMobile,
      );

      if (choice == 'attach') {
        return const PaymentSelectionResult(attachToSession: true);
      } else if (choice != 'pay') {
        return null;
      }
      if (!context.mounted) return null;
    }

    // Show payment method selection
    if (isMobile) {
      return _showMobilePaymentSheet(
        context,
        totalAmount: totalAmount,
        session: session,
        customer: customer,
        payableAfterDiscounts: payableAfterDiscounts,
      );
    } else {
      return showDialog<PaymentSelectionResult>(
        context: context,
        builder: (context) => PaymentMethodDialog(
          totalAmount: totalAmount,
          session: session,
          customer: customer,
          hasActiveSession: hasActiveSession,
          sessionTableName: sessionTableName,
          payableAfterDiscounts: payableAfterDiscounts,
        ),
      );
    }
  }

  static Future<String?> _showAttachSessionSheet(
    BuildContext context,
    Customer? customer,
    String? sessionTableName,
    bool isMobile,
  ) {
    final theme = Theme.of(context);

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sem = AppSemanticColors.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: GlassModalSheetChrome(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer?.name ?? 'Customer',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Active on ${sessionTableName ?? 'Table'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Options
                  _PaymentOptionCard(
                    icon: Icons.link_rounded,
                    iconColor: sem.info,
                    title: 'Add to Session',
                    subtitle: 'Bill will be added to the active session',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(ctx, 'attach');
                    },
                  ),
                  const SizedBox(height: 12),
                  _PaymentOptionCard(
                    icon: Icons.payments_outlined,
                    iconColor: sem.success,
                    title: 'Pay Separately',
                    subtitle: 'Complete this payment now',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(ctx, 'pay');
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<PaymentSelectionResult?> _showMobilePaymentSheet(
    BuildContext context, {
    double? totalAmount,
    TableSession? session,
    Customer? customer,
    double? payableAfterDiscounts,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final total = payableAfterDiscounts ??
        totalAmount ??
        session?.calculateTotalBillAmount() ??
        0.0;
    final canPayWithCredits = customer != null && customer.credits >= total;

    return showModalBottomSheet<PaymentSelectionResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: GlassModalSheetChrome(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with total
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: theme.colorScheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Payment',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (total > 0)
                            Text(
                              'Total: ₹${total.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Payment Options
                _PaymentOptionCard(
                  icon: Icons.payments_rounded,
                  iconColor: sem.success,
                  title: 'Cash',
                  subtitle: 'Pay with physical currency',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(
                      ctx,
                      PaymentSelectionResult(method: PaymentMethod.cash),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _PaymentOptionCard(
                  icon: Icons.phone_android_rounded,
                  iconColor: sem.info,
                  title: 'UPI',
                  subtitle: 'GPay, PhonePe, Paytm, etc.',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(
                      ctx,
                      PaymentSelectionResult(method: PaymentMethod.upi),
                    );
                  },
                ),
                if (customer != null) ...[
                  const SizedBox(height: 12),
                  _PaymentOptionCard(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: canPayWithCredits
                        ? sem.warning
                        : cs.onSurfaceVariant,
                    title: 'Credits',
                    subtitle:
                        'Balance: ₹${customer.credits.toStringAsFixed(2)}',
                    enabled: canPayWithCredits,
                    onTap: canPayWithCredits
                        ? () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(
                              ctx,
                              PaymentSelectionResult(
                                method: PaymentMethod.credits,
                              ),
                            );
                          }
                        : null,
                    trailing: !canPayWithCredits
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Insufficient',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.error,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
                const SizedBox(height: 20),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(AppStrings.cancel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final total = effectiveTotal;
    final canPayWithCredits = customer != null && customer!.credits >= total;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.payment_rounded, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                'Select Payment',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total:', style: textTheme.bodyMedium),
                    const SizedBox(width: 8),
                    Text(
                      '₹${total.toStringAsFixed(2)}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PaymentOptionCard(
            icon: Icons.payments_rounded,
            iconColor: sem.success,
            title: 'Cash',
            subtitle: 'Physical currency',
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(
                context,
                PaymentSelectionResult(method: PaymentMethod.cash),
              );
            },
          ),
          const SizedBox(height: 10),
          _PaymentOptionCard(
            icon: Icons.phone_android_rounded,
            iconColor: sem.info,
            title: 'UPI',
            subtitle: 'Digital payment',
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(
                context,
                PaymentSelectionResult(method: PaymentMethod.upi),
              );
            },
          ),
          if (customer != null) ...[
            const SizedBox(height: 10),
            _PaymentOptionCard(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: canPayWithCredits
                  ? sem.warning
                  : colorScheme.onSurfaceVariant,
              title: 'Credits',
              subtitle: '₹${customer!.credits.toStringAsFixed(2)} available',
              enabled: canPayWithCredits,
              onTap: canPayWithCredits
                  ? () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(
                        context,
                        PaymentSelectionResult(method: PaymentMethod.credits),
                      );
                    }
                  : null,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppStrings.cancel,
            style: textTheme.labelLarge?.copyWith(color: colorScheme.secondary),
          ),
        ),
      ],
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? trailing;

  const _PaymentOptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: enabled
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: enabled ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? iconColor
                      : theme.colorScheme.onSurfaceVariant,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (enabled)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
