import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../firestore/tenant_firestore.dart';
import '../../models/credit_transaction_with_customer.dart';
import '../../theme/app_theme.dart';
import '../../auth/permission_id.dart';
import '../../providers/customer_provider.dart'
    show allCreditTransactionsWithCustomerProvider;
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/credit_transaction_tile.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../services/whatsapp_service.dart';

class AllCreditTransactionsScreen extends ConsumerStatefulWidget {
  const AllCreditTransactionsScreen({super.key});

  @override
  ConsumerState<AllCreditTransactionsScreen> createState() =>
      _AllCreditTransactionsScreenState();
}

class _AllCreditTransactionsScreenState
    extends ConsumerState<AllCreditTransactionsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _dateRange;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<CreditTransactionWithCustomer> _applyFilters(
    List<CreditTransactionWithCustomer> items,
  ) {
    return items.where((item) {
      final tx = item.transaction;

      final query = _searchController.text.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          item.customerName.toLowerCase().contains(query) ||
          (item.phoneNumber ?? '').contains(query) ||
          (item.membershipId ?? '').toLowerCase().contains(query);

      final inDateRange =
          _dateRange == null ||
          (tx.date.isAfter(
                _dateRange!.start.subtract(const Duration(seconds: 1)),
              ) &&
              tx.date.isBefore(
                _dateRange!.end.add(const Duration(seconds: 1)),
              ));

      return matchesQuery && inDateRange;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.opsCustomersAdmin)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Credit transactions'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('You do not have access to this report.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final txAsync = ref.watch(allCreditTransactionsWithCustomerProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: isMobile ? 16 : 20,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Flexible(
              child: Text(
                'Credit Transactions',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: isMobile,
        actions: [
          if (_dateRange != null)
            IconButton(
              tooltip: 'Clear Date Range',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _dateRange = null);
              },
            ),
          IconButton(
            tooltip: 'Select Date Range',
            icon: Badge(
              isLabelVisible: _dateRange != null,
              smallSize: 8,
              child: const Icon(Icons.date_range_rounded),
            ),
            onPressed: () async {
              await HapticFeedback.lightImpact();
              if (!context.mounted) return;
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 1),
                initialDateRange: _dateRange,
              );
              if (picked != null) {
                setState(() => _dateRange = picked);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      hintText: 'Search by name, phone, membership...',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.75),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                if (_dateRange != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: theme.colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Content
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: txAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: theme.colorScheme.error,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: $e',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (items) {
                  final tenant = ref.watch(tenantRefProvider);
                  if (tenant == null) {
                    return const Center(child: Text('No company context'));
                  }
                  return _buildContent(context, items, isMobile, tenant);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<CreditTransactionWithCustomer> items,
    bool isMobile,
    TenantRef tenant,
  ) {
    final theme = Theme.of(context);
    final filtered = _applyFilters(items);

    if (filtered.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.receipt_long_rounded,
        message: 'No Transactions',
        details: 'No transactions match your filters',
      );
    }

    final globalAdded = filtered
        .where((e) => e.transaction.amount >= 0)
        .fold<double>(0, (p, e) => p + e.transaction.amount);
    final globalUsed = filtered
        .where((e) => e.transaction.amount < 0)
        .fold<double>(0, (p, e) => p + e.transaction.amount.abs());
    final globalBalance = globalAdded - globalUsed;

    final Map<String, List<CreditTransactionWithCustomer>> byCustomer = {};
    for (final item in filtered) {
      byCustomer.putIfAbsent(item.customerId, () => []).add(item);
    }

    final customerIds = byCustomer.keys.toList();

    return ListView.builder(
      physics: AppTheme.scrollPhysicsFor(context),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: customerIds.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) {
          return _buildGlobalSummary(
            theme,
            globalAdded,
            globalUsed,
            globalBalance,
            isMobile,
          );
        }

        final cid = customerIds[idx - 1];
        final list = byCustomer[cid]!;
        return _buildCustomerCard(context, list, isMobile, tenant);
      },
    );
  }

  Widget _buildGlobalSummary(
    ThemeData theme,
    double added,
    double used,
    double balance,
    bool isMobile,
  ) {
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      color: cs.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 16 : 18,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      theme,
                      'Added',
                      added,
                      cs.tertiary,
                      Icons.add_circle_rounded,
                      isMobile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      theme,
                      'Used',
                      used,
                      cs.error,
                      Icons.remove_circle_rounded,
                      isMobile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      theme,
                      'Balance',
                      balance,
                      cs.primary,
                      Icons.account_balance_wallet_rounded,
                      isMobile,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    ThemeData theme,
    String label,
    double value,
    Color accent,
    IconData icon,
    bool isMobile,
  ) {
    final cs = theme.colorScheme;
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₹${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(
    BuildContext context,
    List<CreditTransactionWithCustomer> list,
    bool isMobile,
    TenantRef tenant,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final added = list
        .where((e) => e.transaction.amount >= 0)
        .fold<double>(0, (p, e) => p + e.transaction.amount);
    final used = list
        .where((e) => e.transaction.amount < 0)
        .fold<double>(0, (p, e) => p + e.transaction.amount.abs());
    final balance = added - used;
    final customer = list.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: 4,
            ),
            childrenPadding: EdgeInsets.all(isMobile ? 12 : 16),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  customer.customerName.isNotEmpty
                      ? customer.customerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            title: Text(
              customer.customerName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer.phoneNumber != null)
                  Text(
                    customer.phoneNumber!,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: isMobile ? 12 : 13,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: balance >= 0
                        ? cs.tertiaryContainer.withValues(alpha: 0.65)
                        : cs.errorContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Balance: ₹${balance.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: balance >= 0
                          ? cs.onTertiaryContainer
                          : cs.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            children: [
              // Customer summary
              Row(
                children: [
                  Expanded(
                    child: _buildMiniMetric(theme, 'Added', added, cs.tertiary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniMetric(theme, 'Used', used, cs.error),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Send ledger button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send Ledger via WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.tertiary,
                    side: BorderSide(color: cs.tertiary.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _sendLedger(list, balance),
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                thickness: 1,
                color: AppTheme.subtleDividerColor(theme),
              ),
              // Transactions list
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  return CreditTransactionTile(
                    tx: list[i].transaction,
                    tenant: tenant,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(
    ThemeData theme,
    String label,
    double value,
    Color accent,
  ) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          Text(
            '₹${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendLedger(
    List<CreditTransactionWithCustomer> list,
    double balance,
  ) async {
    await HapticFeedback.lightImpact();
    if (!mounted) return;

    final phone = list.first.phoneNumber ?? '';
    if (phone.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.tertiaryContainer,
          content: Text(
            'Customer phone not found',
            style: TextStyle(color: cs.onTertiaryContainer),
          ),
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Registeryourcafe – Credit Ledger');
    buffer.writeln('Customer: ${list.first.customerName}');
    buffer.writeln('Date: ${DateFormat.yMMMd().format(DateTime.now())}\n');

    for (final ct in list.take(50).toList().reversed) {
      final t = ct.transaction;
      final sign = t.amount >= 0 ? '+' : '-';
      final amt = t.amount.abs().toStringAsFixed(0);
      final dateStr = DateFormat('dd/MM/yy').add_jm().format(t.date);
      buffer.writeln(
        '$dateStr  $sign$amt  (${t.paymentMethod.name.toUpperCase()})',
      );
      if ((t.note ?? '').isNotEmpty) buffer.writeln('  • ${t.note}');
    }

    buffer.writeln('\nBalance: ${balance.toStringAsFixed(0)}');
    buffer.writeln('\nThank you!');

    try {
      await WhatsAppService.sendMessage(
        rawPhone: phone,
        message: buffer.toString(),
      );
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.errorContainer,
            content: Text(
              e.toString(),
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        );
      }
    }
  }
}
