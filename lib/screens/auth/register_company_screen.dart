import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseAuthException, User;
import 'package:registeryourcafe/branding/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/company_module_visibility.dart';
import '../../models/venue_kind.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_strings.dart';
import '../../theme/app_theme.dart';
import '../../utils/auth_email_policy.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/legal_footer_links.dart';
import '../../widgets/glass_panel.dart';

class RegisterCompanyScreen extends ConsumerStatefulWidget {
  const RegisterCompanyScreen({
    super.key,
    required this.venueKind,
    this.prefilledName,
    this.prefilledEmail,
    this.isGoogleUser = false,
  });

  final VenueKind venueKind;
  final String? prefilledName;
  final String? prefilledEmail;
  final bool isGoogleUser;

  @override
  ConsumerState<RegisterCompanyScreen> createState() =>
      _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends ConsumerState<RegisterCompanyScreen>
    with SingleTickerProviderStateMixin {
  final _accountFormKey = GlobalKey<FormState>();
  final _venueFormKey = GlobalKey<FormState>();

  // Step 1: Account
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _adminFocus = FocusNode();

  // Step 2: Venue
  final _companyNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _phoneFocus = FocusNode();
  late VenueKind _selectedVenueKind;

  User? _googleUser;
  bool get _isGoogleAuth => _googleUser != null;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late int _currentStep;
  late final PageController _pageController;

  bool _accountStepValidated = false;
  bool _venueStepValidated = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedVenueKind = widget.venueKind;
    _currentStep = widget.isGoogleUser ? 1 : 0;
    if (widget.isGoogleUser) {
      _googleUser = FirebaseAuth.instance.currentUser;
    }
    if (widget.prefilledName != null) {
      _adminNameController.text = widget.prefilledName!;
    }
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
    _pageController = PageController(initialPage: widget.isGoogleUser ? 1 : 0);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    _companyNameController.dispose();
    _adminNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _companyFocus.dispose();
    _adminFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _descriptionFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (step < 0 || step > 2) return;
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _validateAccountStep() {
    return _accountFormKey.currentState?.validate() ?? false;
  }

  bool _validateVenueStep() {
    return _venueFormKey.currentState?.validate() ?? false;
  }

  void _onNext() {
    if (_currentStep == 0 && (_isGoogleAuth || _validateAccountStep())) {
      _accountStepValidated = true;
      _goToStep(1);
    } else if (_currentStep == 1 && _validateVenueStep()) {
      _venueStepValidated = true;
      _goToStep(2);
    }
  }

  void _onBack() {
    if (_currentStep > 0) {
      if (_currentStep == 2) _venueStepValidated = false;
      if (_currentStep == 1) _accountStepValidated = false;
      _goToStep(_currentStep - 1);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (result == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final user = result.credential.user;
      if (user != null && mounted) {
        setState(() {
          _googleUser = user;
          _adminNameController.text = user.displayName ?? '';
          _emailController.text = user.email ?? '';
          _isLoading = false;
        });
        _goToStep(1);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-up failed: $e')),
        );
      }
    }
  }

  Future<void> _register() async {
    final accountOk = _isGoogleAuth
        || _accountStepValidated
        || _validateAccountStep();
    if (!accountOk) {
      _goToStep(0);
      return;
    }
    final venueOk = _venueStepValidated
        || _validateVenueStep();
    if (!venueOk) {
      _goToStep(1);
      return;
    }
    if (_companyNameController.text.trim().isEmpty) {
      _goToStep(1);
      return;
    }
    if (!_isGoogleAuth && _emailController.text.trim().isEmpty) {
      _goToStep(0);
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_isGoogleAuth) {
        await ref.read(authServiceProvider).registerCompanyWithGoogle(
          companyName: _companyNameController.text.trim(),
          venueKind: _selectedVenueKind,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          address: null,
        );
      } else {
        await ref.read(authServiceProvider).registerCompany(
          companyName: _companyNameController.text.trim(),
          adminName: _adminNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          venueKind: _selectedVenueKind,
          phoneNumber: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
      }
      if (mounted) {
        context.showSuccessSnackbar(
          _isGoogleAuth
              ? 'Workspace created successfully!'
              : 'Workspace created. We sent a verification link. '
                '${AppStrings.authEmailSentHints}',
        );
        ref.invalidate(authStateChangesProvider);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context).pop();
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'email-already-in-use' =>
          'An account with this email already exists. Try signing in instead.',
        'invalid-email' => 'The email address is not valid.',
        'weak-password' =>
          'The password is too weak. Use at least 6 characters.',
        'operation-not-allowed' =>
          'Email/password accounts are not enabled.',
        'network-request-failed' =>
          'Network error. Check your connection and try again.',
        _ => e.message ?? 'Registration failed. Please try again.',
      };
      context.showErrorSnackbar(msg);
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackbar('Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < AppTheme.kMobileBreakpoint;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _onBack,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _StepIndicator(
                    currentStep: _currentStep,
                    theme: theme,
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildAccountStep(theme, isMobile, keyboardVisible),
                      _buildVenueStep(theme, isMobile, keyboardVisible),
                      _buildReviewStep(theme, isMobile, keyboardVisible),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountStep(
    ThemeData theme,
    bool isMobile,
    bool keyboardVisible,
  ) {
    return SingleChildScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 40),
      child: Column(
        children: [
          if (!keyboardVisible) ...[
            const SizedBox(height: 20),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: isMobile ? 72 : 88,
              child: Image.asset(AppAssets.appLogo, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            Text(
              'Step 1: Your account',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: isMobile ? 24 : 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will be the owner (admin) for this workspace.',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AppSurface(
              borderRadius: 20,
              padding: const EdgeInsets.all(20),
              borderColor:
                  theme.colorScheme.outline.withValues(alpha: 0.25),
              child: Form(
                key: _accountFormKey,
                child: Column(
                  children: [
                    if (_isGoogleAuth) ...[
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Signed in as ${_googleUser!.email}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildField(
                      theme,
                      controller: _adminNameController,
                      focusNode: _adminFocus,
                      label: 'Your full name',
                      hint: 'Admin name',
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _isGoogleAuth ? _onNext() : _emailFocus.requestFocus(),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    if (!_isGoogleAuth) ...[
                      const SizedBox(height: 14),
                      _buildField(
                        theme,
                        controller: _emailController,
                        focusNode: _emailFocus,
                        label: 'Email',
                        hint: AuthEmailPolicy.gmailOnlyHint,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          return AuthEmailPolicy.workspaceGmailFieldError(v);
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        theme,
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        label: 'Password',
                        hint: 'At least 6 characters',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            _confirmPasswordFocus.requestFocus(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 6) return 'Minimum 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        theme,
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocus,
                        label: 'Confirm password',
                        hint: 'Re-enter password',
                        icon: Icons.lock_outline,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _onNext(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Confirm your password';
                          }
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _onNext,
                        child: const Text('Next: Venue details'),
                      ),
                    ),
                    if (!_isGoogleAuth) ...[
                      const SizedBox(height: 20),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                        const Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signUpWithGoogle,
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                          label: const Text('Sign up with Google'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const LegalFooterLinks(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVenueStep(
    ThemeData theme,
    bool isMobile,
    bool keyboardVisible,
  ) {
    return SingleChildScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 40),
      child: Column(
        children: [
          if (!keyboardVisible) ...[
            const SizedBox(height: 20),
            Text(
              'Step 2: Venue info',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: isMobile ? 24 : 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about your venue so we can set up the right modules.',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AppSurface(
              borderRadius: 20,
              padding: const EdgeInsets.all(20),
              borderColor:
                  theme.colorScheme.outline.withValues(alpha: 0.25),
              child: Form(
                key: _venueFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      theme,
                      controller: _companyNameController,
                      focusNode: _companyFocus,
                      label: 'Company / venue name',
                      hint: _selectedVenueKind.companyNameFieldHint,
                      icon: Icons.apartment_outlined,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) =>
                          _descriptionFocus.requestFocus(),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Venue type',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _VenueKindSelector(
                      selectedKind: _selectedVenueKind,
                      theme: theme,
                      onChanged: (k) =>
                          setState(() => _selectedVenueKind = k),
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      theme,
                      controller: _descriptionController,
                      focusNode: _descriptionFocus,
                      label: 'Description (optional)',
                      hint: 'What makes your venue special?',
                      icon: Icons.description_outlined,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _phoneFocus.requestFocus(),
                      validator: (_) => null,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      theme,
                      controller: _phoneController,
                      focusNode: _phoneFocus,
                      label: 'Phone (optional)',
                      hint: '+91 …',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onNext(),
                      validator: (_) => null,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _onBack,
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _onNext,
                              child: const Text('Next: Review'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!keyboardVisible) ...[
            _RegistrationModulePreview(
              theme: theme,
              bullets:
                  CompanyModuleVisibility.registrationModuleBullets(
                _selectedVenueKind,
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewStep(
    ThemeData theme,
    bool isMobile,
    bool keyboardVisible,
  ) {
    final cs = theme.colorScheme;
    return SingleChildScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 40),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Step 3: Review & create',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirm your details before creating the workspace.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AppSurface(
              borderRadius: 20,
              padding: const EdgeInsets.all(20),
              borderColor: cs.outline.withValues(alpha: 0.25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _reviewSection(theme, 'Account'),
                  const SizedBox(height: 8),
                  _reviewRow(theme, 'Name', _adminNameController.text.trim()),
                  _reviewRow(theme, 'Email', _emailController.text.trim()),
                  const SizedBox(height: 16),
                  Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  _reviewSection(theme, 'Venue'),
                  const SizedBox(height: 8),
                  _reviewRow(
                    theme,
                    'Company',
                    _companyNameController.text.trim().isEmpty
                        ? '(not set)'
                        : _companyNameController.text.trim(),
                  ),
                  _reviewRow(theme, 'Type', _selectedVenueKind.label),
                  if (_descriptionController.text.trim().isNotEmpty)
                    _reviewRow(
                      theme,
                      'Description',
                      _descriptionController.text.trim(),
                    ),
                  if (_phoneController.text.trim().isNotEmpty)
                    _reviewRow(
                      theme,
                      'Phone',
                      _phoneController.text.trim(),
                    ),
                  const SizedBox(height: 16),
                  Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    _selectedVenueKind.registrationFocusNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Text('Create workspace'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _onBack,
                          child: const Text('Back'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const LegalFooterLinks(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _reviewSection(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _reviewRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    ThemeData theme, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.theme});

  final int currentStep;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i <= currentStep;
        final isCurrent = i == currentStep;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isCurrent ? 28 : 10,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
        );
      }),
    );
  }
}

class _VenueKindSelector extends StatelessWidget {
  const _VenueKindSelector({
    required this.selectedKind,
    required this.theme,
    required this.onChanged,
  });

  final VenueKind selectedKind;
  final ThemeData theme;
  final ValueChanged<VenueKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: VenueKind.values.map((kind) {
        final isSelected = kind == selectedKind;
        final cs = theme.colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onChanged(kind),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isSelected
                    ? cs.primaryContainer.withValues(alpha: 0.5)
                    : cs.surfaceContainer,
                border: Border.all(
                  color: isSelected
                      ? cs.primary.withValues(alpha: 0.6)
                      : cs.outlineVariant.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    switch (kind) {
                      VenueKind.gamingCafe => Icons.sports_esports_outlined,
                      VenueKind.diningCafe => Icons.restaurant_outlined,
                      VenueKind.restaurantCafe => Icons.storefront_outlined,
                    },
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kind.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? cs.primary : cs.onSurface,
                          ),
                        ),
                        Text(
                          kind.shortDescription,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: cs.primary, size: 22),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RegistrationModulePreview extends StatelessWidget {
  const _RegistrationModulePreview({
    required this.theme,
    required this.bullets,
  });

  final ThemeData theme;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_outlined,
                  size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Modules enabled for this template',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Change anytime under Settings \u2192 workspace modules.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in bullets) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
