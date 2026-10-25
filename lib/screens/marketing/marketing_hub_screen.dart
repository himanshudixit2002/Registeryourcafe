import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/marketing.dart';
import '../../providers/tenant_provider.dart';
import '../../services/marketing_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class MarketingHubScreen extends ConsumerStatefulWidget {
  const MarketingHubScreen({super.key});

  @override
  ConsumerState<MarketingHubScreen> createState() =>
      _MarketingHubScreenState();
}

class _MarketingHubScreenState extends ConsumerState<MarketingHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Marketing'),
          bottom: TabBar(controller: _tab, tabs: const [
            Tab(text: 'Campaigns'),
            Tab(text: 'Gift cards'),
            Tab(text: 'Budget'),
          ]),
        ),
        body: TabBarView(
          controller: _tab,
          children: const [_CampaignsTab(), _GiftCardsTab(), _BudgetTab()],
        ),
      );
}

class _CampaignsTab extends ConsumerWidget {
  const _CampaignsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<MarketingCampaign>>(
      stream: MarketingService(tenant).watchCampaigns(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final campaigns = snap.data ?? [];
        if (campaigns.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No campaigns', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: campaigns.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = campaigns[i];
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(c.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (c.status == 'sent'
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(c.status,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  Text(
                    '${c.channel} \u2022 ${c.targetCount} targets \u2022 ${c.sentCount} sent',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _GiftCardsTab extends ConsumerWidget {
  const _GiftCardsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<GiftCard>>(
      stream: MarketingService(tenant).watchGiftCards(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final cards = snap.data ?? [];
        if (cards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_giftcard_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No gift cards', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final g in cards) ...[
              AppCard(
                child: Row(children: [
                  Icon(Icons.card_giftcard,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.code,
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                        Text(
                          'Balance: \u20B9${g.currentBalance.toStringAsFixed(0)} / \u20B9${g.originalBalance.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!g.isActive)
                    Text('Expired',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.error)),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _BudgetTab extends ConsumerWidget {
  const _BudgetTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<MarketingBudget>>(
      stream: MarketingService(tenant).watchBudgets(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final budgets = snap.data ?? [];
        if (budgets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No marketing budgets',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final b in budgets) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.channel,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: b.allocated > 0
                          ? (b.spent / b.allocated).clamp(0, 1.5)
                          : 0,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Spent \u20B9${b.spent.toStringAsFixed(0)} of \u20B9${b.allocated.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
