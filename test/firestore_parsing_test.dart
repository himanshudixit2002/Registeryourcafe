import 'package:flutter_test/flutter_test.dart';
import 'package:registeryourcafe/utils/firestore_utils.dart';

void main() {
  group('parseFirestoreDoubleOrNull', () {
    test('null and empty string', () {
      expect(parseFirestoreDoubleOrNull(null), isNull);
      expect(parseFirestoreDoubleOrNull(''), isNull);
      expect(parseFirestoreDoubleOrNull('   '), isNull);
    });

    test('num and string', () {
      expect(parseFirestoreDoubleOrNull(42), 42.0);
      expect(parseFirestoreDoubleOrNull(3.14), 3.14);
      expect(parseFirestoreDoubleOrNull(' 2.5 '), 2.5);
    });

    test('invalid uses fallback on parseFirestoreDouble', () {
      expect(parseFirestoreDouble(true, fallback: -1), -1);
      expect(parseFirestoreDouble('x', fallback: -1), -1);
    });
  });

  group('parseFirestoreIntOrNull', () {
    test('null and empty string', () {
      expect(parseFirestoreIntOrNull(null), isNull);
      expect(parseFirestoreIntOrNull(''), isNull);
    });

    test('int, double, and string', () {
      expect(parseFirestoreIntOrNull(7), 7);
      expect(parseFirestoreIntOrNull(7.9), 7);
      expect(parseFirestoreIntOrNull(' 99 '), 99);
    });
  });

  group('parseFirestoreStringOrNull', () {
    test('null, trim, and legacy numeric', () {
      expect(parseFirestoreStringOrNull(null), isNull);
      expect(parseFirestoreStringOrNull('  ab '), 'ab');
      expect(parseFirestoreStringOrNull(''), isNull);
      expect(parseFirestoreStringOrNull(42), '42');
      expect(parseFirestoreStringOrNull(3.0), '3');
    });
  });
}
