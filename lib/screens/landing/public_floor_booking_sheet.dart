import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/ui_helpers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../firestore/tenant_firestore.dart';
import '../../models/floor_booking_request.dart';
import '../../models/public_floor_table.dart';
import '../../services/floor_booking_service.dart';
import '../../utils/landing_guest_auth.dart';

Future<void> showPublicFloorBookingSheet(
  BuildContext context, {
  required String companyId,
  required PublicFloorTable table,
  String? venuePhone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _PublicFloorBookingSheet(
        companyId: companyId,
        table: table,
        venuePhone: venuePhone,
      ),
    ),
  );
}

class _PublicFloorBookingSheet extends StatefulWidget {
  const _PublicFloorBookingSheet({
    required this.companyId,
    required this.table,
    this.venuePhone,
  });

  final String companyId;
  final PublicFloorTable table;
  final String? venuePhone;

  @override
  State<_PublicFloorBookingSheet> createState() =>
      _PublicFloorBookingSheetState();
}

class _PublicFloorBookingSheetState extends State<_PublicFloorBookingSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _submitting = false;

  static const _minWindow = Duration(minutes: 15);
  static const _maxWindow = Duration(hours: 8);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    final startHour = now.minute >= 45 ? now.hour + 1 : now.hour;
    _startTime = TimeOfDay(hour: startHour % 24, minute: 0);
    _endTime = TimeOfDay(
      hour: (startHour + 2) % 24,
      minute: 0,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime day, TimeOfDay t) {
    return DateTime(day.year, day.month, day.day, t.hour, t.minute);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (name.isEmpty) {
      _snack('Please enter your name.');
      return;
    }
    if (phone.isEmpty || phone.length > 32) {
      _snack('Please enter a valid phone number (max 32 characters).');
      return;
    }
    if (note.length > 500) {
      _snack('Note is too long.');
      return;
    }

    final startAt = _combine(_date, _startTime);
    final endAt = _combine(_date, _endTime);
    if (!endAt.isAfter(startAt)) {
      _snack('End time must be after start time.');
      return;
    }
    final len = endAt.difference(startAt);
    if (len < _minWindow) {
      _snack('Booking must be at least 15 minutes.');
      return;
    }
    if (len > _maxWindow) {
      _snack('Booking cannot exceed 8 hours.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ensureLandingGuestUser();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        throw StateError('Could not sign in anonymously.');
      }

      final draft = FloorBookingRequest(
        id: '',
        tableId: widget.table.id,
        tableName: widget.table.name,
        startAt: startAt,
        endAt: endAt,
        guestName: name,
        guestPhone: phone,
        guestEmail: null,
        note: note.isEmpty ? null : note,
        status: FloorBookingRequestStatus.pending,
        requesterUid: uid,
        createdAt: DateTime.now(),
      );

      await FloorBookingService(
        TenantRef(FirebaseFirestore.instance, widget.companyId),
      ).submitRequest(draft);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request sent. The venue will confirm — you will not see '
            '"Reserved" on the floor until they approve.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        _snack(e.message ?? 'Could not submit request (${e.code}).');
      }
    } catch (e) {
      if (mounted) _snack('Could not submit request: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final df = DateFormat.MMMEd();
    final tf = DateFormat.jm();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: FadeInWidget(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Request booking',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.table.name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(df.format(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              subtitle: Text(tf.format(_combine(_date, _startTime))),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: _pickStart,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              subtitle: Text(tf.format(_combine(_date, _endTime))),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: _pickEnd,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.venuePhone != null &&
                widget.venuePhone!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  final raw = widget.venuePhone!.trim();
                  final uri = Uri.parse('tel:${raw.replaceAll(' ', '')}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Call venue'),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit request'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
