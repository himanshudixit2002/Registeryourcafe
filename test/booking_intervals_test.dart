import 'package:flutter_test/flutter_test.dart';
import 'package:registeryourcafe/models/public_booking_slot.dart';

void main() {
  group('bookingIntervalsOverlap', () {
    test('adjacent windows do not overlap', () {
      final a0 = DateTime(2026, 4, 12, 10, 0);
      final a1 = DateTime(2026, 4, 12, 11, 0);
      final b0 = DateTime(2026, 4, 12, 11, 0);
      final b1 = DateTime(2026, 4, 12, 12, 0);
      expect(bookingIntervalsOverlap(a0, a1, b0, b1), false);
    });

    test('partial overlap', () {
      final a0 = DateTime(2026, 4, 12, 10, 0);
      final a1 = DateTime(2026, 4, 12, 12, 0);
      final b0 = DateTime(2026, 4, 12, 11, 0);
      final b1 = DateTime(2026, 4, 12, 13, 0);
      expect(bookingIntervalsOverlap(a0, a1, b0, b1), true);
    });

    test('invalid zero-length interval', () {
      final t = DateTime(2026, 4, 12, 10, 0);
      expect(bookingIntervalsOverlap(t, t, t, t.add(const Duration(hours: 1))), false);
    });
  });

  group('PublicBookingSlot.containsInstant', () {
    test('half-open [start, end)', () {
      final start = DateTime(2026, 4, 12, 10, 0);
      final end = DateTime(2026, 4, 12, 11, 0);
      final slot = PublicBookingSlot(
        id: '1',
        tableId: 't1',
        startAt: start,
        endAt: end,
        requestId: 'r1',
      );
      expect(slot.containsInstant(start), true);
      expect(slot.containsInstant(start.add(const Duration(minutes: 30))), true);
      expect(slot.containsInstant(end), false);
      expect(slot.containsInstant(start.subtract(const Duration(seconds: 1))), false);
    });
  });
}
