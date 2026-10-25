import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/public_venue_listing.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../widgets/app_card.dart';

class AdvancedBookingScreen extends ConsumerStatefulWidget {
  final PublicVenueListing listing;
  const AdvancedBookingScreen({super.key, required this.listing});

  @override
  ConsumerState<AdvancedBookingScreen> createState() =>
      _AdvancedBookingScreenState();
}

class _AdvancedBookingScreenState extends ConsumerState<AdvancedBookingScreen> {
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);
  int _partySize = 2;
  String? _occasion;
  String? _preferences;
  bool _isRecurring = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static const _occasions = [
    'Birthday',
    'Anniversary',
    'Business',
    'Date night',
    'Family gathering',
    'Friends meetup',
    'Other',
  ];

  static const _prefs = [
    'Window seat',
    'Quiet area',
    'Outdoor',
    'Near entrance',
    'Private room',
    'No preference',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = AppTheme.isDesktop(context)
        ? AppTheme.kSpacingXLarge
        : AppTheme.kSpacingMedium;

    return Scaffold(
      appBar: AppBar(title: Text('Book at ${widget.listing.displayName}')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'When?',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _buildDateRow(theme),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePicker(
                          label: 'Start',
                          time: _startTime,
                          onPick: (t) => setState(() => _startTime = t),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimePicker(
                          label: 'End',
                          time: _endTime,
                          onPick: (t) => setState(() => _endTime = t),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Party size',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        onPressed: _partySize > 1
                            ? () => setState(() => _partySize--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          '$_partySize',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _partySize < 20
                            ? () => setState(() => _partySize++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Special occasion?',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in _occasions)
                        ChoiceChip(
                          label: Text(o),
                          selected: _occasion == o,
                          onSelected: (s) =>
                              setState(() => _occasion = s ? o : null),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seating preference',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in _prefs)
                        ChoiceChip(
                          label: Text(p),
                          selected: _preferences == p,
                          onSelected: (s) =>
                              setState(() => _preferences = s ? p : null),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Special requests (optional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Make this recurring'),
                    subtitle: const Text('Repeat this booking weekly'),
                    value: _isRecurring,
                    onChanged: (v) => setState(() => _isRecurring = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Confirm booking'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      context.showErrorSnackbar('Name and phone are required');
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      context.showSuccessSnackbar('Booking request submitted!');
      Navigator.pop(context);
    }
  }

  Widget _buildDateRow(ThemeData theme) {
    final days = List.generate(14, (i) => DateTime.now().add(Duration(days: i)));
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final isSelected = d.day == _date.day && d.month == _date.month;
          return GestureDetector(
            onTap: () => setState(() => _date = d),
            child: Container(
              width: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    const [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ][d.weekday - 1],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${d.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    const [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec',
                    ][d.month - 1],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onPick,
  }) {
    return OutlinedButton.icon(
      onPressed: () async {
        final t = await showTimePicker(context: context, initialTime: time);
        if (t != null) onPick(t);
      },
      icon: const Icon(Icons.access_time, size: 18),
      label: Text(
        '$label: ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      ),
    );
  }
}
