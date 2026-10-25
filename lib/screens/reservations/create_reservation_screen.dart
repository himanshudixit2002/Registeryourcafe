import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reservation.dart';
import '../../providers/reservation_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_card.dart';

class CreateReservationScreen extends ConsumerStatefulWidget {
  const CreateReservationScreen({super.key});

  @override
  ConsumerState<CreateReservationScreen> createState() =>
      _CreateReservationScreenState();
}

class _CreateReservationScreenState
    extends ConsumerState<CreateReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _partySizeController = TextEditingController(text: '2');
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _partySizeController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final reservation = Reservation(
        id: '',
        guestName: _nameController.text.trim(),
        guestPhone: _phoneController.text.trim(),
        date: _date,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        partySize: int.tryParse(_partySizeController.text.trim()) ?? 2,
        createdAt: DateTime.now(),
      );
      await ref
          .read(reservationServiceProvider)
          ?.createReservation(reservation);
      if (mounted) {
        context.showSuccessSnackbar('Reservation created');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New reservation')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingXLarge,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                          labelText: 'Guest name',
                          prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone_outlined)),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _partySizeController,
                      decoration: const InputDecoration(
                          labelText: 'Party size',
                          prefixIcon: Icon(Icons.group_outlined)),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text(
                          '${_date.day}/${_date.month}/${_date.year}'),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: const Text('Change'),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                'Start: ${_formatTime(_startTime)}'),
                            onTap: () async {
                              final t = await showTimePicker(
                                  context: context,
                                  initialTime: _startTime);
                              if (t != null) {
                                setState(() => _startTime = t);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title:
                                Text('End: ${_formatTime(_endTime)}'),
                            onTap: () async {
                              final t = await showTimePicker(
                                  context: context,
                                  initialTime: _endTime);
                              if (t != null) {
                                setState(() => _endTime = t);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          prefixIcon: Icon(Icons.notes_outlined)),
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Create reservation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
