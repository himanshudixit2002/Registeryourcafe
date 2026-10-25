import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class SABillingScreen extends ConsumerWidget {
  const SABillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final companiesAsync = ref.watch(allCompaniesProvider);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allCompaniesProvider),
          ),
        ],
      ),
      body: companiesAsync.when(
        data: (companies) {
          final planBreakdown = _buildPlanBreakdown(companies);
          final plans = planBreakdown.keys.toList()..sort();
          final expiringSoon = _getExpiringSoon(companies);
          final onTrial = _getOnTrial(companies);

          return ListView(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: AppTheme.getScreenPadding(context),
            children: [
              Text('Subscription Overview', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppTheme.kSpacingMedium),
              _buildPlanSummary(context, planBreakdown, companies.length, isDesktop),
              const SizedBox(height: AppTheme.kSpacingLarge),
              Text('Plan Distribution', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppTheme.kSpacingSmall),
              AppCard(
                child: Column(
                  children: plans.map((plan) {
                    final count = planBreakdown[plan]!;
                    final pct = companies.isNotEmpty ? (count * 100 / companies.length) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatPlanName(plan),
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '$count cafes (${pct.toStringAsFixed(1)}%)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _planColor(plan, cs),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: companies.isNotEmpty ? count / companies.length : 0,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: _planColor(plan, cs),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (onTrial.isNotEmpty) ...[
                const SizedBox(height: AppTheme.kSpacingLarge),
                Text('On Trial (${onTrial.length})', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppTheme.kSpacingSmall),
                ...onTrial.map((doc) => _TrialCafeCard(doc: doc)),
              ],
              if (expiringSoon.isNotEmpty) ...[
                const SizedBox(height: AppTheme.kSpacingLarge),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 22),
                    const SizedBox(width: 8),
                    Text('Expiring Soon (${expiringSoon.length})', style: theme.textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: AppTheme.kSpacingSmall),
                ...expiringSoon.map((doc) => _ExpiringCafeCard(doc: doc)),
              ],
              const SizedBox(height: AppTheme.kSpacingLarge),
              Text('Cafes by Plan', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppTheme.kSpacingSmall),
              ...plans.map((plan) {
                final cafes = companies.where((doc) {
                  final p = doc.data()['plan'] as String? ?? 'free';
                  return p == plan;
                }).toList();

                return ExpansionTile(
                  title: Text(
                    '${_formatPlanName(plan)} (${cafes.length})',
                    style: theme.textTheme.titleSmall,
                  ),
                  leading: Icon(Icons.payments, color: _planColor(plan, cs)),
                  children: cafes.map((doc) {
                    final data = doc.data();
                    final name = data['name'] as String? ?? 'Unnamed';
                    return ListTile(
                      dense: true,
                      title: Text(name),
                      subtitle: Text(doc.id, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 18),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: AppTheme.kSpacingXLarge),
            ],
          );
        },
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
      ),
    );
  }

  Map<String, int> _buildPlanBreakdown(List<QueryDocumentSnapshot<Map<String, dynamic>>> companies) {
    final Map<String, int> plans = {};
    for (final doc in companies) {
      final plan = doc.data()['plan'] as String? ?? 'free';
      plans[plan] = (plans[plan] ?? 0) + 1;
    }
    return plans;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getExpiringSoon(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> companies,
  ) {
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));
    return companies.where((doc) {
      final data = doc.data();
      final expiresAt = data['subscriptionExpiresAt'] ?? data['trialEndsAt'];
      if (expiresAt is Timestamp) {
        final dt = expiresAt.toDate();
        return dt.isAfter(now) && dt.isBefore(thirtyDaysFromNow);
      }
      return false;
    }).toList()
      ..sort((a, b) {
        final aTs = (a.data()['subscriptionExpiresAt'] ?? a.data()['trialEndsAt']) as Timestamp;
        final bTs = (b.data()['subscriptionExpiresAt'] ?? b.data()['trialEndsAt']) as Timestamp;
        return aTs.compareTo(bTs);
      });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getOnTrial(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> companies,
  ) {
    final now = DateTime.now();
    return companies.where((doc) {
      final data = doc.data();
      final trialEnds = data['trialEndsAt'];
      if (trialEnds is Timestamp) {
        return trialEnds.toDate().isAfter(now);
      }
      return false;
    }).toList();
  }

  Widget _buildPlanSummary(
    BuildContext context,
    Map<String, int> planBreakdown,
    int total,
    bool isDesktop,
  ) {
    final cs = Theme.of(context).colorScheme;
    final free = planBreakdown['free'] ?? 0;
    final pro = planBreakdown['pro'] ?? 0;
    final enterprise = planBreakdown['enterprise'] ?? 0;
    final other = total - free - pro - enterprise;

    final cards = [
      _PlanCard(label: 'Free', count: free, color: cs.onSurfaceVariant),
      _PlanCard(label: 'Pro', count: pro, color: AppTheme.infoColor),
      _PlanCard(label: 'Enterprise', count: enterprise, color: cs.primary),
      if (other > 0) _PlanCard(label: 'Other', count: other, color: AppTheme.warningColor),
    ];

    if (isDesktop) {
      return Row(children: cards.map((c) => Expanded(child: c)).toList());
    }
    return Wrap(
      children: cards.map((c) => SizedBox(
        width: MediaQuery.of(context).size.width / 2 - 20,
        child: c,
      )).toList(),
    );
  }

  String _formatPlanName(String plan) {
    return plan.isEmpty
        ? 'Unknown'
        : '${plan[0].toUpperCase()}${plan.substring(1)}';
  }

  Color _planColor(String plan, ColorScheme cs) {
    switch (plan) {
      case 'free': return cs.onSurfaceVariant;
      case 'pro': return AppTheme.infoColor;
      case 'enterprise': return cs.primary;
      default: return AppTheme.warningColor;
    }
  }
}

class _PlanCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _PlanCard({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeInWidget(
      child: AppCard(
        child: Column(
          children: [
            AnimatedCountUp(
              endValue: count.toDouble(),
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TrialCafeCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _TrialCafeCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final data = doc.data();
    final name = data['name'] as String? ?? 'Unnamed';
    final trialEnds = data['trialEndsAt'] as Timestamp?;
    final daysLeft = trialEnds != null
        ? trialEnds.toDate().difference(DateTime.now()).inDays
        : 0;

    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.infoColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.hourglass_top, color: AppTheme.infoColor, size: 20),
        ),
        title: Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Trial ends ${trialEnds != null ? DateFormat.yMMMd().format(trialEnds.toDate()) : "N/A"} ($daysLeft days left)',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ExpiringCafeCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _ExpiringCafeCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final data = doc.data();
    final name = data['name'] as String? ?? 'Unnamed';
    final plan = data['plan'] as String? ?? 'free';
    final expiresAt = (data['subscriptionExpiresAt'] ?? data['trialEndsAt']) as Timestamp?;
    final daysLeft = expiresAt != null
        ? expiresAt.toDate().difference(DateTime.now()).inDays
        : 0;

    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 20),
        ),
        title: Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${_formatPlan(plan)} expires ${expiresAt != null ? DateFormat.yMMMd().format(expiresAt.toDate()) : "N/A"} ($daysLeft days)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: daysLeft <= 7 ? cs.error : AppTheme.warningColor,
          ),
        ),
      ),
    );
  }

  String _formatPlan(String plan) =>
      plan.isEmpty ? 'Unknown' : '${plan[0].toUpperCase()}${plan.substring(1)}';
}
