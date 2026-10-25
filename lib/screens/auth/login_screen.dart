import 'package:firebase_auth/firebase_auth.dart';
import 'package:registeryourcafe/branding/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_strings.dart';
import '../../theme/app_theme.dart';
import '../../utils/auth_email_policy.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/legal_footer_links.dart';
import '../../widgets/glass_modal_bottom_sheet.dart';
import '../../widgets/glass_panel.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final credential = await ref
            .read(authServiceProvider)
            .signInWithEmailAndPassword(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );
        try {
          await credential.user?.reload();
        } catch (_) {
          // Best-effort: session is still valid; reload only refreshes flags.
        }
        ref.invalidate(authStateChangesProvider);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        final message = switch (e.code) {
          'user-not-found' => 'No account found with this email.',
          'wrong-password' => 'Incorrect password. Try again or reset it.',
          'invalid-email' => 'The email address is not valid.',
          'user-disabled' =>
            'This account has been disabled. Contact support.',
          'too-many-requests' =>
            'Too many attempts. Please wait and try again.',
          'network-request-failed' =>
            'Network error. Check your connection.',
          'invalid-credential' => 'Invalid email or password.',
          _ => e.message ?? 'Login failed. Please try again.',
        };
        _showErrorSnackBar(message);
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('Login failed: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    context.showErrorSnackbar(message);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (result == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      try { await result.credential.user?.reload(); } catch (_) {}
      ref.invalidate(authStateChangesProvider);
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showErrorSnackbar(e.message ?? 'Google sign-in failed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showErrorSnackbar('Google sign-in failed: $e');
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: GlassModalSheetChrome(
          topRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Reset Password',
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email to receive a reset link',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: AuthEmailPolicy.gmailOnlyHint,
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Theme.of(
                      sheetContext,
                    ).colorScheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(AppStrings.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, emailController.text.trim()),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Send Reset Link'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      final emailErr = AuthEmailPolicy.workspaceGmailFieldError(result);
      if (emailErr != null) {
        if (mounted) {
          _showErrorSnackBar(emailErr);
        }
        return;
      }
      try {
        await ref.read(authServiceProvider).sendPasswordResetEmail(result);
        if (mounted) {
          context.showSuccessSnackbar(
            'If that Gmail account is registered, a reset link was sent. '
            '${AppStrings.authEmailSentHints}',
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Failed to send reset email');
        }
      }
    }
  }

  Future<void> _showCreateAccountSheet() async {
    final theme = Theme.of(context);
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(ctx).bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create account', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Sign up to book tables, order food, and earn rewards.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  try {
                    await ref.read(authServiceProvider).createCustomerAccount(
                      name: nameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      password: passCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } on FirebaseAuthException catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.message ?? 'Sign up failed')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Sign up failed: $e')),
                      );
                    }
                  }
                },
                child: const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );

    if (created == true && mounted) {
      ref.invalidate(authStateChangesProvider);
      if (mounted) Navigator.of(context).pop();
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
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
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
                  TextButton(
                    onPressed: _forgotPassword,
                    child: Text(
                      'Need help?',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: AppTheme.scrollPhysicsFor(context),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 40),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        SizedBox(height: keyboardVisible ? 10 : 20),

                        // Logo
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: keyboardVisible ? 52 : (isMobile ? 72 : 88),
                          child: Image.asset(
                            AppAssets.appLogo,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: keyboardVisible ? 12 : 20),

                        // Title
                        if (!keyboardVisible) ...[
                          Text(
                            'Welcome back',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: isMobile ? 24 : 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to your venue dashboard',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 15,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Form
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: AppSurface(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(20),
                            borderColor: theme.colorScheme.outline.withValues(
                              alpha: 0.25,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Email Field
                                  _buildTextField(
                                    controller: _emailController,
                                    focusNode: _emailFocus,
                                    label: 'Email',
                                    hint: AuthEmailPolicy.gmailOnlyHint,
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) =>
                                        _passwordFocus.requestFocus(),
                                    validator: AuthEmailPolicy.workspaceGmailFieldError,
                                  ),
                                  const SizedBox(height: 16),

                                  // Password Field
                                  _buildTextField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocus,
                                    label: 'Password',
                                    hint: '••••••••',
                                    icon: Icons.lock_outline,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _login(),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Please enter your password';
                                      }
                                      return null;
                                    },
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),

                                  // Forgot Password
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _forgotPassword,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Login Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: FilledButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.primary,
                                        foregroundColor:
                                            theme.colorScheme.onPrimary,
                                        elevation: _isLoading ? 0 : 2,
                                        shadowColor: theme.colorScheme.primary
                                            .withValues(alpha: 0.45),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color:
                                                    theme.colorScheme.onPrimary,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.login_rounded,
                                                  size: 20,
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Sign In',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
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
                                      onPressed: _isLoading ? null : _signInWithGoogle,
                                      icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                                      label: const Text('Sign in with Google'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Center(
                                    child: TextButton(
                                      onPressed: _showCreateAccountSheet,
                                      child: Text.rich(
                                        TextSpan(children: [
                                          TextSpan(text: "Don't have an account? ", style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                                          TextSpan(text: 'Sign up', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                                        ]),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Legal links + bottom indicator (Play / web disclosure)
            if (!keyboardVisible)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LegalFooterLinks(compact: true),
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
          fontSize: 15,
        ),
        prefixIcon: Icon(icon, color: cs.onSurfaceVariant, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: cs.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error.withValues(alpha: 0.85)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
