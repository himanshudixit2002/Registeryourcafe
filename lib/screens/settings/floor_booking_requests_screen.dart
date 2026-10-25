import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/permission_id.dart';
import '../../models/floor_booking_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/table_provider.dart';
import '../../widgets/permission_denied_scaffold.dart';

/// Staff queue for guest-initiated live-floor booking requests.
class FloorBookingRequestsScreen extends ConsumerWidget {
  const FloorBookingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (!ref.watchResolvedPermissions().can(PermissionIds.navTables)) {
      return const PermissionDeniedScaffold(
        title: 'Floor booking requests',
        message: 'You do not have access to table features.',
      );
    }

    final fmt = DateFormat.yMMMd().add_jm();
    final async = ref.watch(pendingFloorBookingRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Floor booking requests')),
      body: async.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No pending requests.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = list[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.tableName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${fmt.format(r.startAt)} → ${fmt.format(r.endAt)}'),
                      const SizedBox(height: 8),
                      Text('${r.guestName} · ${r.guestPhone}'),
                      if (r.note != null && r.note!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            r.note!.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: () =>
                                _approveBooking(context, ref, r),
                            child: const Text('Approve'),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _declineBooking(context, ref, r),
                            child: const Text('Decline'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load requests: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _approveBooking(
  BuildContext context,
  WidgetRef ref,
  FloorBookingRequest r,
) async {
  final user = ref.read(appUserProvider).valueOrNull;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not identify the current user.')),
    );
    return;
  }
  try {
    await ref.read(floorBookingServiceProvider).approveRequest(
          requestId: r.id,
          decidedByUid: user.uid,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Approved. The public Live floor will show Reserved during that time.',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}

Future<void> _declineBooking(
  BuildContext context,
  WidgetRef ref,
  FloorBookingRequest r,
) async {
  final user = ref.read(appUserProvider).valueOrNull;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not identify the current user.')),
    );
    return;
  }
  final noteCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Decline request'),
      content: TextField(
        controller: noteCtrl,
        decoration: const InputDecoration(
          labelText: 'Note to keep internally (optional)',
        ),
        maxLines: 2,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Decline'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(floorBookingServiceProvider).declineRequest(
          requestId: r.id,
          decidedByUid: user.uid,
          decisionNote: noteCtrl.text.trim().isEmpty
              ? null
              : noteCtrl.text.trim(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request declined.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}
