import 'package:flutter_test/flutter_test.dart';
import 'package:registeryourcafe/utils/app_logger.dart';
import 'package:registeryourcafe/utils/safe_async.dart';

void main() {
  setUp(AppLogger.clearRecentErrorsForTest);
  tearDown(AppLogger.clearRecentErrorsForTest);

  test('run returns success when operation completes', () async {
    final r = await SafeAsync.run(() async => 42);
    expect(r.isSuccess, true);
    expect(r.valueOrNull, 42);
  });

  test('run returns failure and logs on exception', () async {
    final r = await SafeAsync.run(
      () async {
        throw StateError('bad');
      },
      context: 'ctx',
    );
    expect(r.isFailure, true);
    expect(r.errorOrNull, contains('ctx'));
    expect(r.errorOrNull, contains('bad'));
    expect(AppLogger.recentErrorRecords.length, 1);
  });

  test('runWithTimeout returns failure on timeout without error ring', () async {
    final r = await SafeAsync.runWithTimeout(
      () async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return 1;
      },
      timeout: const Duration(milliseconds: 50),
      context: 'slow',
    );
    expect(r.isFailure, true);
    expect(r.errorOrNull, contains('slow'));
    expect(r.errorOrNull, contains('timed out'));
    expect(AppLogger.recentErrorRecords, isEmpty);
  });
}
