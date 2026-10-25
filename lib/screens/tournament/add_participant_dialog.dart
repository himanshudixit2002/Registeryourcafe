import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/tournament.dart';
import '../../models/customer.dart';
import '../../providers/tournament_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/dialogs/customer_selection_dialog.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class AddParticipantDialog extends ConsumerStatefulWidget {
  final Tournament tournament;

  const AddParticipantDialog({super.key, required this.tournament});

  @override
  ConsumerState<AddParticipantDialog> createState() =>
      _AddParticipantDialogState();
}

class _AddParticipantDialogState extends ConsumerState<AddParticipantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _isLoading = false;
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.tournament.entryFee.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final isMobile = AppTheme.isMobile(context);
    final tournament = widget.tournament;

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
                color: sem.infoContainer,
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
                      color: sem.info.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_add,
                      color: sem.onInfoContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Participant',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          tournament.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
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
                      // Customer Selection
                      Text(
                        'Select Customer',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_selectedCustomer == null)
                        InkWell(
                          onTap: _selectCustomer,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: cs.outlineVariant),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Icon(
                                    Icons.person_add,
                                    color: cs.outline,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Tap to select customer',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: cs.outline,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: sem.infoContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sem.info.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: sem.info.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Center(
                                  child: Text(
                                    _selectedCustomer!.name.isNotEmpty
                                        ? _selectedCustomer!.name[0]
                                              .toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: sem.onInfoContainer,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCustomer!.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_selectedCustomer!
                                        .phoneNumber
                                        .isNotEmpty)
                                      Text(
                                        _selectedCustomer!.phoneNumber,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() => _selectedCustomer = null);
                                },
                                icon: const Icon(Icons.close, size: 20),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Payment Section
                      Text(
                        'Payment Details',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Entry fee info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Entry Fee: ',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            Text(
                              tournament.entryFee > 0
                                  ? '₹${tournament.entryFee.toStringAsFixed(0)}'
                                  : 'FREE',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Payment method
                      Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PaymentMethod.values.map((method) {
                          final isSelected = _paymentMethod == method;
                          return ChoiceChip(
                            label: Text(method.displayName),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _paymentMethod = method);
                              HapticFeedback.selectionClick();
                            },
                            selectedColor: cs.primary.withValues(alpha: 0.15),
                            avatar: Icon(
                              _getPaymentIcon(method),
                              size: 16,
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount Received',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          helperText: 'Amount collected from participant',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount < 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Note (optional)
                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Note (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          hintText: 'Any additional notes...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text(AppStrings.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _selectedCustomer == null
                          ? null
                          : _addParticipant,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add),
                      label: Text(_isLoading ? 'Adding...' : 'Add Participant'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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

  IconData _getPaymentIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.upi:
        return Icons.qr_code;
      case PaymentMethod.credits:
        return Icons.account_balance_wallet;
    }
  }

  Future<void> _selectCustomer() async {
    final customer = await showDialog<Customer>(
      context: context,
      builder: (_) => CustomerSelectionDialog(
        customers: ref.read(tenantRefProvider)!.customers(),
      ),
    );

    if (customer != null) {
      setState(() => _selectedCustomer = customer);
    }
  }

  Future<void> _addParticipant() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      context.showWarningSnackbar('Please select a customer');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appUser = ref.read(appUserProvider).value;
      if (appUser == null) {
        throw Exception('User not authenticated');
      }

      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final note = _noteController.text.trim();

      // Use the service to add participant with payment
      await ref
          .read(tournamentServiceProvider)
          .addParticipantWithPayment(
            tournamentId: widget.tournament.id,
            customer: _selectedCustomer!,
            amountPaid: amount,
            paymentMethod: _paymentMethod,
            approvedBy: appUser,
            note: note.isNotEmpty ? note : null,
          );

      if (mounted) {
        Navigator.pop(context, true);
        context.showSuccessSnackbar(
          '${_selectedCustomer!.name} added with ₹${amount.toStringAsFixed(0)} payment',
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
}
