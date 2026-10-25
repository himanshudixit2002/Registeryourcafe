import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/credit_transaction.dart';
import '../../auth/permission_id.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_indicator.dart';

class CreditLedgerScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String? customerName;

  const CreditLedgerScreen({
    super.key,
    required this.customerId,
    this.customerName,
  });

  @override
  ConsumerState<CreditLedgerScreen> createState() => _CreditLedgerScreenState();
}

class _CreditLedgerScreenState extends ConsumerState<CreditLedgerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.navCustomers)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.customerName ?? 'Credit ledger'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('You do not have access to customer credit data.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final ledgerAsync = ref.watch(
      customerCreditLedgerProvider(widget.customerId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName ?? 'Credit Ledger'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: theme.colorScheme.onSurface,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ledgerAsync.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Error loading ledger', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        data: (txs) {
          if (txs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.account_balance_wallet_outlined,
              message: 'No transactions yet',
              details: 'Credit transactions will appear here',
            );
          }

          final totalCredits = txs
              .where((t) => t.amount > 0)
              .fold<double>(0, (p, t) => p + t.amount);
          final totalDebits = txs
              .where((t) => t.amount < 0)
              .fold<double>(0, (p, t) => p + t.amount.abs());
          final balance = totalCredits - totalDebits;

          return FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              physics: AppTheme.scrollPhysicsFor(context),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      children: [
                        _buildSummaryCard(
                          theme,
                          isMobile,
                          totalCredits: totalCredits,
                          totalDebits: totalDebits,
                          balance: balance,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Icon(
                              Icons.history,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Transaction History',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${txs.length} entries',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final tx = txs[index];
                      return _TransactionCard(
                        transaction: tx,
                        animationDelay: index * 50,
                      );
                    }, childCount: txs.length),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    bool isMobile, {
    required double totalCredits,
    required double totalDebits,
    required double balance,
  }) {
    final onGrad = theme.colorScheme.onPrimary;
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: onGrad.withValues(alpha: 0.85),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Available Balance',
                style: TextStyle(
                  color: onGrad.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${balance.toStringAsFixed(0)}',
            style: TextStyle(
              color: onGrad,
              fontSize: isMobile ? 36 : 44,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          // Credits & Debits
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: onGrad.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Total Added',
                    value: '₹${totalCredits.toStringAsFixed(0)}',
                    accent: theme.colorScheme.tertiary,
                    onGradient: onGrad,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: onGrad.withValues(alpha: 0.28),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Total Used',
                    value: '₹${totalDebits.toStringAsFixed(0)}',
                    accent: theme.colorScheme.error,
                    onGradient: onGrad,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    required Color onGradient,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: onGradient.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: onGradient,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TransactionCard extends StatefulWidget {
  final CreditTransaction transaction;
  final int animationDelay;

  const _TransactionCard({
    required this.transaction,
    required this.animationDelay,
  });

  @override
  State<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<_TransactionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future<void>.delayed(Duration(milliseconds: widget.animationDelay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreditTransaction tx = widget.transaction;
    final isCredit = tx.amount >= 0;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final creditColor = cs.tertiary;
    final debitColor = cs.error;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () {
              HapticFeedback.lightImpact();
            },
            padding: EdgeInsets.all(isMobile ? 14 : 18),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isCredit ? creditColor : debitColor).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCredit
                        ? Icons.add_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                    color: isCredit ? creditColor : debitColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCredit ? 'Credit Added' : 'Credit Used',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('MMM d, y • h:mm a').format(tx.date),
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Amount & Method
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isCredit ? '+' : '-'}₹${tx.amount.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: isCredit ? creditColor : debitColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tx.paymentMethod.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
