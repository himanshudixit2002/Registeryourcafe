import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/shift.dart';
import '../../providers/shift_provider.dart';
import '../../providers/staff_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class ShiftManagementScreen extends ConsumerStatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  ConsumerState<ShiftManagementScreen> createState() =>
      _ShiftManagementScreenState();
}

class _ShiftManagementScreenState
    extends ConsumerState<ShiftManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shiftsAsync = ref.watch(shiftsProvider);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Shift management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateShiftDialog(context),
        child: const Icon(Icons.add),
      ),
      body: shiftsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shifts) {
          if (shifts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No shifts scheduled',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to schedule a shift.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.fromLTRB(
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingMedium,
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingXLarge +
                  MediaQuery.paddingOf(context).bottom +
                  80,
            ),
            itemCount: shifts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _ShiftCard(shift: shifts[i]),
          );
        },
      ),
    );
  }

  Future<void> _showCreateShiftDialog(BuildContext context) async {
    final staff = ref.read(companyStaffProvider).valueOrNull ?? [];
    if (staff.isEmpty) {
      context.showErrorSnackbar('No staff members found');
      return;
    }
    String? selectedUid;
    String? selectedName;
    final startController = TextEditingController(text: '09:00');
    final endController = TextEditingController(text: '17:00');
    DateTime date = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Schedule shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedUid,
                decoration: const InputDecoration(labelText: 'Staff member'),
                items: staff
                    .map((s) =>
                        DropdownMenuItem(value: s.uid, child: Text(s.name)))
                    .toList(),
                onChanged: (v) {
                  setDialogState(() {
                    selectedUid = v;
                    selectedName =
                        staff.firstWhere((s) => s.uid == v).name;
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startController,
                      decoration:
                          const InputDecoration(labelText: 'Start time'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: endController,
                      decoration:
                          const InputDecoration(labelText: 'End time'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title:
                    Text('Date: ${date.day}/${date.month}/${date.year}'),
                trailing: TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 90)),
                    );
                    if (d != null) setDialogState(() => date = d);
                  },
                  child: const Text('Change'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
    if (result != true || selectedUid == null || !context.mounted) return;
    try {
      final shift = Shift(
        id: '',
        staffUid: selectedUid!,
        staffName: selectedName ?? 'Staff',
        date: date,
        scheduledStart: startController.text.trim(),
        scheduledEnd: endController.text.trim(),
      );
      final service = ref.read(shiftServiceProvider);
      if (service == null) return;
      await service.createShift(shift);
      if (context.mounted) context.showSuccessSnackbar('Shift scheduled');
    } catch (e) {
      if (context.mounted) context.showErrorSnackbar('Failed: $e');
    }
  }
}

class _ShiftCard extends ConsumerWidget {
  final Shift shift;
  const _ShiftCard({required this.shift});

  Color _statusColor(ThemeData theme) {
    switch (shift.status) {
      case ShiftStatus.scheduled:
        return theme.colorScheme.tertiary;
      case ShiftStatus.clockedIn:
        return theme.colorScheme.primary;
      case ShiftStatus.clockedOut:
        return theme.colorScheme.outline;
      case ShiftStatus.absent:
        return theme.colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _statusColor(theme);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(
            shift.staffName.isNotEmpty
                ? shift.staffName[0].toUpperCase()
                : '?',
            style:
                TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          shift.staffName,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${shift.date.day}/${shift.date.month}/${shift.date.year} \u2022 ${shift.scheduledStart} - ${shift.scheduledEnd}',
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    shift.status.name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (shift.hoursWorked > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${shift.hoursWorked.toStringAsFixed(1)}h worked',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, ref, action),
          itemBuilder: (_) => [
            if (shift.status == ShiftStatus.scheduled)
              const PopupMenuItem(
                value: 'clockIn',
                child: Text('Clock in'),
              ),
            if (shift.status == ShiftStatus.clockedIn)
              const PopupMenuItem(
                value: 'clockOut',
                child: Text('Clock out'),
              ),
            if (shift.status == ShiftStatus.scheduled)
              const PopupMenuItem(
                value: 'absent',
                child: Text('Mark absent'),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final service = ref.read(shiftServiceProvider);
    if (service == null) return;
    try {
      switch (action) {
        case 'clockIn':
          await service.clockIn(shift.id);
        case 'clockOut':
          await service.clockOut(shift.id);
        case 'absent':
          await service.markAbsent(shift.id);
        case 'delete':
          await service.deleteShift(shift.id);
      }
      if (context.mounted) context.showSuccessSnackbar('Updated');
    } catch (e) {
      if (context.mounted) context.showErrorSnackbar('Failed: $e');
    }
  }
}
