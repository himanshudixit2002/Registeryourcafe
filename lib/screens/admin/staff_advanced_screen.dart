import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/staff_advanced.dart';
import '../../providers/tenant_provider.dart';
import '../../services/staff_advanced_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class StaffAdvancedScreen extends ConsumerStatefulWidget {
  const StaffAdvancedScreen({super.key});

  @override
  ConsumerState<StaffAdvancedScreen> createState() =>
      _StaffAdvancedScreenState();
}

class _StaffAdvancedScreenState extends ConsumerState<StaffAdvancedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff advanced'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Commissions'),
            Tab(text: 'Leave requests'),
            Tab(text: 'Training'),
            Tab(text: 'Goals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _CommissionsTab(),
          _LeaveTab(),
          _TrainingTab(),
          _GoalsTab(),
        ],
      ),
    );
  }
}

class _CommissionsTab extends ConsumerWidget {
  const _CommissionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return StreamBuilder<List<CommissionRecord>>(
      stream: StaffAdvancedService(tenant).watchCommissions(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final recs = snap.data ?? [];
        if (recs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.attach_money,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No commissions yet',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        final total = recs.fold(0.0, (s, r) => s + r.commissionAmount);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(children: [
                Text('Total commissions',
                    style: theme.textTheme.titleSmall),
                Text(
                  '\u20B9${total.toStringAsFixed(0)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            for (final r in recs) ...[
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.staffName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Sale: \u20B9${r.saleAmount.toStringAsFixed(0)} @ ${r.commissionRate}%',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\u20B9${r.commissionAmount.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
            ],
          ],
        );
      },
    );
  }
}

class _LeaveTab extends ConsumerWidget {
  const _LeaveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return StreamBuilder<List<LeaveRequest>>(
      stream: StaffAdvancedService(tenant).watchLeaveRequests(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final reqs = snap.data ?? [];
        if (reqs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No leave requests',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reqs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = reqs[i];
            final isPending = r.status == 'pending';
            return AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(
                  '${r.staffName} - ${r.type}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${r.startDate.day}/${r.startDate.month} - ${r.endDate.day}/${r.endDate.month} \u2022 ${r.reason}',
                ),
                trailing: isPending
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.check),
                          color: theme.colorScheme.primary,
                          onPressed: () async {
                            await StaffAdvancedService(tenant)
                                .updateLeaveStatus(r.id, 'approved');
                            if (context.mounted) {
                              context.showSuccessSnackbar('Approved');
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: theme.colorScheme.error,
                          onPressed: () async {
                            await StaffAdvancedService(tenant)
                                .updateLeaveStatus(r.id, 'rejected');
                            if (context.mounted) {
                              context.showSuccessSnackbar('Rejected');
                            }
                          },
                        ),
                      ])
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (r.status == 'approved'
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r.status,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TrainingTab extends ConsumerWidget {
  const _TrainingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return StreamBuilder<List<TrainingModule>>(
      stream: StaffAdvancedService(tenant).watchTraining(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final mods = snap.data ?? [];
        if (mods.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No training modules',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final m in mods) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text('${m.totalSteps} steps',
                        style: theme.textTheme.labelSmall),
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

class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return StreamBuilder<List<StaffGoal>>(
      stream: StaffAdvancedService(tenant).watchGoals(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final goals = snap.data ?? [];
        if (goals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined,
                    size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No goals set', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final g in goals) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          g.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${g.progressPercent.toStringAsFixed(0)}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '${g.staffName} \u2022 ${g.metric}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: g.progressPercent / 100,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${g.current}/${g.target} \u2022 Due ${g.deadline.day}/${g.deadline.month}/${g.deadline.year}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
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
