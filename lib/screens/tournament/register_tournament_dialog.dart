import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/tournament.dart';
import '../../models/tournament_registration.dart';
import '../../providers/tournament_service_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class RegisterTournamentDialog extends ConsumerStatefulWidget {
  final Tournament tournament;

  const RegisterTournamentDialog({super.key, required this.tournament});

  @override
  ConsumerState<RegisterTournamentDialog> createState() =>
      _RegisterTournamentDialogState();
}

class _RegisterTournamentDialogState
    extends ConsumerState<RegisterTournamentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingExisting = false;
  String? _existingStatus;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingRegistration(String phoneNumber) async {
    if (phoneNumber.length != 10) return;

    setState(() {
      _isCheckingExisting = true;
      _existingStatus = 'Checking...';
    });

    try {
      final tournamentService = ref.read(tournamentServiceProvider);

      // Check for existing registration request by phone number
      final registration = await tournamentService.getRegistrationByPhone(
        tournamentId: widget.tournament.id,
        phoneNumber: phoneNumber,
      );

      if (registration != null) {
        setState(() {
          _existingStatus =
              'This phone number already has a ${registration.status.displayName.toLowerCase()} registration for this tournament.';
        });
        return;
      }

      // Check if already a participant by phone
      final isParticipant = await tournamentService
          .isPhoneRegisteredAsParticipant(
            tournamentId: widget.tournament.id,
            phoneNumber: phoneNumber,
          );

      if (isParticipant) {
        setState(() {
          _existingStatus =
              'This phone number is already registered as a participant in this tournament.';
        });
        return;
      }

      // No existing registration found
      setState(() {
        _existingStatus = null;
      });
    } catch (e) {
      // Ignore errors in check
      setState(() {
        _existingStatus = null;
      });
    } finally {
      setState(() {
        _isCheckingExisting = false;
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (_existingStatus != null && !_existingStatus!.contains('Checking')) {
      context.showWarningSnackbar(
        'Cannot register - please check the status message',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tournamentService = ref.read(tournamentServiceProvider);

      await tournamentService.createPublicRegistrationRequest(
        tournamentId: widget.tournament.id,
        tournamentName: widget.tournament.name,
        customerName: name,
        customerPhoneNumber: phone,
        entryFee: widget.tournament.entryFee,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
        context.showSuccessSnackbar(
          'Registration request submitted for $name! We will contact you soon.',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final isMobile = AppTheme.isMobile(context);
    final tournament = widget.tournament;
    final onHeader = cs.onPrimary;

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 16 : 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: onHeader.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: onHeader,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Register for Tournament',
                          style: TextStyle(
                            color: onHeader,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          tournament.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: onHeader.withValues(alpha: 0.92),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: onHeader),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tournament Info Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.subtleDividerColor(theme),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              context,
                              Icons.sports,
                              'Game',
                              tournament.gameType.displayName,
                            ),
                            Divider(height: 16, color: AppTheme.subtleDividerColor(theme)),
                            _buildInfoRow(
                              context,
                              Icons.account_tree,
                              'Format',
                              tournament.format.displayName,
                            ),
                            Divider(height: 16, color: AppTheme.subtleDividerColor(theme)),
                            _buildInfoRow(
                              context,
                              Icons.calendar_today,
                              'Start Date',
                              DateFormat(
                                'EEE, MMM d, y',
                              ).format(tournament.startDate),
                            ),
                            Divider(height: 16, color: AppTheme.subtleDividerColor(theme)),
                            _buildInfoRow(
                              context,
                              Icons.people,
                              'Participants',
                              '${tournament.currentParticipantCount}/${tournament.maxParticipantsDisplay}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Entry Fee & Prize Pool
                      Row(
                        children: [
                          // Entry Fee
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: sem.infoContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sem.info.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.currency_rupee,
                                    color: sem.onInfoContainer,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Entry Fee',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: sem.onInfoContainer.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tournament.entryFee > 0
                                        ? '₹${tournament.entryFee.toStringAsFixed(0)}'
                                        : 'FREE',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: tournament.entryFee > 0
                                          ? sem.onInfoContainer
                                          : sem.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Prize Pool
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    sem.warningContainer,
                                    sem.warningContainer.withValues(
                                      alpha: 0.75,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sem.warning.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    color: sem.onWarningContainer,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Prize Pool',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: sem.onWarningContainer.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tournament.prizePool > 0
                                        ? '₹${tournament.prizePool.toStringAsFixed(0)}'
                                        : 'TBD',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: sem.onWarningContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Your Details Section
                      Text(
                        'Your Details',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'Enter your name',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          // Clear existing status when user changes input
                          if (_existingStatus != null) {
                            setState(() => _existingStatus = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Phone Number Field
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number *',
                          hintText: '10 digit mobile number',
                          prefixIcon: const Icon(Icons.phone),
                          prefixText: '+91 ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          suffixIcon: _isCheckingExisting
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (value.trim().length != 10) {
                            return 'Phone number must be 10 digits';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          // Check for existing registration when phone is complete
                          if (value.length == 10) {
                            _checkExistingRegistration(value);
                          } else if (_existingStatus != null) {
                            setState(() => _existingStatus = null);
                          }
                        },
                      ),

                      // Existing registration status
                      if (_existingStatus != null &&
                          !_existingStatus!.contains('Checking')) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: sem.warningContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sem.warning.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: sem.onWarningContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _existingStatus!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: sem.onWarningContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Optional Note
                      TextFormField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          labelText: 'Note (Optional)',
                          hintText: 'Any message for the organizer',
                          prefixIcon: const Icon(Icons.note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Info text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sem.infoContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info,
                              size: 18,
                              color: sem.onInfoContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your registration request will be reviewed by our staff. '
                                'You will receive a confirmation call once approved.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: sem.onInfoContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                color: cs.surfaceContainerLow,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text(AppStrings.cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed:
                        _isLoading ||
                            _isCheckingExisting ||
                            (_existingStatus != null &&
                                !_existingStatus!.contains('Checking'))
                        ? null
                        : _submitRegistration,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Submit Registration'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
