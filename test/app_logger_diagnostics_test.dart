import 'package:flutter_test/flutter_test.dart';
import 'package:registeryourcafe/utils/app_logger.dart';

void main() {
  setUp(AppLogger.clearRecentErrorsForTest);

  tearDown(AppLogger.clearRecentErrorsForTest);

  test('error() appends to ring and supportSnippet lists entries', () {
    AppLogger.error('first', tag: 'T1');
    AppLogger.error('second', tag: 'T2', error: StateError('x'));
    expect(AppLogger.recentErrorRecords.length, 2);
    final snippet = AppLogger.supportSnippet();
    expect(snippet, contains('App:'));
    expect(snippet, contains('first'));
    expect(snippet, contains('second'));
    expect(snippet, contains('T1'));
    expect(snippet, contains('Bad state'));
  });

  test('ring evicts oldest beyond capacity', () {
    for (var i = 0; i < AppLogger.recentErrorCapacity + 3; i++) {
      AppLogger.error('msg-$i');
    }
    expect(AppLogger.recentErrorRecords.length, AppLogger.recentErrorCapacity);
    final first = AppLogger.recentErrorRecords.first.message;
    expect(first, 'msg-3');
    final last = AppLogger.recentErrorRecords.last.message;
    expect(last, contains('msg-'));
  });

  test('supportSnippet empty message includes build context', () {
    final s = AppLogger.supportSnippet();
    expect(s, contains('App:'));
    expect(s, contains('debug:'));
    expect(s, contains('No recent errors'));
  });
}
