import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/app_logger.dart';

/// Web hot restart can dispose the old [EngineFlutterView] while a frame is
/// still queued; the engine then asserts on render. Harmless in debug; avoid
/// treating it like an app bug or calling [FlutterError.presentError].
@visibleForTesting
bool isWebDebugDisposedEngineViewNoise(FlutterErrorDetails details) {
  if (!kIsWeb || !kDebugMode) return false;
  return details.exceptionAsString().contains(
    'Trying to render a disposed EngineFlutterView',
  );
}

@visibleForTesting
void logFlutterFrameworkError(FlutterErrorDetails details) {
  AppLogger.error(
    'Flutter framework error',
    tag: 'FlutterFramework',
    error: details.exception,
    stackTrace: details.stack,
    skipExternalReport: true,
  );
}

@visibleForTesting
void logPlatformDispatcherError(Object error, StackTrace stack) {
  AppLogger.error(
    'Uncaught async error',
    tag: 'Zone',
    error: error,
    stackTrace: stack,
    skipExternalReport: true,
  );
}

void _forwardFlutterFatalToCrashlytics(FlutterErrorDetails details) {
  if (kDebugMode || kIsWeb || Firebase.apps.isEmpty) return;
  try {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  } catch (_) {}
}

void _forwardAsyncFatalToCrashlytics(Object error, StackTrace stack) {
  if (kDebugMode || kIsWeb || Firebase.apps.isEmpty) return;
  try {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  } catch (_) {}
}

/// Call after [WidgetsFlutterBinding.ensureInitialized].
void installAppErrorHooks() {
  FlutterError.onError = (FlutterErrorDetails details) {
    if (isWebDebugDisposedEngineViewNoise(details)) {
      AppLogger.debug(
        'Skipped presentError: disposed EngineFlutterView (web hot restart)',
        tag: 'FlutterFramework',
      );
      return;
    }
    logFlutterFrameworkError(details);
    if (kDebugMode) {
      FlutterError.presentError(details);
    } else {
      _forwardFlutterFatalToCrashlytics(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logPlatformDispatcherError(error, stack);
    _forwardAsyncFatalToCrashlytics(error, stack);
    return true;
  };
}
