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

class SABookingsScreen extends ConsumerStatefulWidget {
  const SABookingsScreen({super.key});

  @override
  ConsumerState<SABookingsScreen> createState() => _SABookingsScreenState();
}

class _SABookingsScreenState extends ConsumerState<SABookingsScreen> {
  String _search = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bookingsAsync = ref.watch(allBookingRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allBookingRequestsProvider),
          ),
        ],
      ),
      body: bookingsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Error loading bookings', style: TextStyle(color: cs.error)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(allBookingRequestsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (bookings) {
          int pending = 0, approved = 0, declined = 0;
          for (final b in bookings) {
            switch (b.data()['status'] as String? ?? 'pending') {
              case 'pending': pending++;
              case 'approved': approved++;
              case 'declined': declined++;
            }
          }

          final filtered = bookings.where((doc) {
            final d = doc.data();
            final status = d['status'] as String? ?? 'pending';
            if (_statusFilter != 'all' && status != _statusFilter) return false;
            if (_search.isEmpty) return true;
            final q = _search.toLowerCase();
            final guestName = (d['guestName'] as String? ?? '').toLowerCase();
            final tableName = (d['tableName'] as String? ?? '').toLowerCase();
            final companyId = (doc.reference.parent.parent?.id ?? '').toLowerCase();
            return guestName.contains(q) || tableName.contains(q) || companyId.contains(q);
          }).toList();

          if (bookings.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.event_seat_outlined, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 16), Text('No booking requests', style: theme.textTheme.titleMedium),
            ]));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _StatCard(label: 'Total', count: bookings.length, color: cs.primary)),
                    SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _StatCard(label: 'Pending', count: pending, color: AppTheme.warningColor)),
                    SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _StatCard(label: 'Approved', count: approved, color: AppTheme.successColor)),
                    SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _StatCard(label: 'Declined', count: declined, color: cs.error)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.kSpacingMedium),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by guest name, table, company...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: AppTheme.kSpacingSmall),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.kSpacingMedium),
                child: Row(
                  children: [
                    for (final entry in {'all': 'All', 'pending': 'Pending', 'approved': 'Approved', 'declined': 'Declined'}.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(entry.value),
                          selected: _statusFilter == entry.key,
                          onSelected: (_) => setState(() => _statusFilter = entry.key),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.kSpacingSmall),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('No bookings match your filters', style: TextStyle(color: cs.onSurfaceVariant)))
                    : ListView.separated(
                        physics: AppTheme.scrollPhysicsFor(context),
                        padding: EdgeInsets.all(AppTheme.isDesktop(context) ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => FadeInWidget(
                          delay: Duration(milliseconds: 50 * i),
                          child: _BookingCard(doc: filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatCard({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        children: [
          AnimatedCountUp(
            endValue: count.toDouble(),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _BookingCard({required this.doc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final d = doc.data();
    final companyId = doc.reference.parent.parent?.id ?? '';
    final status = d['status'] as String? ?? 'pending';
    final guestName = d['guestName'] as String? ?? 'Guest';
    final tableName = d['tableName'] as String? ?? '';
    final startAt = d['startAt'];
    final endAt = d['endAt'];

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'pending':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.schedule;
      case 'approved':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
      case 'declined':
        statusColor = cs.error;
        statusIcon = Icons.cancel;
      default:
        statusColor = cs.onSurfaceVariant;
        statusIcon = Icons.help_outline;
    }

    String timeRange = '';
    if (startAt is Timestamp && endAt is Timestamp) {
      final fmt = DateFormat.jm();
      timeRange = '${fmt.format(startAt.toDate())} - ${fmt.format(endAt.toDate())}';
    }

    String dateStr = '';
    if (startAt is Timestamp) {
      dateStr = DateFormat.yMMMd().format(startAt.toDate());
    }

    return AppCard(
      onTap: () => _showBookingDetail(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(guestName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      'Table: $tableName \u2022 $dateStr',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: status.toUpperCase(), color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (timeRange.isNotEmpty)
                Text(timeRange, style: theme.textTheme.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (companyId.isNotEmpty)
                Text(
                  'Cafe: ${companyId.length > 12 ? '${companyId.substring(0, 12)}...' : companyId}',
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBookingDetail(BuildContext context, WidgetRef ref) {
    final d = doc.data();
    final companyId = doc.reference.parent.parent?.id ?? '';
    final status = d['status'] as String? ?? 'pending';
    final guestName = d['guestName'] as String? ?? 'Guest';
    final guestPhone = d['guestPhone'] as String? ?? '';
    final guestEmail = d['guestEmail'] as String? ?? '';
    final tableName = d['tableName'] as String? ?? '';
    final note = d['note'] as String? ?? '';
    final decisionNote = d['decisionNote'] as String? ?? '';
    final startAt = d['startAt'];
    final endAt = d['endAt'];
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final noteController = TextEditingController();

    String startStr = '', endStr = '', dateStr = '';
    if (startAt is Timestamp) {
      startStr = DateFormat.jm().format(startAt.toDate());
      dateStr = DateFormat.yMMMd().format(startAt.toDate());
    }
    if (endAt is Timestamp) {
      endStr = DateFormat.jm().format(endAt.toDate());
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Booking Details', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              _DetailRow(label: 'Guest', value: guestName),
              if (guestPhone.isNotEmpty) _DetailRow(label: 'Phone', value: guestPhone),
              if (guestEmail.isNotEmpty) _DetailRow(label: 'Email', value: guestEmail),
              _DetailRow(label: 'Table', value: tableName),
              _DetailRow(label: 'Date', value: dateStr),
              _DetailRow(label: 'Time', value: '$startStr - $endStr'),
              _DetailRow(label: 'Status', value: status),
              _DetailRow(label: 'Company', value: companyId),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Guest Note', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(note, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
              if (decisionNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Decision Note', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(decisionNote, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
              if (status == 'pending') ...[
                const SizedBox(height: 20),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    hintText: 'Add a note (optional)',
                    prefixIcon: Icon(Icons.note_add_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final service = ref.read(superAdminServiceProvider);
                            await service.updateBookingRequest(
                              companyId, doc.id, 'declined',
                              note: noteController.text.trim(),
                            );
                            final actorEmail = FirebaseAuth.instance.currentUser?.email ?? '';
                            service.logSuperAdminAction(action: 'booking_declined', actorEmail: actorEmail, entityType: 'booking', entityId: doc.id, details: 'Declined booking by $guestName in $companyId');
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) context.showSuccessSnackbar('Booking declined');
                            ref.invalidate(allBookingRequestsProvider);
                          } catch (e) {
                            if (context.mounted) context.showErrorSnackbar('Error: $e');
                          }
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          try {
                            final service = ref.read(superAdminServiceProvider);
                            await service.updateBookingRequest(
                              companyId, doc.id, 'approved',
                              note: noteController.text.trim(),
                            );
                            final actorEmail = FirebaseAuth.instance.currentUser?.email ?? '';
                            service.logSuperAdminAction(action: 'booking_approved', actorEmail: actorEmail, entityType: 'booking', entityId: doc.id, details: 'Approved booking by $guestName in $companyId');
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) context.showSuccessSnackbar('Booking approved');
                            ref.invalidate(allBookingRequestsProvider);
                          } catch (e) {
                            if (context.mounted) context.showErrorSnackbar('Error: $e');
                          }
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ).then((_) => noteController.dispose());
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
