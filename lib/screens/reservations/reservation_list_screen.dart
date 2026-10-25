import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reservation.dart';
import '../../providers/reservation_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';
import 'create_reservation_screen.dart';

class ReservationListScreen extends ConsumerWidget {
  const ReservationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reservationsAsync = ref.watch(reservationsProvider);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reservations')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const CreateReservationScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: reservationsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (reservations) {
          if (reservations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_seat_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No reservations',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Tap + to create one.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          return ListView.separated(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.fromLTRB(
              isDesktop
                  ? AppTheme.kSpacingXLarge
                  : AppTheme.kSpacingMedium,
              AppTheme.kSpacingMedium,
              isDesktop
                  ? AppTheme.kSpacingXLarge
                  : AppTheme.kSpacingMedium,
              AppTheme.kSpacingXLarge +
                  MediaQuery.paddingOf(context).bottom +
                  80,
            ),
            itemCount: reservations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _ReservationCard(reservation: reservations[i]),
          );
        },
      ),
    );
  }
}

class _ReservationCard extends ConsumerWidget {
  final Reservation reservation;

  const _ReservationCard({required this.reservation});

  Color _statusColor(ThemeData theme) {
    switch (reservation.status) {
      case ReservationStatus.pending:
        return theme.colorScheme.tertiary;
      case ReservationStatus.confirmed:
        return theme.colorScheme.primary;
      case ReservationStatus.cancelled:
        return theme.colorScheme.error;
      case ReservationStatus.completed:
        return theme.colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(theme).withValues(alpha: 0.2),
          child: Icon(Icons.event_seat,
              color: _statusColor(theme), size: 20),
        ),
        title: Text(reservation.guestName,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${reservation.date.day}/${reservation.date.month}/${reservation.date.year} \u2022 ${reservation.startTime} - ${reservation.endTime}'),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color:
                          _statusColor(theme).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(reservation.status.name,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: _statusColor(theme),
                          fontWeight: FontWeight.w600)),
                ),
                if (reservation.tableName != null) ...[
                  const SizedBox(width: 8),
                  Text(reservation.tableName!,
                      style: theme.textTheme.labelSmall),
                ],
                const SizedBox(width: 8),
                Text('${reservation.partySize} guests',
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<ReservationStatus>(
          onSelected: (status) async {
            try {
              final service = ref.read(reservationServiceProvider);
              if (service == null) return;
              await service.updateStatus(reservation.id, status);
              if (context.mounted) {
                context.showSuccessSnackbar('Status updated');
              }
            } catch (e) {
              if (context.mounted) {
                context.showErrorSnackbar('Failed: $e');
              }
            }
          },
          itemBuilder: (_) => [
            for (final s in ReservationStatus.values)
              if (s != reservation.status)
                PopupMenuItem(value: s, child: Text(s.name)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
