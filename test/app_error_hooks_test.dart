import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:registeryourcafe/bootstrap/app_error_hooks.dart';
import 'package:registeryourcafe/utils/app_logger.dart';

void main() {
  setUp(AppLogger.clearRecentErrorsForTest);
  tearDown(AppLogger.clearRecentErrorsForTest);

  test('logFlutterFrameworkError records diagnostics ring', () {
    final details = FlutterErrorDetails(
      exception: Exception('widget blew up'),
      stack: StackTrace.current,
    );
    logFlutterFrameworkError(details);
    expect(AppLogger.recentErrorRecords.length, 1);
    expect(AppLogger.recentErrorRecords.first.tag, 'FlutterFramework');
    expect(
      AppLogger.recentErrorRecords.first.message,
      'Flutter framework error',
    );
  });

  test('logPlatformDispatcherError records diagnostics ring', () {
    logPlatformDispatcherError(StateError('zone'), StackTrace.current);
    expect(AppLogger.recentErrorRecords.length, 1);
    expect(AppLogger.recentErrorRecords.first.tag, 'Zone');
    expect(AppLogger.recentErrorRecords.first.message, 'Uncaught async error');
  });

  test('isWebDebugDisposedEngineViewNoise matches engine assertion text', () {
    final details = FlutterErrorDetails(
      exception: AssertionError(
        'Trying to render a disposed EngineFlutterView.',
      ),
      stack: StackTrace.current,
    );
    expect(
      details.exceptionAsString(),
      contains('Trying to render a disposed EngineFlutterView'),
    );
    // Only suppressed on web debug builds (VM tests are not web).
    expect(isWebDebugDisposedEngineViewNoise(details), kIsWeb && kDebugMode);
  });
}
