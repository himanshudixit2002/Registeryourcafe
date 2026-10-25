import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../utils/snackbar_helper.dart';
import '../../auth/permission_id.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';

class EditCustomerScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const EditCustomerScreen({super.key, required this.customer});

  @override
  ConsumerState<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends ConsumerState<EditCustomerScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _pincodeController;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _emailController = TextEditingController(text: widget.customer.email ?? '');
    _phoneController = TextEditingController(text: widget.customer.phoneNumber);
    _pincodeController = TextEditingController(
      text: widget.customer.pincode ?? '',
    );

    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomerChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await HapticFeedback.mediumImpact();

    try {
      final String? emailValue = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null;
      final String? pincodeValue = _pincodeController.text.trim().isNotEmpty
          ? _pincodeController.text.trim()
          : null;

      final Map<String, dynamic> updatedData = {
        'name': _nameController.text.trim(),
        'email': emailValue,
        'phoneNumber': _phoneController.text.trim(),
        'pincode': pincodeValue,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) {
        if (mounted) {
          context.showErrorSnackbar('No company context');
        }
        return;
      }
      await tenant.customers().doc(widget.customer.id).update(updatedData);

      if (mounted) {
        context.showSuccessSnackbar('Customer updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.opsCustomersAdmin)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Customer')),
        body: const Center(
          child: Text('You do not have permission to edit customers.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final maxWidth = isMobile ? double.infinity : 500.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Customer'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: theme.colorScheme.onSurface,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SizedBox(
                  width: maxWidth,
                  child: Column(
                    children: [
                      // Customer Avatar
                      _buildCustomerAvatar(theme),
                      const SizedBox(height: 16),
                      Text(
                        widget.customer.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.customer.membershipId != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.customer.membershipId!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Form Card
                      AppCard(
                        padding: EdgeInsets.all(isMobile ? 20 : 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSectionHeader('Personal Information'),
                              const SizedBox(height: 16),
                              _buildInputField(
                                controller: _nameController,
                                label: 'Full Name',
                                icon: Icons.person_outline_rounded,
                                hint: 'Enter full name',
                                required: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildInputField(
                                controller: _phoneController,
                                label: 'Phone Number',
                                icon: Icons.phone_outlined,
                                hint: '+91 XXXXX XXXXX',
                                required: true,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Phone is required';
                                  }
                                  if (value.length < 10) {
                                    return 'Min 10 digits';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              _buildSectionHeader('Optional Details'),
                              const SizedBox(height: 16),
                              _buildInputField(
                                controller: _emailController,
                                label: 'Email Address',
                                icon: Icons.email_outlined,
                                hint: 'email@example.com',
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value != null &&
                                      value.isNotEmpty &&
                                      !value.contains('@')) {
                                    return 'Invalid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildInputField(
                                controller: _pincodeController,
                                label: 'Pincode',
                                icon: Icons.location_on_outlined,
                                hint: '6-digit pincode',
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value != null &&
                                      value.isNotEmpty &&
                                      value.length != 6) {
                                    return 'Must be 6 digits';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),
                              _buildSaveButton(theme),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerAvatar(ThemeData theme) {
    final initials = widget.customer.name.isNotEmpty
        ? widget.customer.name[0].toUpperCase()
        : '?';

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: cs.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: cs.onSurfaceVariant.withValues(alpha: 0.72),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: cs.onSurfaceVariant.withValues(alpha: 0.85),
            ),
            filled: true,
            fillColor: cs.surfaceContainer.withValues(alpha: 0.65),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: cs.outline.withValues(alpha: 0.35),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: cs.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: cs.error.withValues(alpha: 0.8),
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveCustomerChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: _isLoading ? 0 : 2,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        child: _isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.onPrimary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_rounded, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
