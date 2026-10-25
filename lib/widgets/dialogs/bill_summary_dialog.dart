import 'package:registeryourcafe/providers/cafe_order_provider.dart';
import 'package:registeryourcafe/providers/merchandise_order_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/session.dart';
import '../../models/customer.dart';
import '../../models/membership_type_definition.dart';
import '../../providers/membership_type_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/firestore_utils.dart';
import '../../utils/session_checkout_discounts.dart';
import '../../widgets/glass_panel.dart';

/// Returned when staff confirms the bill during active-session checkout.
class SessionCheckoutBillResult {
  /// Percent discounts for `endSession`: keys `membership`, `special`; `null` if none.
  final Map<String, double>? discounts;

  const SessionCheckoutBillResult({this.discounts});
}

/// Enhanced bill summary dialog with:
/// - Mobile-optimized bottom sheet
/// - Smooth animations
/// - Better visual hierarchy
/// - Large touch targets
class BillSummaryDialog extends ConsumerStatefulWidget {
  final TableSession session;
  final Customer customer;

  const BillSummaryDialog({
    super.key,
    required this.session,
    required this.customer,
  });

  /// Show the dialog - uses bottom sheet on mobile, dialog on desktop
  static Future<SessionCheckoutBillResult?> show(
    BuildContext context, {
    required TableSession session,
    required Customer customer,
  }) {
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    if (isMobile) {
      return showModalBottomSheet<SessionCheckoutBillResult?>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        enableDrag: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => _MobileBillSheet(
            session: session,
            customer: customer,
            scrollController: scrollController,
          ),
        ),
      );
    } else {
      return showDialog<SessionCheckoutBillResult?>(
        context: context,
        builder: (ctx) =>
            BillSummaryDialog(session: session, customer: customer),
      );
    }
  }

  @override
  ConsumerState<BillSummaryDialog> createState() => _BillSummaryDialogState();
}

class _BillSummaryDialogState extends ConsumerState<BillSummaryDialog> {
  late final TextEditingController _specialPctController;

  TableSession get session => widget.session;
  Customer get customer => widget.customer;

  @override
  void initState() {
    super.initState();
    _specialPctController = TextEditingController();
    _specialPctController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _specialPctController.dispose();
    super.dispose();
  }

  bool get _showCheckoutDiscountEditor =>
      widget.session.status == SessionStatus.active;

  double _parsedSpecialPercent() {
    final raw = _specialPctController.text.trim();
    if (raw.isEmpty) return 0;
    final v = double.tryParse(raw);
    if (v == null) return 0;
    return v.clamp(0.0, 100.0);
  }

