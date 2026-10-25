import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/tournament.dart';
import '../../models/tournament_registration.dart';
import '../../constants/payment_mode.dart';
import '../../providers/tournament_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';

class RefundRegistrationDialog extends ConsumerStatefulWidget {
  final TournamentRegistration registration;
  final Tournament tournament;

  const RefundRegistrationDialog({
    super.key,
    required this.registration,
    required this.tournament,
  });

  @override
  ConsumerState<RefundRegistrationDialog> createState() =>
      _RefundRegistrationDialogState();
}

class _RefundRegistrationDialogState
    extends ConsumerState<RefundRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  PaymentMethod _refundMethod = PaymentMethod.cash;
  bool _refundToCredits = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final paid = widget.registration.amountPaid ?? widget.registration.entryFee;
    _amountController.text = paid.toStringAsFixed(0);

    // Default method: original method if present
    final orig = widget.registration.paymentMethod;
    if (orig != null) {
      _refundMethod = orig;
      _refundToCredits = orig == PaymentMethod.credits;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitRefund() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(appUserProvider).value;
      if (currentUser == null) throw Exception('User not authenticated');

      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final note = _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null;

      await ref
          .read(tournamentServiceProvider)
          .refundTournamentRegistration(
            registrationId: widget.registration.id,
            refundAmount: amount,
            refundToCredits: _refundToCredits,
            refundPaymentMethod: _refundMethod,
            refundedBy: currentUser,
            note: note,
          );

      if (mounted) Navigator.pop(context, true);
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
    final isMobile = AppTheme.isMobile(context);

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.undo, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Refund Registration',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.registration.customerName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.registration.customerPhone != null)
                Text(
                  widget.registration.customerPhone!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Tournament: ${widget.tournament.name}',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Refund Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter amount';
                  final amt = double.tryParse(v);
                  if (amt == null || amt < 0) return 'Invalid amount';
                  if (amt >
                      (widget.registration.amountPaid ??
                          widget.registration.entryFee)) {
                    return 'Cannot exceed paid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (ctx) {
                        final theme = Theme.of(ctx);
                        final methodItems = PaymentMethod.values
                            .map(
                              (m) => DropdownMenuItem<PaymentMethod>(
                                value: m,
                                child: Text(m.displayName),
                              ),
                            )
                            .toList();
                        return DropdownButtonFormField<PaymentMethod>(
                          initialValue: _refundMethod,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Refund Method',
                            prefixIcon: Icon(Icons.payment),
                          ),
                          items: methodItems,
                          selectedItemBuilder: (context) =>
                              AppTheme.dropdownSelectedItemBuilders(
                                theme,
                                methodItems,
                              ),
                          onChanged: _refundToCredits
                              ? null
                              : (val) => setState(() => _refundMethod = val!),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Refund to credits?'),
                      Switch(
                        value: _refundToCredits,
                        onChanged: (val) {
                          setState(() {
                            _refundToCredits = val;
                            if (val) _refundMethod = PaymentMethod.credits;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Refund Note (optional)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitRefund,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Confirm Refund'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
