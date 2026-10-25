import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/table_advanced.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/table_advanced_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class TableAdvancedScreen extends ConsumerStatefulWidget {
  const TableAdvancedScreen({super.key});

  @override
  ConsumerState<TableAdvancedScreen> createState() =>
      _TableAdvancedScreenState();
}

class _TableAdvancedScreenState extends ConsumerState<TableAdvancedScreen>
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table management'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Maintenance'),
            Tab(text: 'Walk-in Queue'),
            Tab(text: 'Cleaning'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _MaintenanceTab(),
          _WalkInTab(),
          _CleaningTab(),
        ],
      ),
    );
  }
}

class _MaintenanceTab extends ConsumerWidget {
  const _MaintenanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<TableMaintenanceLog>>(
      stream: TableAdvancedService(tenant).watchMaintenance(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final logs = snap.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.build_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No maintenance logs',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final l = logs[i];
            final isOpen = l.status == 'open';
            return AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  isOpen ? Icons.warning_amber : Icons.check_circle,
                  color: isOpen
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                title: Text(
                  '${l.tableName}: ${l.issue}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${l.createdAt.day}/${l.createdAt.month}/${l.createdAt.year} \u2022 ${l.status}',
                ),
                trailing: isOpen
                    ? IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () async {
                          final user =
                              ref.read(appUserProvider).valueOrNull;
                          await TableAdvancedService(tenant)
                              .resolveMaintenance(
                            l.id,
                            user?.name ?? 'Admin',
                          );
                          if (context.mounted) {
                            context.showSuccessSnackbar('Resolved');
                          }
                        },
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _WalkInTab extends ConsumerWidget {
  const _WalkInTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<WalkInQueueEntry>>(
      stream: TableAdvancedService(tenant).watchWalkInQueue(),
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
                Icon(
                  Icons.group_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No one in queue',
                  style: theme.textTheme.titleMedium,
                ),
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
                leading: CircleAvatar(child: Text('${e.partySize}')),
                title: Text(
                  e.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text('~${e.estimatedMinutes} min wait'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.event_seat),
                      color: theme.colorScheme.primary,
                      onPressed: () async {
                        await TableAdvancedService(tenant)
                            .updateWalkInStatus(e.id, 'seated');
                        if (context.mounted) {
                          context.showSuccessSnackbar('Seated');
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: theme.colorScheme.error,
                      onPressed: () async {
                        await TableAdvancedService(tenant)
                            .updateWalkInStatus(e.id, 'left');
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

class _CleaningTab extends StatelessWidget {
  const _CleaningTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cleaning_services_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Table cleaning status',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Mark tables as clean, dirty, or in-progress\nfrom the table grid view.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