  SessionCheckoutBillResult _resultForConfirm() {
    if (!_showCheckoutDiscountEditor) {
      return const SessionCheckoutBillResult(discounts: null);
    }
    final membershipAsync = ref.read(activeMembershipTypeDefinitionsProvider);
    final defs = membershipAsync.valueOrNull ?? <MembershipTypeDefinition>[];
    final membershipPct = membershipDiscountPercentForCustomer(
      customer: widget.customer,
      definitions: defs,
    );
    final specialPct = _parsedSpecialPercent();
    return SessionCheckoutBillResult(
      discounts: discountsMapForEndSession(
        membershipPercent: membershipPct,
        specialPercent: specialPct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session;
    final customer = widget.customer;
    final tableCharges = session.tableCharges;
    final totalBillAmount = session.calculateTotalBillAmount();
    final membershipAsync = ref.watch(activeMembershipTypeDefinitionsProvider);
    final defs = membershipAsync.valueOrNull ?? <MembershipTypeDefinition>[];
    final membershipPct = _showCheckoutDiscountEditor
        ? membershipDiscountPercentForCustomer(
            customer: customer,
            definitions: defs,
          )
        : 0.0;
    final specialPct =
        _showCheckoutDiscountEditor ? _parsedSpecialPercent() : 0.0;
    final draftDiscounts = _showCheckoutDiscountEditor
        ? discountsMapForEndSession(
            membershipPercent: membershipPct,
            specialPercent: specialPct,
          )
        : null;
    final discountPreview = _showCheckoutDiscountEditor
        ? applySubtotalPercentageDiscounts(
            subtotal: totalBillAmount,
            discounts: draftDiscounts,
          )
        : null;
    final finalAmount = _showCheckoutDiscountEditor
        ? discountPreview!.totalAfterDiscounts
        : session.calculateFinalAmount();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.all(20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          const Text('Bill Summary'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              if (session.isPTL) ...[
                const SizedBox(height: AppTheme.kSpacingSmall),
                _buildPTLInfo(theme),
              ],
              const Divider(height: AppTheme.kSpacingLarge),
              _buildBillDetails(theme, tableCharges, ref),
              const Divider(height: AppTheme.kSpacingLarge),
              if (_showCheckoutDiscountEditor) ...[
                _buildCheckoutDiscountEditor(theme, membershipPct),
                const Divider(height: AppTheme.kSpacingLarge),
              ],
              _buildTotals(
                theme,
                totalBillAmount,
                finalAmount,
                draftApplied: discountPreview?.appliedDiscounts,
              ),
              if (session.creditsEarned != null && session.creditsEarned! > 0)
                _buildCreditsEarned(theme),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop(_resultForConfirm());
          },
          icon: const Icon(Icons.check_circle),
          label: const Text('Continue to payment'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPTLInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          avatar: const Icon(Icons.sports_esports, size: 18),
          label: Text('LTP Mode • ${session.playerCount ?? '-'} players'),
          backgroundColor: theme.colorScheme.secondaryContainer,
        ),
        if (session.loserPlayerIndex != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.kSpacingSmall),
            child: Chip(
              avatar: const Icon(Icons.emoji_events, size: 18),
              label: Text(
                (() {
                  if (session.playerNames.isNotEmpty &&
                      session.loserPlayerIndex! <= session.playerNames.length) {
                    return '${session.playerNames[session.loserPlayerIndex! - 1]} will pay';
                  }
                  return 'Player ${session.loserPlayerIndex} will pay';
                })(),
              ),
              backgroundColor: theme.colorScheme.errorContainer,
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          customer.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.kSpacingSmall),
        Text('Table: ${session.tableName}', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.kSpacingSmall),
        _buildTimeRow(
          theme,
          'Start Time:',
          DateFormat.jm().format(session.startTime),
        ),
        _buildTimeRow(
          theme,
          'End Time:',
          DateFormat.jm().format(session.endTime!),
        ),
        _buildTimeRow(theme, 'Duration:', session.formattedDuration),
      ],
    );
  }

  Widget _buildTimeRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetails(
    ThemeData theme,
    double tableCharges,
    WidgetRef ref,
  ) {
    final cafeOrdersAsync = ref.watch(
      sessionBillCafeOrdersProvider((
        sessionId: session.id,
        orderIds: session.cafeOrderIds,
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Itemized Bill', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.kSpacingMedium),
        _buildDetailRow(
          'Table Charges (${(session.duration.inMinutes / 60.0).toStringAsFixed(1)} hrs)',
          '₹${tableCharges.toStringAsFixed(2)}',
        ),
        if (session.totalCafeAmount != null && session.totalCafeAmount! > 0)
          cafeOrdersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return _buildDetailRow(
                  'Cafe Orders',
                  '₹${session.totalCafeAmount!.toStringAsFixed(2)}',
                );
              }
              final allItems = orders.expand((order) => order.items).toList();
              if (allItems.isEmpty) {
                final sumOrders = orders.fold<double>(0, (s, o) => s + o.total);
                final amt = sumOrders > 0
                    ? sumOrders
                    : session.totalCafeAmount!;
                final label = orders.length == 1
                    ? 'Cafe order (line items cleared)'
                    : 'Cafe orders (${orders.length}, line items cleared)';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'Cafe',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildDetailRow('  $label', '₹${amt.toStringAsFixed(2)}'),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      'Cafe Items:',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...allItems.map((item) {
                    return _buildDetailRow(
                      '  ${item.quantity} x ${item.name}',
                      '₹${item.total.toStringAsFixed(2)}',
                    );
                  }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) =>
                const Text('Could not load cafe order details.'),
          ),
        if (session.totalMerchandiseAmount != null &&
            session.totalMerchandiseAmount! > 0)
          ref
              .watch(
                sessionBillMerchandiseOrdersProvider((
                  sessionId: session.id,
                  orderIds: session.merchandiseOrderIds,
                )),
              )
              .when(
                data: (mOrders) {
                  if (mOrders.isEmpty) {
                    return _buildDetailRow(
                      'Merchandise',
                      '₹${session.totalMerchandiseAmount!.toStringAsFixed(2)}',
                    );
                  }
                  final items = mOrders.expand((o) => o.items).toList();
                  if (items.isEmpty) {
                    final sumOrders = mOrders.fold<double>(
                      0,
                      (s, o) => s + o.total,
                    );
                    final amt = sumOrders > 0
                        ? sumOrders
                        : session.totalMerchandiseAmount!;
                    final label = mOrders.length == 1
                        ? 'Merchandise order (line items cleared)'
                        : 'Merchandise orders (${mOrders.length}, line items cleared)';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            'Merchandise',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildDetailRow(
                          '  $label',
                          '₹${amt.toStringAsFixed(2)}',
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'Merchandise:',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...items.map(
                        (it) => _buildDetailRow(
                          '  ${it.quantity} x ${it.name}',
                          '₹${(it.price * it.quantity).toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    const Text('Could not load merchandise details'),
              ),
      ],
    );
  }

  Widget _buildCheckoutDiscountEditor(ThemeData theme, double membershipPct) {
    final pctLabel = membershipPct % 1 == 0
        ? '${membershipPct.toInt()}'
        : membershipPct.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Checkout discounts', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.kSpacingSmall),
        if (membershipPct > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.kSpacingSmall),
            child: Text(
              'Membership discount ($pctLabel%)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.kSpacingSmall),
            child: Text(
              'No membership discount (inactive or regular tier).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        TextField(
          controller: _specialPctController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Special discount (%)',
            helperText:
                'Applied to subtotal; stacks with membership as in billing.',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixText: '%',
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTotals(
    ThemeData theme,
    double totalBillAmount,
    double finalAmount, {
    Map<String, dynamic>? draftApplied,
  }) {
    final sem = AppSemanticColors.of(context);
    return Column(
      children: [
        _buildDetailRow(
          'Subtotal',
          '₹${totalBillAmount.toStringAsFixed(2)}',
          isBold: true,
        ),
        const Divider(
          height: AppTheme.kSpacingMedium,
          indent: 20,
          endIndent: 20,
        ),
        if (draftApplied != null && draftApplied.isNotEmpty) ...[
          if (draftApplied['membershipDiscountPercentage'] != null)
            _buildDetailRow(
              'Membership Discount (${draftApplied['membershipDiscountPercentage']}%)',
              '- ₹${(totalBillAmount * (draftApplied['membershipDiscountPercentage'] as num) / 100).toStringAsFixed(2)}',
              color: sem.success,
            ),
          if (draftApplied['specialDiscountPercentage'] != null)
            _buildDetailRow(
              'Special Discount (${draftApplied['specialDiscountPercentage']}%)',
              '- ₹${(totalBillAmount * (draftApplied['specialDiscountPercentage'] as num) / 100).toStringAsFixed(2)}',
              color: sem.success,
            ),
        ] else if (session.discountsApplied != null &&
            session.discountsApplied!.isNotEmpty) ...[
          if (session.discountsApplied!['membershipDiscountPercentage'] != null)
            _buildDetailRow(
              'Membership Discount (${session.discountsApplied!['membershipDiscountPercentage']}%)',
              '- ₹${(totalBillAmount * parseFirestoreDouble(session.discountsApplied!['membershipDiscountPercentage']) / 100).toStringAsFixed(2)}',
              color: sem.success,
            ),
          if (session.discountsApplied!['specialDiscountPercentage'] != null)
            _buildDetailRow(
              'Special Discount (${session.discountsApplied!['specialDiscountPercentage']}%)',
              '- ₹${(totalBillAmount * parseFirestoreDouble(session.discountsApplied!['specialDiscountPercentage']) / 100).toStringAsFixed(2)}',
              color: sem.success,
            ),
        ],
        if (session.creditsUsed != null && session.creditsUsed! > 0)
          _buildDetailRow(
            'Credits Used',
            '- ₹${session.creditsUsed!.toStringAsFixed(2)}',
            color: sem.success,
          ),
        const Divider(height: AppTheme.kSpacingLarge),
        _buildDetailRow(
          'Final Amount',
          '₹${finalAmount.toStringAsFixed(2)}',
          isBold: true,
          isTotal: true,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildCreditsEarned(ThemeData theme) {
    final sem = AppSemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.kSpacingMedium),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                sem.warningContainer,
                sem.warning.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sem.warning.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: sem.warning, size: 22),
              const SizedBox(width: 8),
              Text(
                'Earn ₹${session.creditsEarned!.toStringAsFixed(2)} credits!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: sem.onWarningContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    bool isTotal = false,
    Color? color,
    ThemeData? theme,
  }) {
    final textStyle = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: isTotal ? 20 : 16,
      color: color ?? (isTotal ? theme?.colorScheme.primary : null),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: textStyle.copyWith(fontSize: 15))),
          Text(value, style: textStyle),
        ],
      ),
    );
  }
}

/// Mobile-optimized bill summary as draggable bottom sheet
class _MobileBillSheet extends ConsumerStatefulWidget {
  final TableSession session;
  final Customer customer;
  final ScrollController scrollController;

  const _MobileBillSheet({
    required this.session,
    required this.customer,
    required this.scrollController,
  });

  @override
  ConsumerState<_MobileBillSheet> createState() => _MobileBillSheetState();
}

class _MobileBillSheetState extends ConsumerState<_MobileBillSheet> {
  late final TextEditingController _specialPctController;

  TableSession get session => widget.session;
  Customer get customer => widget.customer;
  ScrollController get scrollController => widget.scrollController;

  @override
  void initState() {
    super.initState();
    _specialPctController = TextEditingController();
    _specialPctController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _specialPctController.dispose();
    super.dispose();
  }

  bool get _showCheckoutDiscountEditor =>
      widget.session.status == SessionStatus.active;

  double _parsedSpecialPercent() {
    final raw = _specialPctController.text.trim();
    if (raw.isEmpty) return 0;
    final v = double.tryParse(raw);
    if (v == null) return 0;
    return v.clamp(0.0, 100.0);
  }

  SessionCheckoutBillResult _resultForConfirm() {
    if (!_showCheckoutDiscountEditor) {
      return const SessionCheckoutBillResult(discounts: null);
    }
    final membershipAsync = ref.read(activeMembershipTypeDefinitionsProvider);
    final defs = membershipAsync.valueOrNull ?? <MembershipTypeDefinition>[];
    final membershipPct = membershipDiscountPercentForCustomer(
      customer: customer,
      definitions: defs,
    );
    final specialPct = _parsedSpecialPercent();
    return SessionCheckoutBillResult(
      discounts: discountsMapForEndSession(
        membershipPercent: membershipPct,
        specialPercent: specialPct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalBillAmount = session.calculateTotalBillAmount();
    final membershipAsync = ref.watch(activeMembershipTypeDefinitionsProvider);
    final defs = membershipAsync.valueOrNull ?? <MembershipTypeDefinition>[];
    final membershipPct = _showCheckoutDiscountEditor
        ? membershipDiscountPercentForCustomer(
            customer: customer,
            definitions: defs,
          )
        : 0.0;
    final specialPct =
        _showCheckoutDiscountEditor ? _parsedSpecialPercent() : 0.0;
    final draftDiscounts = _showCheckoutDiscountEditor
        ? discountsMapForEndSession(
            membershipPercent: membershipPct,
            specialPercent: specialPct,
          )
        : null;
    final discountPreview = _showCheckoutDiscountEditor
        ? applySubtotalPercentageDiscounts(
            subtotal: totalBillAmount,
            discounts: draftDiscounts,
          )
        : null;
    final finalAmount = _showCheckoutDiscountEditor
        ? discountPreview!.totalAfterDiscounts
        : session.calculateFinalAmount();
    final tableCharges = session.tableCharges;

    return GlassPanel(
      blur: GlassBlur.modal,
      borderRadiusGeometry: const BorderRadius.vertical(
        top: Radius.circular(24),
      ),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Fixed header
          _buildSheetHeader(context, theme, finalAmount),

          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                _buildCustomerCard(theme),
                const SizedBox(height: 16),
                if (session.isPTL) ...[
                  _buildPTLCard(theme),
                  const SizedBox(height: 16),
                ],
                _buildItemsCard(theme, tableCharges, ref),
                const SizedBox(height: 16),
                if (_showCheckoutDiscountEditor) ...[
                  _buildMobileCheckoutDiscountEditor(theme, membershipPct),
                  const SizedBox(height: 16),
                ],
                _buildTotalsCard(
                  theme,
                  totalBillAmount,
                  finalAmount,
                  draftApplied: discountPreview?.appliedDiscounts,
                ),
                if (session.creditsEarned != null &&
                    session.creditsEarned! > 0) ...[
                  const SizedBox(height: 16),
                  _buildCreditsCard(theme),
                ],
                const SizedBox(height: 100), // Space for button
              ],
            ),
          ),

          // Fixed bottom button
          _buildBottomButton(context, theme),
        ],
      ),
    );
  }

  Widget _buildSheetHeader(
    BuildContext context,
    ThemeData theme,
    double finalAmount,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
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
                      'Bill Summary',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total: ₹${finalAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, null),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      session.tableName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildInfoRow(
            theme,
            Icons.play_arrow_rounded,
            'Start',
            DateFormat.jm().format(session.startTime),
          ),
          const SizedBox(height: 6),
          _buildInfoRow(
            theme,
            Icons.stop_rounded,
            'End',
            DateFormat.jm().format(session.endTime!),
          ),
          const SizedBox(height: 6),
          _buildInfoRow(
            theme,
            Icons.timer_rounded,
            'Duration',
            session.formattedDuration,
          ),
        ],
      ),
    );
  }

