import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/customer.dart';
import '../../models/membership_type_definition.dart';
import '../../models/venue_ui_config.dart';
import 'dart:math';
import 'dart:async';
import '../../providers/company_module_provider.dart';
import '../../providers/customer_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../models/credit_transaction.dart';
import '../../services/membership_service.dart';
import '../../services/whatsapp_service.dart';
import '../../auth/permission_id.dart';
import '../../providers/auth_provider.dart';
import '../../providers/membership_type_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/permission_denied_scaffold.dart';
import '../../widgets/customer_ui_components.dart';
import '../../widgets/glass_panel.dart';
import '../../utils/app_logger.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  /// Optional initial name to pre-fill (e.g., from tournament registration)
  final String? initialName;

  /// Optional initial phone to pre-fill (e.g., from tournament registration)
  final String? initialPhone;

  /// If true, returns the created customer instead of just popping
  final bool returnCustomer;

  const AddCustomerScreen({
    super.key,
    this.initialName,
    this.initialPhone,
    this.returnCustomer = false,
  });

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _membershipIdController = TextEditingController();

  // Focus node and error message for duplicate phone validation
  final _phoneFocusNode = FocusNode();
  String? _phoneErrorMessage;
  Timer? _phoneDebounce;

  String _selectedMembershipTypeId = kRegularMembershipTypeId;
  final Set<PaymentMethod> _selectedPaymentMethods = {PaymentMethod.cash};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen for focus changes on phone field to trigger duplicate check
    _phoneFocusNode.addListener(_onPhoneFocusChange);

    // Pre-fill initial values if provided (e.g., from tournament registration)
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _phoneController.text = widget.initialPhone!;
    }
  }

  /*
  // This approach is inefficient with pagination as it requires loading all customers.
  Future<void> _fetchCustomers() async {
    // Reading the new provider requires handling its AsyncValue states.
    final customersAsync = ref.read(customerListProvider);
    customersAsync.whenData((customers) {
       if (mounted) {
        setState(() {
          _allCustomers = customers;
        });
      }
    });
  }
  */

  Future<void> _generateMembershipId(MembershipTypeDefinition? def) async {
    if (def == null || def.isRegular) {
      _membershipIdController.clear();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) {
        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.errorContainer,
              content: Text(
                'No company context',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          );
        }
        return;
      }
      final newId = await MembershipService.generateMembershipId(tenant, def);
      _membershipIdController.text = newId;
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.errorContainer,
            content: Text(
              'Could not generate Membership ID: ${e.toString()}',
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pincodeController.dispose();
    _membershipIdController.dispose();
    _phoneFocusNode.dispose();
    _phoneDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < AppTheme.kMobileBreakpoint;
    final isDesktop = screenSize.width > 1024;

    if (!ref.watchResolvedPermissions().can(PermissionIds.navCustomers)) {
      final vk = ref.watch(venueKindProvider);
      return PermissionDeniedScaffold(
        title: 'Add ${vk.customerSingularCapitalized}',
        message: 'You do not have access to ${vk.customerPlural}.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Add ${ref.watch(venueKindProvider).customerSingularCapitalized}',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        centerTitle: isMobile,
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            height: isMobile ? 120 : 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.15),
                  theme.colorScheme.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SingleChildScrollView(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile
                  ? 12
                  : (isDesktop ? screenSize.width * 0.15 : 24),
              vertical: isMobile ? 12 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : 800),
                child: _buildCustomerDetailsCard(theme, isDesktop, isMobile),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: theme.colorScheme.shadow.withValues(alpha: 0.35),
              child: const Center(child: LoadingIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerDetailsCard(
    ThemeData theme,
    bool isDesktop,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : (isDesktop ? 32 : 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: theme.colorScheme.primary,
                    size: isMobile ? 22 : (isDesktop ? 28 : 24),
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Details',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : (isDesktop ? 24 : 20),
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (!isMobile)
                        Text(
                          'Fill in the customer information below',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 20 : (isDesktop ? 32 : 24)),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildResponsiveGrid([
                    _buildFormField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      isRequired: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter customer name';
                        }
                        return null;
                      },
                    ),
                    _buildFormField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            !value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    _buildFormField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      isRequired: true,
                      keyboardType: TextInputType.phone,
                      focusNode: _phoneFocusNode,
                      onChanged: (_) {
                        if (_phoneErrorMessage != null) {
                          setState(() {
                            _phoneErrorMessage = null;
                          });
                        }
                        _scheduleDuplicatePhoneCheck();
                      },
                      suffixIcon: _phoneErrorMessage != null
                          ? Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                            )
                          : null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (value.length < 10) {
                          return 'Phone number should be at least 10 digits';
                        }
                        if (_phoneErrorMessage != null) {
                          return _phoneErrorMessage;
                        }
                        return null;
                      },
                    ),
                    _buildFormField(
                      controller: _pincodeController,
                      label: 'Pincode',
                      icon: Icons.location_on_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            value.length != 6) {
                          return 'Pincode must be 6 digits if provided';
                        }
                        return null;
                      },
                    ),
                  ], isDesktop),
                  SizedBox(
                    height: isDesktop
                        ? AppTheme.kSpacingLarge
                        : AppTheme.kSpacingMedium,
                  ),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildMembershipSection(theme)),
                        const SizedBox(width: AppTheme.kSpacingLarge),
                        Expanded(child: _buildPaymentMethodsSection(theme)),
                      ],
                    )
                  else ...[
                    _buildMembershipSection(theme),
                    const SizedBox(height: AppTheme.kSpacingMedium),
                    _buildPaymentMethodsSection(theme),
                  ],
                  SizedBox(height: isMobile ? 24 : (isDesktop ? 40 : 32)),
                  // Submit button
                  Center(
                    child: SizedBox(
                      width: isDesktop ? 300 : double.infinity,
                      height: isMobile ? 52 : (isDesktop ? 56 : 48),
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _submitForm();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              theme.colorScheme.onPrimary
                                                  .withValues(alpha: 0.9),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Adding...',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_add_rounded,
                                      size: isMobile ? 20 : 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Add Customer',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: isMobile ? 15 : 16,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
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

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      decoration: AppTheme.inputDecoration(
        theme,
        isRequired ? '$label *' : label,
        icon,
      ).copyWith(suffixIcon: suffixIcon),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildMembershipSection(ThemeData theme) {
    final async = ref.watch(membershipTypeDefinitionsProvider);
    return async.when(
      data: (defs) {
        final options = List<MembershipTypeDefinition>.from(
          defs.where((d) => !d.isArchived),
        )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (options.isEmpty) {
          return Text(
            'No membership plans configured.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          );
        }
        final dropdownValue =
            options.any((d) => d.id == _selectedMembershipTypeId)
            ? _selectedMembershipTypeId
            : kRegularMembershipTypeId;
        final selectedDef = lookupMembershipType(defs, dropdownValue);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.card_membership_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.kSpacingMedium),
                Text(
                  'Membership Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.kSpacingSmall),
            Builder(
              builder: (ctx) {
                final membershipItems = options
                    .map(
                      (d) =>
                          DropdownMenuItem(value: d.id, child: Text(d.name)),
                    )
                    .toList();
                return DropdownButtonFormField<String>(
                  initialValue: dropdownValue,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Membership Type',
                    prefixIcon: const Icon(Icons.card_membership_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.kBorderRadiusMedium,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.kSpacingMedium,
                      vertical: AppTheme.kSpacingSmall,
                    ),
                  ),
                  items: membershipItems,
                  selectedItemBuilder: (context) =>
                      AppTheme.dropdownSelectedItemBuilders(
                        theme,
                        membershipItems,
                      ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedMembershipTypeId = value);
                      _generateMembershipId(lookupMembershipType(defs, value));
                    }
                  },
                );
              },
            ),
            if (_membershipIdController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.kSpacingSmall),
                child: AppSurface(
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  borderColor: theme.colorScheme.primary.withValues(
                    alpha: 0.35,
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.badge_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                    title: Text(
                      'Membership ID',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Text(
                      _membershipIdController.text,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            if (selectedDef != null && !selectedDef.isRegular)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.kSpacingSmall),
                child: _buildMembershipPlanDetailsCard(selectedDef),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Text(
        'Could not load membership plans: $e',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.payments_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: AppTheme.kSpacingMedium),
            Text(
              'Payment Methods',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.kSpacingSmall),
        Wrap(
          spacing: AppTheme.kSpacingSmall / 2,
          runSpacing: AppTheme.kSpacingSmall / 2,
          children: PaymentMethod.values
              .where((m) => m != PaymentMethod.credits)
              .map((method) {
                final isSelected = _selectedPaymentMethods.contains(method);
                return FilterChip(
                  label: Text(method.toString().split('.').last.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPaymentMethods
                          ..clear()
                          ..add(method);
                      } else {
                        _selectedPaymentMethods.remove(method);
                      }
                    });
                  },
                  showCheckmark: true,
                  checkmarkColor: theme.colorScheme.onPrimary,
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.kSpacingSmall,
                    vertical: AppTheme.kSpacingSmall / 2,
                  ),
                );
              })
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResponsiveGrid(List<Widget> children, bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isDesktop
            ? 4
            : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: isDesktop
                ? AppTheme.kSpacingMedium
                : AppTheme.kSpacingSmall,
            mainAxisSpacing: isDesktop
                ? AppTheme.kSpacingMedium
                : AppTheme.kSpacingSmall,
            mainAxisExtent: isDesktop ? 110 : 100,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }

  Widget _buildMembershipPlanDetailsCard(MembershipTypeDefinition plan) {
    final theme = Theme.of(context);

    return AppSurface(
      borderRadius: AppTheme.kBorderRadiusMedium,
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      borderColor: theme.colorScheme.secondary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan Benefits',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppTheme.kSpacingMedium),
          _buildPlanDetailRow(
            theme,
            Icons.price_check_rounded,
            'Membership Fee',
            '₹${plan.fee}',
          ),
          const SizedBox(height: AppTheme.kSpacingSmall),
          _buildPlanDetailRow(
            theme,
            Icons.card_giftcard_rounded,
            'Credits Added',
            '${plan.creditsToAdd} Cr',
          ),
          const SizedBox(height: AppTheme.kSpacingSmall),
          _buildPlanDetailRow(
            theme,
            Icons.date_range_rounded,
            'Validity',
            plan.durationInDays != null
                ? '${plan.durationInDays} days'
                : 'Lifetime',
          ),
        ],
      ),
    );
  }

  Widget _buildPlanDetailRow(
    ThemeData theme,
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSecondaryContainer.withValues(
              alpha: 0.1,
            ),
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusSmall),
          ),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: AppTheme.kSpacingMedium),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final membershipDefs =
        ref.read(activeMembershipTypeDefinitionsProvider).valueOrNull ?? [];
    final effectiveTypeId =
        membershipDefs.any((d) => d.id == _selectedMembershipTypeId)
        ? _selectedMembershipTypeId
        : kRegularMembershipTypeId;
    final selectedDef = lookupMembershipType(membershipDefs, effectiveTypeId);
    final paidPlan = selectedDef != null && !selectedDef.isRegular
        ? selectedDef
        : null;

    if (paidPlan != null && _selectedPaymentMethods.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.tertiaryContainer,
          content: Text(
            'Please select a payment method.',
            style: TextStyle(color: cs.onTertiaryContainer),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) {
        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.errorContainer,
              content: Text(
                'No company context',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }
      // --------------------------
      // Prevent duplicate phone numbers
      // --------------------------
      final String phone = _phoneController.text.trim();
      final dupSnap = await tenant
          .customers()
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();
      if (dupSnap.docs.isNotEmpty) {
        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.tertiaryContainer,
              content: Text(
                'A customer with this phone number already exists.',
                style: TextStyle(color: cs.onTertiaryContainer),
              ),
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }
      // --------------------------
      final now = DateTime.now();

      final double initialManualCredits =
          0.0; // Initial credits removed from UI; always zero.
      double totalCredits = initialManualCredits;
      double topUpAmountForLog = initialManualCredits;

      if (paidPlan != null) {
        totalCredits += paidPlan.creditsToAdd;
      }

      // Since manual credits are no longer entered, topUpAmountForLog stays 0.
      topUpAmountForLog = 0;

      final PaymentMethod topUpMethodForLog = _selectedPaymentMethods.isNotEmpty
          ? _selectedPaymentMethods.first
          : PaymentMethod.cash;

      DateTime? membershipExpiry;
      if (paidPlan != null && paidPlan.durationInDays != null) {
        membershipExpiry = now.add(Duration(days: paidPlan.durationInDays!));
      }

      final String? emailValue = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null;
      final String? pincodeValue = _pincodeController.text.trim().isNotEmpty
          ? _pincodeController.text.trim()
          : null;

      // Generate 6-digit credit code
      final String generatedCreditCode = (Random().nextInt(900000) + 100000)
          .toString();

      final newDocRef = await tenant.customers().add({
        'name': _nameController.text.trim(),
        'email': emailValue,
        'phoneNumber': _phoneController.text.trim(),
        'pincode': pincodeValue,
        'credits': totalCredits,
        'membershipType': effectiveTypeId,
        'membershipFeePaid': paidPlan?.fee,
        'membershipStartDate': paidPlan != null
            ? Timestamp.fromDate(now)
            : null,
        'membershipExpiry': membershipExpiry != null
            ? Timestamp.fromDate(membershipExpiry)
            : null,
        if (topUpAmountForLog > 0 || paidPlan == null)
          'lastCreditTopUp': {
            'date': Timestamp.fromDate(now),
            'amount': topUpAmountForLog,
            'method': topUpMethodForLog
                .toString()
                .split('.')
                .last
                .toLowerCase(),
            'type': paidPlan == null ? 'initial_balance' : 'additional_top_up',
          },
        'preferredPaymentMethods': _selectedPaymentMethods
            .map((method) => method.toString().split('.').last.toLowerCase())
            .toList(),
        'alerts': {'lowCredit': false, 'membershipExpiry': false},
        'membershipId': _membershipIdController.text.trim().isNotEmpty
            ? _membershipIdController.text.trim()
            : null,
        'membershipIds': [
          if (_membershipIdController.text.trim().isNotEmpty)
            {
              'id': _membershipIdController.text.trim(),
              'type': effectiveTypeId,
              'active': true,
            },
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'creditCode': generatedCreditCode,
      });

      if (mounted) {
        // Show confirmation dialog with option to send WhatsApp message.
        final bool sendWhatsApp =
            await showDialog<bool>(
              context: context,
              barrierDismissible: false, // User must choose an action
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text('Customer Added'),
                  content: const Text(
                    'Customer has been added successfully. Do you want to send the credit code via WhatsApp?',
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('No, Just Close'),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Send WhatsApp & Close'),
                    ),
                  ],
                );
              },
            ) ??
            false;

        if (mounted) {
          if (sendWhatsApp) {
            try {
              await WhatsAppService.sendCreditCode(
                rawPhone: _phoneController.text.trim(),
                customerName: _nameController.text.trim(),
                creditCode: generatedCreditCode,
              );
            } catch (e) {
              if (mounted) {
                final cs = Theme.of(context).colorScheme;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: cs.errorContainer,
                    content: Text(
                      'Could not open WhatsApp: $e',
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                );
              }
            }
          }
          // Clear cached customers so the newly added customer appears in search delegates.
          if (mounted) {
            CustomerCacheManager.clearCache();

            await ref.read(customerListProvider.notifier).refresh();
            if (!mounted) return;

            // If returnCustomer is true, fetch and return the created customer
            if (widget.returnCustomer) {
              final customerDoc = await newDocRef.get();
              if (mounted) {
                if (customerDoc.exists) {
                  final customer = Customer.fromFirestore(customerDoc);
                  Navigator.pop(context, customer);
                } else {
                  Navigator.pop(context, true);
                }
              }
            } else {
              Navigator.pop(context, true);
            }
          }
        }
      }

      // Record initial credits as credit transactions for audit trail
      try {
        final appUser = ref
            .read(appUserProvider)
            .maybeWhen(data: (u) => u, orElse: () => null);
        final creditTxCollection = newDocRef.collection('credit_transactions');

        // 1. Manual credits entered for regular customer (initial balance)
        if (initialManualCredits > 0) {
          await creditTxCollection.add({
            'date': Timestamp.fromDate(now),
            'amount': initialManualCredits,
            'type': CreditTransactionType.initialBalance.name,
            'method': 'credits',
            'note': 'Initial balance on customer creation',
            if (appUser != null) 'performedById': appUser.uid,
            if (appUser != null) 'performedByName': appUser.name,
            if (appUser != null) 'performedByRole': appUser.role.name,
            'reference': {
              'type': 'customer_creation',
              'id': newDocRef.id,
              'paymentMethod': topUpMethodForLog.name.toLowerCase(),
            },
          });
        }

        // 2. Credits granted via membership purchase
        if (paidPlan != null && paidPlan.creditsToAdd > 0) {
          await creditTxCollection.add({
            'date': Timestamp.fromDate(now),
            'amount': paidPlan.creditsToAdd.toDouble(),
            'type': CreditTransactionType.membership.name,
            'method': 'credits',
            'note': 'Membership credits: ${paidPlan.name.toUpperCase()}',
            if (appUser != null) 'performedById': appUser.uid,
            if (appUser != null) 'performedByName': appUser.name,
            if (appUser != null) 'performedByRole': appUser.role.name,
            'reference': {
              'type': 'membership',
              'id': _membershipIdController.text.trim().isNotEmpty
                  ? _membershipIdController.text.trim()
                  : newDocRef.id,
              'membershipType': paidPlan.id,
            },
          });
        }
      } catch (e, st) {
        AppLogger.warning(
          'Credit transaction log skipped during add customer: $e',
          tag: 'AddCustomer',
        );
        AppLogger.debug('$st', tag: 'AddCustomer');
        // Credit transaction recording failure shouldn't block customer creation
      }

      // Record revenue in membership_payments
      if (paidPlan == null) {
        if (topUpAmountForLog > 0) {
          await tenant.membershipPayments().add({
            'createdAt': Timestamp.fromDate(now),
            'amount': topUpAmountForLog,
            'paymentMethod': topUpMethodForLog
                .toString()
                .split('.')
                .last
                .toLowerCase(),
            'customerId': newDocRef.id,
            'type': 'manualTopUp',
          });
        }
      } else {
        await tenant.membershipPayments().add({
          'createdAt': Timestamp.fromDate(now),
          'amount': paidPlan.fee,
          'paymentMethod': topUpMethodForLog
              .toString()
              .split('.')
              .last
              .toLowerCase(),
          'customerId': newDocRef.id,
          'type': 'membership',
        });
      }
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cs.errorContainer,
            content: Text(
              'Failed to add customer: ${e.toString()}',
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /*
  // Placeholder implementations to avoid compilation errors
  Widget _buildMembershipCard(ThemeData theme) {
    // The membership and payment sections are already included within the main customer details
    // card. This placeholder prevents missing-method errors while we refactor the UI.
    return const SizedBox.shrink();
  }

  Widget _buildPaymentMethodsCard(ThemeData theme) {
    // Payment method selection is handled in the main customer details card.
    return const SizedBox.shrink();
  }
  */

  // --------------------------------------------
  // Duplicate phone validation helpers
  // --------------------------------------------
  void _onPhoneFocusChange() {
    if (!_phoneFocusNode.hasFocus) {
      _checkDuplicatePhone();
    }
  }

  // Schedule debounce check
  void _scheduleDuplicatePhoneCheck() {
    _phoneDebounce?.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _checkDuplicatePhone();
      }
    });
  }

  Future<void> _checkDuplicatePhone() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) return; // Skip invalid / incomplete input

    try {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) return;
      final dupSnap = await tenant
          .customers()
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();
      if (dupSnap.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _phoneErrorMessage = 'Phone number already in use.';
          });
          _formKey.currentState?.validate();
        }
      } else {
        if (_phoneErrorMessage != null && mounted) {
          setState(() {
            _phoneErrorMessage = null;
          });
          _formKey.currentState?.validate();
        }
      }
    } catch (e, st) {
      AppLogger.debug(
        'Duplicate phone check failed (non-blocking): $e\n$st',
        tag: 'AddCustomer',
      );
    }
  }
}
