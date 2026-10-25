import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class SAGuestsScreen extends ConsumerStatefulWidget {
  const SAGuestsScreen({super.key});
  @override
  ConsumerState<SAGuestsScreen> createState() => _SAGuestsScreenState();
}

class _SAGuestsScreenState extends ConsumerState<SAGuestsScreen> {
  String _search = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final guestsAsync = ref.watch(allGuestProfilesProvider);
    final ordersAsync = ref.watch(allGuestOrdersProvider);
    final bookingsAsync = ref.watch(allBookingRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guest Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allGuestProfilesProvider);
              ref.invalidate(allGuestOrdersProvider);
              ref.invalidate(allBookingRequestsProvider);
            },
          ),
        ],
      ),
      body: guestsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Error loading guests', style: TextStyle(color: cs.error)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(allGuestProfilesProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (guests) {
          int active = 0, suspended = 0;
          for (final g in guests) {
            if (g.data()['suspended'] == true) {
              suspended++;
            } else {
              active++;
            }
          }

          final totalOrders = ordersAsync.valueOrNull?.length ?? 0;
          final totalBookings = bookingsAsync.valueOrNull?.length ?? 0;

          final filtered = guests.where((d) {
            final data = d.data();
            final isSuspended = data['suspended'] == true;
            if (_statusFilter == 'active' && isSuspended) return false;
            if (_statusFilter == 'suspended' && !isSuspended) return false;
            if (_search.isEmpty) return true;
            return (data['name'] as String? ?? '').toLowerCase().contains(_search) ||
                (data['email'] as String? ?? '').toLowerCase().contains(_search);
          }).toList();

          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
              child: Row(
                children: [
                  _SummaryCard(label: 'Total', value: guests.length, color: cs.primary, icon: Icons.people),
                  const SizedBox(width: 8),
                  _SummaryCard(label: 'Active', value: active, color: AppTheme.successColor, icon: Icons.check_circle_outline),
                  const SizedBox(width: 8),
                  _SummaryCard(label: 'Suspended', value: suspended, color: AppTheme.warningColor, icon: Icons.pause_circle_outline),
                  const SizedBox(width: 8),
                  _SummaryCard(label: 'Orders', value: totalOrders, color: AppTheme.infoColor, icon: Icons.shopping_bag_outlined),
                  const SizedBox(width: 8),
                  _SummaryCard(label: 'Bookings', value: totalBookings, color: cs.tertiary, icon: Icons.event_seat_outlined),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.isDesktop(context) ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      hintText: 'Search guests...',
                      leading: const Icon(Icons.search, size: 20),
                      onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('All')),
                      ButtonSegment(value: 'active', label: Text('Active')),
                      ButtonSegment(value: 'suspended', label: Text('Paused')),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (s) => setState(() => _statusFilter = s.first),
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.kSpacingSmall),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text('No guest profiles match', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          if (_search.isNotEmpty || _statusFilter != 'all') ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _search = '';
                                _statusFilter = 'all';
                              }),
                              icon: const Icon(Icons.filter_alt_off, size: 18),
                              label: const Text('Clear filters'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: AppTheme.scrollPhysicsFor(context),
                      padding: EdgeInsets.symmetric(horizontal: AppTheme.isDesktop(context) ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final d = filtered[i].data();
                        final uid = filtered[i].id;
                        final isSuspended = d['suspended'] == true;
                        final createdAt = d['createdAt'];
                        String joinedStr = '';
                        if (createdAt is Timestamp) {
                          joinedStr = DateFormat.yMMMd().format(createdAt.toDate());
                        }
                        final loyaltyPts = d['loyaltyPoints'] ?? 0;

                        return FadeInWidget(
                          delay: Duration(milliseconds: 40 * (i % 20)),
                          child: AppCard(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSuspended ? AppTheme.warningColor.withValues(alpha: 0.15) : cs.primaryContainer,
                                child: Text(
                                  ((d['name'] as String?) ?? '?').isNotEmpty ? ((d['name'] as String?) ?? '?')[0].toUpperCase() : '?',
                                  style: TextStyle(color: isSuspended ? AppTheme.warningColor : cs.onPrimaryContainer, fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      d['name'] as String? ?? 'Guest',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSuspended) ...[
                                    const SizedBox(width: 8),
                                    StatusBadge(label: 'SUSPENDED', color: AppTheme.warningColor),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (d['email'] != null)
                                    Text(d['email']?.toString() ?? '', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.workspace_premium, size: 14, color: cs.primary),
                                      const SizedBox(width: 4),
                                      Text('$loyaltyPts pts', style: theme.textTheme.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
                                      if (joinedStr.isNotEmpty) ...[
                                        Text('  ·  ', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                        Text('Joined $joinedStr', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) => _handleAction(context, ref, uid, d, action),
                                itemBuilder: (_) => [
                                  if (!isSuspended)
                                    const PopupMenuItem(value: 'suspend', child: Text('Suspend'))
                                  else
                                    const PopupMenuItem(value: 'reactivate', child: Text('Reactivate')),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete', style: TextStyle(color: cs.error)),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String uid, Map<String, dynamic> d, String action) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.delete_forever, color: Theme.of(ctx).colorScheme.error, size: 36),
          title: const Text('Delete guest?'),
          content: const Text('This will permanently remove the guest profile. This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    try {
      final service = ref.read(superAdminServiceProvider);
      await service.manageGuestAccount(uid, action);
      final actorEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      unawaited(service.logSuperAdminAction(
        action: 'guest_$action',
        actorEmail: actorEmail,
        entityType: 'guest',
        entityId: uid,
        details: '${action[0].toUpperCase()}${action.substring(1)} guest ${d['name'] ?? uid}',
      ));
      if (context.mounted) {
        final msg = switch (action) {
          'suspend' => 'Guest suspended',
          'reactivate' => 'Guest reactivated',
          'delete' => 'Guest deleted',
          _ => 'Action completed',
        };
        context.showSuccessSnackbar(msg);
      }
    } catch (e) {
      if (context.mounted) context.showErrorSnackbar('Failed: $e');
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _SummaryCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            AnimatedCountUp(
              endValue: value.toDouble(),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