  Widget _buildPTLCard(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.tertiary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sports_esports_rounded,
            color: cs.onTertiaryContainer,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loser to Pay Mode',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                Text(
                  session.loserPlayerIndex != null &&
                          session.playerNames.isNotEmpty
                      ? '${session.playerNames[session.loserPlayerIndex! - 1]} pays'
                      : '${session.playerCount ?? 2} players',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsCard(ThemeData theme, double tableCharges, WidgetRef ref) {
    final cafeOrdersAsync = ref.watch(
      sessionBillCafeOrdersProvider((
        sessionId: session.id,
        orderIds: session.cafeOrderIds,
      )),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildItemRow(
            'Table (${(session.duration.inMinutes / 60.0).toStringAsFixed(1)} hrs)',
            '₹${tableCharges.toStringAsFixed(0)}',
            icon: Icons.table_restaurant_rounded,
          ),
          if (session.totalCafeAmount != null &&
              session.totalCafeAmount! > 0) ...[
            const Divider(height: 16),
            cafeOrdersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return _buildItemRow(
                    'Cafe',
                    '₹${session.totalCafeAmount!.toStringAsFixed(0)}',
                    icon: Icons.local_cafe_rounded,
                  );
                }
                final allItems = orders.expand((order) => order.items).toList();
                if (allItems.isEmpty) {
                  final sumOrders = orders.fold<double>(
                    0,
                    (s, o) => s + o.total,
                  );
                  final amt = sumOrders > 0
                      ? sumOrders
                      : session.totalCafeAmount!;
                  final label = orders.length == 1
                      ? 'Cafe (items cleared)'
                      : 'Cafe (${orders.length} orders, items cleared)';
                  return _buildItemRow(
                    label,
                    '₹${amt.toStringAsFixed(0)}',
                    icon: Icons.local_cafe_rounded,
                  );
                }
                return Column(
                  children: allItems
                      .map(
                        (item) => _buildItemRow(
                          '${item.quantity}x ${item.name}',
                          '₹${item.total.toStringAsFixed(0)}',
                          icon: Icons.fastfood_rounded,
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => _buildItemRow(
                'Cafe',
                '₹${session.totalCafeAmount!.toStringAsFixed(0)}',
                icon: Icons.local_cafe_rounded,
              ),
            ),
          ],
          if (session.totalMerchandiseAmount != null &&
              session.totalMerchandiseAmount! > 0) ...[
            const Divider(height: 16),
            ref
                .watch(
                  sessionBillMerchandiseOrdersProvider((
                    sessionId: session.id,
                    orderIds: session.merchandiseOrderIds,
                  )),
                )
                .when(
                  data: (mOrders) {
                    if (mOrders.isEmpty) {
                      return _buildItemRow(
                        'Merchandise',
                        '₹${session.totalMerchandiseAmount!.toStringAsFixed(0)}',
                        icon: Icons.shopping_bag_rounded,
                      );
                    }
                    final items = mOrders.expand((o) => o.items).toList();
                    if (items.isEmpty) {
                      final sumOrders = mOrders.fold<double>(
                        0,
                        (s, o) => s + o.total,
                      );
                      final amt = sumOrders > 0
                          ? sumOrders
                          : session.totalMerchandiseAmount!;
                      final label = mOrders.length == 1
                          ? 'Merch (items cleared)'
                          : 'Merch (${mOrders.length} orders, items cleared)';
                      return _buildItemRow(
                        label,
                        '₹${amt.toStringAsFixed(0)}',
                        icon: Icons.shopping_bag_rounded,
                      );
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Merchandise',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...items.map(
                          (it) => _buildItemRow(
                            '${it.quantity}x ${it.name}',
                            '₹${(it.price * it.quantity).toStringAsFixed(0)}',
                            icon: Icons.shopping_bag_rounded,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, _) => _buildItemRow(
                    'Merchandise',
                    '₹${session.totalMerchandiseAmount!.toStringAsFixed(0)}',
                    icon: Icons.shopping_bag_rounded,
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(String label, String value, {IconData? icon}) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileCheckoutDiscountEditor(
    ThemeData theme,
    double membershipPct,
  ) {
    final pctLabel = membershipPct % 1 == 0
        ? '${membershipPct.toInt()}'
        : membershipPct.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Checkout discounts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (membershipPct > 0)
            Text(
              'Membership discount ($pctLabel%)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              'No membership discount (inactive or regular tier).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _specialPctController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Special discount (%)',
              helperText:
                  'Applied to subtotal; stacks with membership as in billing.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixText: '%',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(
    ThemeData theme,
    double totalBillAmount,
    double finalAmount, {
    Map<String, dynamic>? draftApplied,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', '₹${totalBillAmount.toStringAsFixed(2)}'),
          if (draftApplied != null && draftApplied.isNotEmpty) ...[
            const Divider(height: 16),
            if (draftApplied['membershipDiscountPercentage'] != null)
              _buildTotalRow(
                'Membership (${draftApplied['membershipDiscountPercentage']}%)',
                '- ₹${(totalBillAmount * (draftApplied['membershipDiscountPercentage'] as num) / 100).toStringAsFixed(2)}',
                isDiscount: true,
              ),
            if (draftApplied['specialDiscountPercentage'] != null)
              _buildTotalRow(
                'Special (${draftApplied['specialDiscountPercentage']}%)',
                '- ₹${(totalBillAmount * (draftApplied['specialDiscountPercentage'] as num) / 100).toStringAsFixed(2)}',
                isDiscount: true,
              ),
          ] else if (session.discountsApplied != null &&
              session.discountsApplied!.isNotEmpty) ...[
            const Divider(height: 16),
            if (session.discountsApplied!['membershipDiscountPercentage'] !=
                null)
              _buildTotalRow(
                'Membership (${session.discountsApplied!['membershipDiscountPercentage']}%)',
                '- ₹${(totalBillAmount * parseFirestoreDouble(session.discountsApplied!['membershipDiscountPercentage']) / 100).toStringAsFixed(2)}',
                isDiscount: true,
              ),
            if (session.discountsApplied!['specialDiscountPercentage'] != null)
              _buildTotalRow(
                'Special (${session.discountsApplied!['specialDiscountPercentage']}%)',
                '- ₹${(totalBillAmount * parseFirestoreDouble(session.discountsApplied!['specialDiscountPercentage']) / 100).toStringAsFixed(2)}',
                isDiscount: true,
              ),
          ],
          if (session.creditsUsed != null && session.creditsUsed! > 0)
            _buildTotalRow(
              'Credits Used',
              '- ₹${session.creditsUsed!.toStringAsFixed(2)}',
              isDiscount: true,
            ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${finalAmount.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isDiscount = false}) {
    final sem = AppSemanticColors.of(context);
    final discountColor = sem.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDiscount ? discountColor : null),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDiscount ? discountColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsCard(ThemeData theme) {
    final sem = AppSemanticColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            sem.warningContainer,
            sem.warning.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sem.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sem.warning.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.star_rounded,
              color: sem.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credits Earned',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: sem.onWarningContainer,
                  ),
                ),
                Text(
                  '₹${session.creditsEarned!.toStringAsFixed(2)} will be added',
                  style: TextStyle(
                    fontSize: 13,
                    color: sem.onWarningContainer.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(_resultForConfirm());
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text(
              'Continue to payment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
