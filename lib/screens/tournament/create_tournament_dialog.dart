import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/tournament.dart';
import '../../models/table_type_definition.dart';
import '../../providers/tournament_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/table_type_provider.dart';
import '../../theme/app_theme.dart';
import 'package:registeryourcafe/constants/app_strings.dart';
import '../../utils/snackbar_helper.dart';

class CreateTournamentDialog extends ConsumerStatefulWidget {
  final Tournament? existingTournament;

  const CreateTournamentDialog({super.key, this.existingTournament});

  @override
  ConsumerState<CreateTournamentDialog> createState() =>
      _CreateTournamentDialogState();
}

class _CreateTournamentDialogState
    extends ConsumerState<CreateTournamentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _entryFeeController = TextEditingController(text: '0');
  final _prizePoolController = TextEditingController(text: '0');
  final _pointsWinnerController = TextEditingController(text: '100');
  final _pointsRunnerUpController = TextEditingController(text: '50');
  final _pointsPerWinController = TextEditingController(text: '10');
  final _maxParticipantsController = TextEditingController(text: '8');
  final _minParticipantsController = TextEditingController(text: '2');

  TournamentFormat _format = TournamentFormat.singleElimination;
  TournamentGameType _gameType = TournamentGameType.snooker;
  bool _hasNoMaxLimit = false;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTableId;
  String? _selectedTableName;
  bool _isSeeded = false;
  bool _showOnPublicLanding = false;
  bool _isLoading = false;

  bool get isEditing => widget.existingTournament != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _populateFromExisting();
    }
  }

  void _populateFromExisting() {
    final t = widget.existingTournament!;
    _nameController.text = t.name;
    _descriptionController.text = t.description ?? '';
    _entryFeeController.text = t.entryFee.toStringAsFixed(0);
    _prizePoolController.text = t.prizePool.toStringAsFixed(0);
    _pointsWinnerController.text = t.pointsForWinner.toStringAsFixed(0);
    _pointsRunnerUpController.text = t.pointsForRunnerUp.toStringAsFixed(0);
    _pointsPerWinController.text = t.pointsPerWin.toStringAsFixed(0);
    _maxParticipantsController.text = t.maxParticipants.toString();
    _minParticipantsController.text = t.minParticipants.toString();
    _format = t.format;
    _gameType = t.gameType;
    _hasNoMaxLimit = t.hasNoMaxLimit;
    _startDate = t.startDate;
    _selectedTableId = t.preferredTableId;
    _selectedTableName = t.preferredTableName;
    _isSeeded = t.isSeeded;
    _showOnPublicLanding = t.showOnPublicLanding;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _entryFeeController.dispose();
    _prizePoolController.dispose();
    _pointsWinnerController.dispose();
    _pointsRunnerUpController.dispose();
    _pointsPerWinController.dispose();
    _maxParticipantsController.dispose();
    _minParticipantsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);
    final tablesAsync = ref.watch(tableListProvider);
    final typeDefs = ref
        .watch(tableTypeDefinitionsProvider)
        .maybeWhen(data: (d) => d, orElse: () => <TableTypeDefinition>[]);

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 16 : 40),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.emoji_events,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Tournament' : 'Create Tournament',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tournament Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tournament Name *',
                          hintText: 'e.g., Weekly Snooker Championship',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a tournament name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Optional description',
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),

                      // Game Type & Format
                      Text(
                        'Tournament Settings',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Builder(
                        builder: (ctx) {
                          final gameTypeItems = TournamentGameType.values
                              .map(
                                (type) => DropdownMenuItem<TournamentGameType>(
                                  value: type,
                                  child: Text(type.displayName),
                                ),
                              )
                              .toList();
                          final formatItems = TournamentFormat.values
                              .map(
                                (format) => DropdownMenuItem<TournamentFormat>(
                                  value: format,
                                  child: Text(format.displayName),
                                ),
                              )
                              .toList();
                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<
                                    TournamentGameType>(
                                  initialValue: _gameType,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Game Type',
                                    prefixIcon: Icon(Icons.sports),
                                  ),
                                  items: gameTypeItems,
                                  selectedItemBuilder: (context) =>
                                      AppTheme.dropdownSelectedItemBuilders(
                                        theme,
                                        gameTypeItems,
                                      ),
                                  onChanged: (value) {
                                    setState(() => _gameType = value!);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<TournamentFormat>(
                                  initialValue: _format,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Format',
                                    prefixIcon: Icon(Icons.account_tree),
                                  ),
                                  items: formatItems,
                                  selectedItemBuilder: (context) =>
                                      AppTheme.dropdownSelectedItemBuilders(
                                        theme,
                                        formatItems,
                                      ),
                                  onChanged: (value) {
                                    setState(() => _format = value!);
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show on public home page'),
                        subtitle: const Text(
                          'When on, this tournament can appear in the public carousel (draft / registration / in progress only).',
                        ),
                        value: _showOnPublicLanding,
                        onChanged: (v) =>
                            setState(() => _showOnPublicLanding = v),
                      ),
                      const SizedBox(height: 16),

                      // Participant Settings
                      Text(
                        'Participant Limits',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Quick select for common sizes
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...[4, 8, 16, 32].map(
                            (n) => ChoiceChip(
                              label: Text(n.toString()),
                              selected:
                                  !_hasNoMaxLimit &&
                                  (int.tryParse(
                                            _maxParticipantsController.text,
                                          ) ??
                                          0) ==
                                      n,
                              onSelected: (_) {
                                setState(() {
                                  _hasNoMaxLimit = false;
                                  _maxParticipantsController.text = n
                                      .toString();
                                });
                              },
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Unlimited'),
                            selected: _hasNoMaxLimit,
                            onSelected: (_) {
                              setState(() {
                                _hasNoMaxLimit = true;
                                _maxParticipantsController.text = '0';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minParticipantsController,
                              decoration: const InputDecoration(
                                labelText: 'Min Participants',
                                hintText: 'e.g., 2',
                                prefixIcon: Icon(Icons.people_outline),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                final min = int.tryParse(value ?? '') ?? 0;
                                if (min < 2) {
                                  return 'Min 2 required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _maxParticipantsController,
                              enabled: !_hasNoMaxLimit,
                              decoration: InputDecoration(
                                labelText: 'Max Participants',
                                hintText: _hasNoMaxLimit
                                    ? 'Unlimited'
                                    : 'e.g., 16',
                                prefixIcon: const Icon(Icons.people),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (_hasNoMaxLimit) return null;
                                final max = int.tryParse(value ?? '') ?? 0;
                                final min =
                                    int.tryParse(
                                      _minParticipantsController.text,
                                    ) ??
                                    2;
                                if (max > 0 && max < min) {
                                  return 'Must be ≥ min';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hasNoMaxLimit
                            ? '• No limit on participants. Byes will be auto-calculated.'
                            : '• Non-power-of-2 counts will use byes (e.g., 6 players = 2 byes)',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Start Date
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Date'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _pickDate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(_startDate),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Preferred Table
                      Text(
                        'Preferred Table (Optional)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      tablesAsync.when(
                        data: (tables) {
                          final filteredTables = tables
                              .where(
                                (t) => tableTypeMatchesTournament(
                                  typeId: t.typeId,
                                  definitions: typeDefs,
                                  tournamentType: _gameType,
                                ),
                              )
                              .toList();
                          final tablePrefItems = <DropdownMenuItem<String>>[
                            const DropdownMenuItem(
                              value: null,
                              child: Text('No preference'),
                            ),
                            ...filteredTables.map(
                              (table) => DropdownMenuItem(
                                value: table.id,
                                child: Text(table.name),
                              ),
                            ),
                          ];
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedTableId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              hintText: 'Select a table',
                              prefixIcon: Icon(Icons.table_bar),
                            ),
                            items: tablePrefItems,
                            selectedItemBuilder: (context) =>
                                AppTheme.dropdownSelectedItemBuilders(
                                  theme,
                                  tablePrefItems,
                                ),
                            onChanged: (value) {
                              final selectedTable = value != null
                                  ? tables.firstWhere((t) => t.id == value)
                                  : null;
                              setState(() {
                                _selectedTableId = value;
                                _selectedTableName = selectedTable?.name;
                              });
                            },
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, _) => const Text('Could not load tables'),
                      ),
                      const SizedBox(height: 20),

                      // Points Settings
                      Text(
                        'Points & Prizes',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _entryFeeController,
                              decoration: const InputDecoration(
                                labelText: 'Entry Fee (₹)',
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _prizePoolController,
                              decoration: const InputDecoration(
                                labelText: 'Prize Pool (₹)',
                                prefixIcon: Icon(Icons.card_giftcard),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _pointsWinnerController,
                              decoration: const InputDecoration(
                                labelText: 'Winner Points',
                                prefixIcon: Icon(Icons.emoji_events),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _pointsRunnerUpController,
                              decoration: const InputDecoration(
                                labelText: 'Runner-up Points',
                                prefixIcon: Icon(Icons.workspace_premium),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _pointsPerWinController,
                        decoration: const InputDecoration(
                          labelText: 'Points Per Match Win',
                          prefixIcon: Icon(Icons.stars),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Options
                      CheckboxListTile(
                        value: _isSeeded,
                        onChanged: (val) => setState(() => _isSeeded = val!),
                        title: const Text('Use Seeded Bracket'),
                        subtitle: const Text(
                          'Higher seeds play lower seeds in first round',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text(AppStrings.cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveTournament,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(isEditing ? 'Save Changes' : 'Create'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _saveTournament() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(appUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final service = ref.read(tournamentServiceProvider);

      final maxParts = _hasNoMaxLimit
          ? 0
          : (int.tryParse(_maxParticipantsController.text) ?? 0);
      final minParts = int.tryParse(_minParticipantsController.text) ?? 2;

      if (isEditing) {
        // Update existing tournament
        final updated = widget.existingTournament!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          format: _format,
          gameType: _gameType,
          maxParticipants: maxParts,
          minParticipants: minParts,
          hasNoMaxLimit: _hasNoMaxLimit,
          startDate: _startDate,
          entryFee: double.tryParse(_entryFeeController.text) ?? 0.0,
          prizePool: double.tryParse(_prizePoolController.text) ?? 0.0,
          pointsForWinner:
              double.tryParse(_pointsWinnerController.text) ?? 100.0,
          pointsForRunnerUp:
              double.tryParse(_pointsRunnerUpController.text) ?? 50.0,
          pointsPerWin: double.tryParse(_pointsPerWinController.text) ?? 10.0,
          preferredTableId: _selectedTableId,
          preferredTableName: _selectedTableName,
          isSeeded: _isSeeded,
          showOnPublicLanding: _showOnPublicLanding,
        );
        await service.updateTournament(updated);
      } else {
        // Create new tournament
        await service.createTournament(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          format: _format,
          gameType: _gameType,
          startDate: _startDate,
          maxParticipants: maxParts,
          minParticipants: minParts,
          hasNoMaxLimit: _hasNoMaxLimit,
          entryFee: double.tryParse(_entryFeeController.text) ?? 0.0,
          prizePool: double.tryParse(_prizePoolController.text) ?? 0.0,
          pointsForWinner:
              double.tryParse(_pointsWinnerController.text) ?? 100.0,
          pointsForRunnerUp:
              double.tryParse(_pointsRunnerUpController.text) ?? 50.0,
          pointsPerWin: double.tryParse(_pointsPerWinController.text) ?? 10.0,
          createdBy: currentUser,
          preferredTableId: _selectedTableId,
          preferredTableName: _selectedTableName,
          isSeeded: _isSeeded,
          showOnPublicLanding: _showOnPublicLanding,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
