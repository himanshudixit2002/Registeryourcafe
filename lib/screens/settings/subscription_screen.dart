import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subscription_plan.dart';
import '../../providers/tenant_provider.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _currentPlanId = 'free';
  DateTime? _expiresAt;
  bool _loading = true;
  bool _upgrading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final service = SubscriptionService(tenant);
    final planId = await service.getCurrentPlanId();
    final expires = await service.getExpirationDate();
    if (mounted) {
      setState(() {
        _currentPlanId = planId;
        _expiresAt = expires;
        _loading = false;
      });
    }
  }

  Future<void> _upgrade(SubscriptionPlan plan) async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Upgrade to ${plan.name}?'),
        content: Text(
          plan.isFree
              ? 'Switch to the Free plan.'
              : 'Subscribe to ${plan.name} for \u20B9${plan.monthlyPrice.toStringAsFixed(0)}/month.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _upgrading = true);
    try {
      await SubscriptionService(tenant).upgradePlan(plan.id);
      if (mounted) {
        setState(() => _currentPlanId = plan.id);
        context.showSuccessSnackbar('Plan updated to ${plan.name}');
        _load();
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);
    final currentPlan = SubscriptionPlan.findById(_currentPlanId);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription & billing')),
        body: const ShimmerList(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription & billing')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingXLarge + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                children: [
                  Text(
                    'Current plan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentPlan.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (!currentPlan.isFree) ...[
                    const SizedBox(height: 4),
                    Text(
                      '\u20B9${currentPlan.monthlyPrice.toStringAsFixed(0)}/month',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                  if (_expiresAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Expires: ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _limitChip(theme, 'Staff', '${currentPlan.maxStaff}'),
                      const SizedBox(width: 12),
                      _limitChip(
                        theme,
                        'Tables',
                        currentPlan.maxTables >= 999
                            ? '\u221E'
                            : '${currentPlan.maxTables}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All plans',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final plan in SubscriptionPlan.allPlans) ...[
              _PlanCard(
                plan: plan,
                isCurrent: plan.id == _currentPlanId,
                onUpgrade: _upgrading ? null : () => _upgrade(plan),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _limitChip(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final VoidCallback? onUpgrade;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      plan.isFree
                          ? 'Free forever'
                          : '\u20B9${plan.monthlyPrice.toStringAsFixed(0)}/month',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Current',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                FilledButton.tonal(
                  onPressed: onUpgrade,
                  child: Text(plan.isFree ? 'Downgrade' : 'Upgrade'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _featureTag(theme, '${plan.maxStaff} staff'),
              _featureTag(
                theme,
                plan.maxTables >= 999
                    ? 'Unlimited tables'
                    : '${plan.maxTables} tables',
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(f, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _featureTag(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
