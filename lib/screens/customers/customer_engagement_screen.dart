import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/customer_engagement.dart';
import '../../providers/tenant_provider.dart';
import '../../services/customer_engagement_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class CustomerEngagementScreen extends ConsumerStatefulWidget {
  const CustomerEngagementScreen({super.key});

  @override
  ConsumerState<CustomerEngagementScreen> createState() =>
      _CustomerEngagementScreenState();
}

class _CustomerEngagementScreenState
    extends ConsumerState<CustomerEngagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer engagement'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Waitlist'),
            Tab(text: 'Referrals'),
            Tab(text: 'Segments'),
            Tab(text: 'Campaigns'),
            Tab(text: 'Badges'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _WaitlistTab(),
          _ReferralsTab(),
          _SegmentsTab(),
          _CampaignsTab(),
          _BadgesTab(),
        ],
      ),
    );
  }
}

class _WaitlistTab extends ConsumerWidget {
  const _WaitlistTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const Center(child: Text('No workspace'));
    final theme = Theme.of(context);
    return StreamBuilder<List<WaitlistEntry>>(
      stream: CustomerEngagementService(tenant).watchWaitlist(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final entries = snap.data ?? [];
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No one waiting', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = entries[i];
            return AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  child: Text('${e.partySize}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                title: Text(
                  e.customerName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                    '~${e.estimatedWaitMinutes} min wait \u2022 ${e.customerPhone}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      color: theme.colorScheme.primary,
                      onPressed: () async {
                        await CustomerEngagementService(tenant)
                            .updateWaitlistStatus(e.id, 'seated');
                        if (context.mounted) {
                          context.showSuccessSnackbar('Seated');
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined),
                      color: theme.colorScheme.error,
                      onPressed: () async {
                        await CustomerEngagementService(tenant)
                            .updateWaitlistStatus(e.id, 'cancelled');
                        if (context.mounted) {
                          context.showSuccessSnackbar('Removed');
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReferralsTab extends ConsumerWidget {
  const _ReferralsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<ReferralRecord>>(
      stream: CustomerEngagementService(tenant).watchReferrals(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final refs = snap.data ?? [];
        if (refs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No referrals yet', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: refs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = refs[i];
            return AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.person_add, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code: ${r.referralCode}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (r.rewardClaimed
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.rewardClaimed ? 'Claimed' : 'Pending',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: r.rewardClaimed
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
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

class _SegmentsTab extends ConsumerWidget {
  const _SegmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Customer segments', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create segments based on visit frequency,\n'
            'spending habits, and membership status.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CampaignsTab extends ConsumerWidget {
  const _CampaignsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Marketing campaigns', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Target customer segments with\n'
            'personalized messages and offers.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _BadgesTab extends StatelessWidget {
  const _BadgesTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final b in BadgeDefinitions.all) ...[
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(_iconFor(b.icon),
                      color: theme.colorScheme.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        b.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (b.requiredPoints > 0)
                  Text(
                    '${b.requiredPoints} pts',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'star':
        return Icons.star_rounded;
      case 'repeat':
        return Icons.replay;
      case 'diamond':
        return Icons.diamond_outlined;
      case 'trophy':
        return Icons.emoji_events;
      case 'crown':
        return Icons.workspace_premium;
      case 'money':
        return Icons.attach_money;
      case 'share':
        return Icons.share;
      case 'rate_review':
        return Icons.rate_review;
      default:
        return Icons.badge;
    }
  }
}
