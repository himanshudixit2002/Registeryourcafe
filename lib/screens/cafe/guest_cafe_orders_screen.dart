import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/permission_id.dart';
import '../../models/guest_cafe_order.dart';
import '../../models/venue_ui_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/guest_cafe_order_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/permission_denied_scaffold.dart';

/// Staff: pending public guest menu orders → promote to kitchen [CafeOrder].
class GuestCafeOrdersScreen extends ConsumerWidget {
  const GuestCafeOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (!ref.watchResolvedPermissions().can(PermissionIds.navCafe)) {
      return const PermissionDeniedScaffold(
        title: 'Guest menu orders',
        message: 'You do not have access to the café.',
      );
    }

    final async = ref.watch(pendingGuestCafeOrdersProvider);
    final svc = ref.watch(guestCafeOrderServiceProvider);
    final userAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(venueKindProvider).guestOrdersTitle),
        centerTitle: true,
      ),
      body: svc == null
          ? const Center(child: Text('No company context.'))
          : async.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        ref.watch(venueKindProvider).guestOrdersEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  physics: AppTheme.scrollPhysicsFor(context),
                  padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final g = list[i];
                    return _GuestOrderCard(
                      order: g,
                      onPromote: () async {
                        final user = userAsync.valueOrNull;
                        if (user == null) {
                          if (context.mounted) {
                            context.showErrorSnackbar('Not signed in.');
                          }
                          return;
                        }
                        try {
                          final id = await svc.promoteToCafeOrder(
                            guest: g,
                            staff: user,
                            venueKind: ref.read(venueKindProvider),
                          );
                          if (context.mounted) {
                            context.showSuccessSnackbar(
                              'Sent to kitchen as $id',
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            context.showErrorSnackbar('$e');
                          }
                        }
                      },
                      onDismiss: () async {
                        try {
                          await svc.cancelGuestOrder(g.id);
                          if (context.mounted) {
                            context.showSuccessSnackbar('Order dismissed');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            context.showErrorSnackbar('$e');
                          }
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $e'),
                ),
              ),
            ),
    );
  }
}

class _GuestOrderCard extends StatelessWidget {
  const _GuestOrderCard({
    required this.order,
    required this.onPromote,
    required this.onDismiss,
  });

  final GuestCafeOrder order;
  final Future<void> Function() onPromote;
  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM d, y · h:mm a');
    final where = order.orderMode == 'table'
        ? 'Table ${order.tableName}'
        : 'Counter / takeaway';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.guestName} · ${order.guestPhone}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  fmt.format(order.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              where,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (order.guestNotes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                order.guestNotes.trim(),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            ...order.items.map(
              (it) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${it.quantity}× ${it.name}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '\u20B9${(it.price * it.quantity).toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.subtleDividerColor(theme),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '\u20B9${order.total.toStringAsFixed(0)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: onPromote,
                    child: const Text('Send to kitchen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
