import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:registeryourcafe/auth/permission_id.dart';
import 'package:registeryourcafe/models/company_role.dart';
import 'package:registeryourcafe/providers/auth_provider.dart';
import 'package:registeryourcafe/providers/company_module_provider.dart';
import 'package:registeryourcafe/providers/permissions_provider.dart';
import 'package:registeryourcafe/providers/tenant_provider.dart';
import 'package:registeryourcafe/providers/company_roles_provider.dart';
import 'package:registeryourcafe/theme/app_theme.dart';
import 'package:registeryourcafe/utils/email_verification_guard.dart';
import 'package:registeryourcafe/utils/snackbar_helper.dart';
import 'package:registeryourcafe/widgets/app_card.dart';
import 'package:registeryourcafe/widgets/permission_denied_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateStaffScreen extends ConsumerStatefulWidget {
  const CreateStaffScreen({super.key});

  @override
  ConsumerState<CreateStaffScreen> createState() => _CreateStaffScreenState();
}

class _CreateStaffScreenState extends ConsumerState<CreateStaffScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRoleId = SystemRoleIds.staff;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (!EmailVerificationGuard.requireVerifiedForSensitiveAction(context)) {
        return;
      }
      setState(() => _isLoading = true);
      await HapticFeedback.mediumImpact();

      try {
        final companyId = ref.read(appUserProvider).valueOrNull?.companyId;
        if (companyId == null || companyId.isEmpty) {
          if (mounted) {
            context.showErrorSnackbar(
              'Your account is not linked to a company.',
            );
          }
          return;
        }
        final tenant = ref.read(tenantRefProvider);
        final ownerUid = FirebaseAuth.instance.currentUser?.uid;
        if (tenant != null && ownerUid != null) {
          final companySnap = await tenant.companyDoc().get();
          final docOwner = companySnap.data()?['ownerUid'] as String?;
          if (docOwner != ownerUid) {
            if (mounted) {
              context.showErrorSnackbar(
                'Only the workspace owner can create sign-in accounts for staff. '
                'Ask the owner to add this team member.',
              );
            }
            return;
          }
        }
        await ref.read(authServiceProvider).createStaffAccount(
              _emailController.text.trim(),
              _passwordController.text.trim(),
              _nameController.text.trim(),
              _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
              companyId: companyId,
              roleId: _selectedRoleId,
            );
        if (mounted) {
          context.showSuccessSnackbar('Staff account created successfully!');
          Navigator.of(context).pop();
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          final msg = switch (e.code) {
            'email-already-in-use' =>
              'That email is already registered. Use another or sign in.',
            'weak-password' => 'Password is too weak.',
            'invalid-email' => 'Invalid email address.',
            _ => e.message ?? e.code,
          };
          context.showErrorSnackbar(msg);
        }
      } catch (e) {
        if (mounted) {
          context.showErrorSnackbar(
            'Could not create staff. If you are not the company owner, only the owner can invite team members. $e',
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = isMobile ? screenWidth : 500.0;
    final rolesAsync = ref.watch(companyRolesListProvider);
    final canInvite =
        ref.watchResolvedPermissions().can(PermissionIds.staffInvite);
    if (!canInvite) {
      return const PermissionDeniedScaffold(
        title: 'Create Staff Account',
        message: 'You do not have permission to invite staff.',
      );
    }

    final profileAsync = ref.watch(companyProfileProvider);
    final currentUser = ref.watch(appUserProvider).valueOrNull;
    final ownerOk = profileAsync.maybeWhen(
      data: (profile) =>
          currentUser != null &&
          isRegisteredCompanyOwner(profile.ownerUid, currentUser.uid),
      orElse: () => false,
    );

    if (profileAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Staff Account')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!ownerOk) {
      return const PermissionDeniedScaffold(
        title: 'Create Staff Account',
        message:
            'Only the company owner can create staff sign-in accounts. '
            'Security rules match the registered owner on the company document—ask them to add team members from Settings or Profile.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Staff Account'),
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
                  color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header Icon
                      _buildHeaderIcon(theme),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'New Staff Member',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create account credentials for a new team member',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Form Card
                      AppCard(
                        padding: EdgeInsets.all(isMobile ? 20 : 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildInputField(
                                controller: _nameController,
                                label: 'Full Name',
                                icon: Icons.person_outline_rounded,
                                hint: 'Enter staff member\'s name',
                                validator: (value) => (value?.isEmpty ?? true)
                                    ? 'Name is required'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              _buildInputField(
                                controller: _emailController,
                                label: 'Email Address',
                                icon: Icons.email_outlined,
                                hint: 'staff@example.com',
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Email is required';
                                  }
                                  if (!value!.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildInputField(
                                controller: _phoneController,
                                label: 'Phone Number (optional)',
                                icon: Icons.phone_outlined,
                                hint: '+91 XXXXX XXXXX',
                                keyboardType: TextInputType.phone,
                                validator: (_) => null,
                              ),
                              const SizedBox(height: 20),
                              rolesAsync.when(
                                data: (roles) {
                                  final assignable = roles
                                      .where((r) => r.id != SystemRoleIds.owner)
                                      .toList();
                                  if (assignable.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  if (!assignable.any(
                                    (r) => r.id == _selectedRoleId,
                                  )) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(() {
                                              _selectedRoleId =
                                                  assignable.first.id;
                                            });
                                          }
                                        });
                                  }
                                  final roleItems = assignable
                                      .map(
                                        (r) => DropdownMenuItem<String>(
                                          value: r.id,
                                          child: Text(
                                            r.isSystem
                                                ? '${r.name} (default)'
                                                : r.name,
                                          ),
                                        ),
                                      )
                                      .toList();
                                  return DropdownButtonFormField<String>(
                                    initialValue: _selectedRoleId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Role',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: roleItems,
                                    selectedItemBuilder: (context) =>
                                        AppTheme.dropdownSelectedItemBuilders(
                                          theme,
                                          roleItems,
                                        ),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedRoleId = v);
                                      }
                                    },
                                  );
                                },
                                loading: () => const LinearProgressIndicator(),
                                error: (_, _) => const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 20),
                              _buildInputField(
                                controller: _passwordController,
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                hint: 'Min. 6 characters',
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                    HapticFeedback.selectionClick();
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (value.length < 6) {
                                    return 'Minimum 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),
                              _buildCreateButton(theme),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Info Note
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Staff will receive limited access to the system',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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

  Widget _buildHeaderIcon(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.person_add_outlined,
        color: theme.colorScheme.onPrimary,
        size: 36,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.error),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildCreateButton(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createAccount,
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
                children: [
                  const Icon(Icons.person_add_rounded, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Create Account',
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
