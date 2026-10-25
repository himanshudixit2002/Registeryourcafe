import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:registeryourcafe/auth/consume_email_action_code.dart';
import 'package:registeryourcafe/bootstrap/app_error_hooks.dart';
import 'package:registeryourcafe/branding/app_assets.dart';
import 'package:registeryourcafe/providers/auth_provider.dart';
import 'package:registeryourcafe/providers/firebase_init_provider.dart';
import 'package:registeryourcafe/screens/auth/email_verification_gate_screen.dart';
import 'package:registeryourcafe/screens/landing/landing_page.dart';
import 'package:registeryourcafe/utils/email_verification_guard.dart';

import 'auth/super_admin.dart';
import 'navigation/workspace_main_screen.dart';
import 'screens/super_admin/super_admin_shell.dart';
import 'providers/permissions_provider.dart';
import 'providers/user_ui_prefs_provider.dart';
import 'theme/app_scroll_behavior.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';
import 'widgets/bootstrap_error_scaffold.dart';
import 'widgets/bootstrap_spinner.dart';
import 'widgets/connectivity_banner.dart';

Brightness _resolvedBrightness(ThemeMode mode, Brightness platform) {
  return switch (mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => platform,
  };
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installAppErrorHooks();
  if (!kDebugMode) {
    AppLogger.onErrorReport = (message, {error, stackTrace, tag}) {
      developer.log(
        message,
        name: tag ?? 'AppError',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        if (Firebase.apps.isEmpty || kIsWeb) return;
        FirebaseCrashlytics.instance.recordError(
          error ?? Exception(message),
          stackTrace,
          reason: tag != null ? '[$tag] $message' : message,
          fatal: false,
        );
      } catch (_) {}
    };
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(AppAssets.appLogo), context);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Registeryourcafe',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 380),
      themeAnimationCurve: Curves.easeOutCubic,
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) {
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final brightness = _resolvedBrightness(themeMode, platformBrightness);
        final overlay = brightness == Brightness.dark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.dark,
              );
        final width = MediaQuery.sizeOf(context).width;
        final isNarrow = width < AppTheme.kMobileBreakpoint;
        final baseTheme = Theme.of(context);
        final scaledChild = MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.35,
          child: child ?? const SizedBox.shrink(),
        );
        final shellChild = Theme(
          data: baseTheme.copyWith(
            visualDensity: isNarrow
                ? VisualDensity.compact
                : VisualDensity.standard,
          ),
          child: scaledChild,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppTheme.shellBackdropGradient(brightness),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ConnectivityBanner(),
                Expanded(child: shellChild),
              ],
            ),
          ),
        );
      },
      home: const AuthWidget(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWidget extends ConsumerStatefulWidget {
  const AuthWidget({super.key});

  @override
  ConsumerState<AuthWidget> createState() => _AuthWidgetState();
}

class _AuthWidgetState extends ConsumerState<AuthWidget> {
  bool _emailActionUrlConsumeStarted = false;

  Future<void> _maybeConsumeEmailActionFromUrl() async {
    if (_emailActionUrlConsumeStarted) return;
    _emailActionUrlConsumeStarted = true;
    final applied = await consumeEmailActionCodeFromBrowserUrl();
    if (!mounted) return;
    if (applied) {
      try {
        await FirebaseAuth.instance.currentUser?.reload();
      } catch (_) {}
      ref.invalidate(authStateChangesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(firebaseInitProvider, (previous, next) {
      next.whenData((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_maybeConsumeEmailActionFromUrl());
        });
      });
    });

    final firebaseInit = ref.watch(firebaseInitProvider);

    return firebaseInit.when(
      data: (_) {
        final authState = ref.watch(authStateChangesProvider);
        return authState.when(
          data: (user) {
            if (user == null || user.isAnonymous) {
              return const LandingPage();
            }
            return const PostAuthShell();
          },
          loading: () => const _QuickSplash(),
          error: (error, stack) {
            final copy = BootstrapFailureCopy.forError(error);
            return BootstrapErrorScaffold(
              title: copy.title,
              userMessage: copy.userMessage,
              errorDetail: error.toString(),
              onRetry: () => ref.invalidate(firebaseInitProvider),
            );
          },
        );
      },
      loading: () => const _QuickSplash(),
      error: (error, stack) {
        final copy = BootstrapFailureCopy.forError(error);
        return BootstrapErrorScaffold(
          title: copy.title,
          userMessage: copy.userMessage,
          errorDetail: error.toString(),
          onRetry: () => ref.invalidate(firebaseInitProvider),
        );
      },
    );
  }
}

class _QuickSplash extends StatelessWidget {
  const _QuickSplash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Image.asset(
                AppAssets.appLogo,
                height: 80,
                cacheWidth: 160,
                cacheHeight: 160,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 24),
            const BootstrapSpinner(
              size: 28,
              strokeWidth: 2.5,
              strongTint: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads [appUserProvider] after sign-in and requires [AppUser.companyId]
/// before opening the main app shell.
class PostAuthShell extends ConsumerWidget {
  const PostAuthShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);
    final theme = Theme.of(context);

    return appUserAsync.when(
      loading: () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(AppAssets.appLogo, height: 60),
              const SizedBox(height: 20),
              const BootstrapSpinner(),
            ],
          ),
        ),
      ),
      error: (err, stack) {
        final copy = BootstrapFailureCopy.forError(err);
        return BootstrapErrorScaffold(
          title: copy.title,
          userMessage: copy.userMessage,
          errorDetail: err.toString(),
          showSignOut: true,
          onRetry: () => ref.invalidate(appUserProvider),
        );
      },
      data: (user) {
        ref.watch(authStateChangesProvider);
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null && isSuperAdmin(fbUser.email)) {
          if (user == null) {
            unawaited(_seedSuperAdminProfile(fbUser.uid, fbUser.email!).catchError((_) {}));
          }
          return const SuperAdminShell();
        }
        final cid = user?.companyId;
        if (user == null || cid == null || cid.isEmpty) {
          if (user == null && fbUser != null) {
            unawaited(_seedCustomerProfile(fbUser).catchError((_) {}));
          }
          return const LandingPage();
        }
        ref.watch(companyRolesBootstrapProvider);
        if (EmailVerificationGuard.mustCompleteEmailVerification(fbUser)) {
          return const EmailVerificationGateScreen();
        }
        return const MainScreen();
      },
    );
  }
}

Future<void> _seedSuperAdminProfile(String uid, String email) async {
  final db = FirebaseFirestore.instance;
  final ref = db.collection('users').doc(uid);
  await db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, {'email': email, 'name': 'Super Admin', 'role': 'admin'});
    } else {
      final data = snap.data() ?? {};
      if (data['role'] != 'admin') {
        tx.update(ref, {'role': 'admin', 'email': email});
      }
    }
  });
}

Future<void> _seedCustomerProfile(User fbUser) async {
  final db = FirebaseFirestore.instance;
  final ref = db.collection('users').doc(fbUser.uid);
  await db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, {
        'email': fbUser.email ?? '',
        'name': fbUser.displayName ?? 'Customer',
        'role': 'customer',
        if (fbUser.phoneNumber != null) 'phoneNumber': fbUser.phoneNumber,
        if (fbUser.photoURL != null) 'photoUrl': fbUser.photoURL,
      });
    }
  });
}

