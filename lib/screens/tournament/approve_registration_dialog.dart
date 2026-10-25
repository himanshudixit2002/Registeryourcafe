import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/tournament.dart';
import '../../models/tournament_registration.dart';
import '../../models/customer.dart';
import '../../auth/permission_id.dart';
import '../../providers/tournament_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/dialogs/customer_selection_dialog.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../customers/add_customer_screen.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class ApproveRegistrationDialog extends ConsumerStatefulWidget {
  final TournamentRegistration registration;
  final Tournament tournament;

  const ApproveRegistrationDialog({
    super.key,
    required this.registration,
    required this.tournament,
  });

  @override
  ConsumerState<ApproveRegistrationDialog> createState() =>
      _ApproveRegistrationDialogState();
}

class _ApproveRegistrationDialogState
    extends ConsumerState<ApproveRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _isLoading = false;

  // For public registrations - allow linking to existing customer
  Customer? _selectedCustomer;
  bool _createNewCustomer = true; // Default to creating new customer

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
    final registration = widget.registration;
    final tournament = widget.tournament;
    final canNavCustomers =
        ref.watchResolvedPermissions().can(PermissionIds.navCustomers);

    if (registration.isPublicRegistration &&
        !canNavCustomers &&
        _createNewCustomer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _createNewCustomer = false);
        }
      });
    }

    if (!ref.watchResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You do not have permission to approve tournament registrations.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppStrings.close),
              ),
            ],
          ),
        ),
      );
    }

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
                color: sem.successContainer,
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
                      color: sem.success.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: sem.onSuccessContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approve Registration',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Confirm payment and add to tournament',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
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
                      // Registrant Info
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sem.infoContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sem.info.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                      registration.customerName.isNotEmpty
                                          ? registration.customerName[0]
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            registration.customerName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (registration
                                              .isPublicRegistration) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: cs.tertiaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Public',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: cs.onTertiaryContainer,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (registration.customerPhone != null)
                                        Text(
                                          '+91 ${registration.customerPhone!}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // For public registrations - show customer linking options
                            if (registration.isPublicRegistration) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Text(
                                'Link to Customer Account',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Option: Create new customer (needs nav.customers)
                              InkWell(
                                onTap: () {
                                  if (!canNavCustomers) {
                                    context.showErrorSnackbar(
                                      'You do not have permission to add customers.',
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _createNewCustomer = true;
                                    _selectedCustomer = null;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _createNewCustomer && canNavCustomers
                                        ? sem.successContainer
                                        : cs.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _createNewCustomer &&
                                              canNavCustomers
                                          ? sem.success.withValues(alpha: 0.45)
                                          : cs.outlineVariant,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _createNewCustomer &&
                                                    canNavCustomers
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_unchecked,
                                            size: 20,
                                            color: _createNewCustomer &&
                                                    canNavCustomers
                                                ? sem.success
                                                : cs.outline,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Create new customer account',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _createNewCustomer &&
                                                        canNavCustomers
                                                    ? sem.onSuccessContainer
                                                    : cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.person_add,
                                            size: 18,
                                            color: _createNewCustomer &&
                                                    canNavCustomers
                                                ? sem.success
                                                : cs.outline,
                                          ),
                                        ],
                                      ),
                                      if (!canNavCustomers) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Requires access to the Customers area.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.error,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Option: Link to existing customer
                              InkWell(
                                onTap: _selectExistingCustomer,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: !_createNewCustomer
                                        ? sem.infoContainer
                                        : cs.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !_createNewCustomer
                                          ? sem.info.withValues(alpha: 0.45)
                                          : cs.outlineVariant,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        !_createNewCustomer
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 20,
                                        color: !_createNewCustomer
                                            ? sem.info
                                            : cs.outline,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _selectedCustomer != null
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _selectedCustomer!.name,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          sem.onInfoContainer,
                                                    ),
                                                  ),
                                                  if (_selectedCustomer!
                                                      .phoneNumber
                                                      .isNotEmpty)
                                                    Text(
                                                      _selectedCustomer!
                                                          .phoneNumber,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: cs
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                ],
                                              )
                                            : Text(
                                                'Link to existing customer',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                      ),
                                      Icon(
                                        Icons.search,
                                        size: 18,
                                        color: !_createNewCustomer
                                            ? sem.info
                                            : cs.outline,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tournament Info
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sem.warningContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sem.warning.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.emoji_events,
                              color: sem.onWarningContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tournament.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${tournament.gameType.displayName} • ${tournament.format.displayName}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Payment Section Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.payment,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Payment Details',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Entry Fee Display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tournament Entry Fee:'),
                            Text(
                              tournament.entryFee > 0
                                  ? '₹${tournament.entryFee.toStringAsFixed(0)}'
                                  : 'FREE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: tournament.entryFee > 0
                                    ? cs.primary
                                    : sem.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount Paid
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Amount Collected (₹)',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          hintText:
                              'Entry fee: ₹${tournament.entryFee.toStringAsFixed(0)}',
                          helperText:
                              'Confirm the amount collected from participant',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (tournament.entryFee > 0) {
                            final amount = double.tryParse(value ?? '');
                            if (amount == null || amount < 0) {
                              return 'Please enter a valid amount';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Payment Method Selection
                      Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: PaymentMethod.values.map((method) {
                          final isSelected = _paymentMethod == method;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: method != PaymentMethod.values.last
                                    ? 8
                                    : 0,
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _paymentMethod = method);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? cs.primary.withValues(
                                            alpha: 0.1,
                                          )
                                        : cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? cs.primary
                                          : cs.outlineVariant,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        _getPaymentIcon(method),
                                        color: isSelected
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                        size: 22,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        method.displayName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? cs.primary
                                              : cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Payment Note (optional)
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: 'Payment Note (Optional)',
                          prefixIcon: Icon(Icons.note),
                          hintText: 'Any additional notes about payment',
                        ),
                        maxLines: 2,
                      ),

                      // Request Note Display
                      if (registration.requestNote != null &&
                          registration.requestNote!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.subtleDividerColor(theme),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registrant\'s Note:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                registration.requestNote!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                children: [
                  // Reject Button
                  TextButton.icon(
                    onPressed: _isLoading ? null : () => _showRejectDialog(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(foregroundColor: cs.error),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text(AppStrings.cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _approveRegistration,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Approve & Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sem.success,
                      foregroundColor: sem.onSuccess,
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

  Future<void> _selectExistingCustomer() async {
    final customer = await showDialog<Customer>(
      context: context,
      builder: (_) => CustomerSelectionDialog(
        customers: ref.read(tenantRefProvider)!.customers(),
      ),
    );

    if (customer != null) {
      setState(() {
        _selectedCustomer = customer;
        _createNewCustomer = false;
      });
    }
  }

  Future<void> _approveRegistration() async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      if (mounted) {
        context.showErrorSnackbar(
          'You do not have permission to approve registrations.',
        );
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // For public registrations, validate customer selection
    if (widget.registration.isPublicRegistration &&
        !_createNewCustomer &&
        _selectedCustomer == null) {
      context.showWarningSnackbar(
        'Please select an existing customer or choose to create new',
      );
      return;
    }

    try {
      final currentUser = ref.read(appUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final note = _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null;

      // For public registrations with "create new customer" option:
      // Always open AddCustomerScreen to create the customer first, then approve.
      if (widget.registration.isPublicRegistration && _createNewCustomer) {
        if (!ref.readResolvedPermissions().can(PermissionIds.navCustomers)) {
          if (mounted) {
            context.showErrorSnackbar(
              'You do not have permission to add customers.',
            );
          }
          return;
        }
        setState(() => _isLoading = false); // pause loading while navigating

        final result = await Navigator.push<dynamic>(
          context,
          AppMaterialPageRoute<void>(
            builder: (_) => AddCustomerScreen(
              initialName: widget.registration.customerName,
              initialPhone: widget.registration.customerPhone,
              returnCustomer: true,
            ),
          ),
        );

        if (!mounted) return;

        if (result is! Customer) {
          // User cancelled or something went wrong; do not approve
          return;
        }

        setState(() => _isLoading = true);

        await ref
            .read(tournamentServiceProvider)
            .approvePublicRegistrationRequest(
              registrationId: widget.registration.id,
              approvedBy: currentUser,
              paymentMethod: _paymentMethod,
              amountPaid: amount,
              existingCustomer: result,
              paymentNote: note,
            );
      } else if (widget.registration.isPublicRegistration) {
        // Using manually selected existing customer
        setState(() => _isLoading = true);
        await ref
            .read(tournamentServiceProvider)
            .approvePublicRegistrationRequest(
              registrationId: widget.registration.id,
              approvedBy: currentUser,
              paymentMethod: _paymentMethod,
              amountPaid: amount,
              existingCustomer: _selectedCustomer,
              paymentNote: note,
            );
      } else {
        // Non-public registration
        setState(() => _isLoading = true);
        await ref
            .read(tournamentServiceProvider)
            .approveRegistrationRequest(
              registrationId: widget.registration.id,
              approvedBy: currentUser,
              paymentMethod: _paymentMethod,
              amountPaid: amount,
              paymentNote: note,
            );
      }

      if (mounted) {
        Navigator.pop(context, true);
        context.showSuccessSnackbar(
          '${widget.registration.customerName} approved and added to tournament!',
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

  Future<void> _showRejectDialog() async {
    if (!ref.readResolvedPermissions().can(PermissionIds.opsTournamentManage)) {
      if (mounted) {
        context.showErrorSnackbar('You do not have permission to reject registrations.');
      }
      return;
    }

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Registration?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to reject ${widget.registration.customerName}\'s registration?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Why is this registration being rejected?',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(appUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await ref
          .read(tournamentServiceProvider)
          .rejectRegistrationRequest(
            registrationId: widget.registration.id,
            rejectedBy: currentUser,
            reason: reasonController.text.trim().isNotEmpty
                ? reasonController.text.trim()
                : null,
          );

      if (mounted) {
        Navigator.pop(context, true);
        context.showWarningSnackbar(
          '${widget.registration.customerName}\'s registration rejected',
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
