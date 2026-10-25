import '../firestore/tenant_firestore.dart';
import '../utils/firestore_utils.dart';

enum OrderCategory { cafe, merchandise, session }

class OrderIdService {
  OrderIdService._();

  /// Generates a unique ID for the given [category] in the format
  ///   C-000001, M-000123, S-001234, …
  ///
  /// Uniqueness is guaranteed via a Firestore transaction that increments a
  /// counter stored in `order_counters/{PREFIX}`.
  static Future<String> generate(
    TenantRef tenant,
    OrderCategory category,
  ) async {
    final firestore = tenant.db;

    // Map enum → single-letter prefix.
    const prefixMap = {
      OrderCategory.cafe: 'C',
      OrderCategory.merchandise: 'M',
      OrderCategory.session: 'S',
    };

    final prefix = prefixMap[category]!;

    return firestore.runTransaction<String>((tx) async {
      final docRef = tenant.orderCounters().doc(prefix);
      final snap = await tx.get(docRef);
      int last = 0;
      if (snap.exists) {
        final d = snap.data();
        if (d is Map<String, dynamic>) {
          last = parseFirestoreInt(d['last']);
        }
      }
      final next = last + 1;
      tx.set(docRef, {'last': next});

      // Pad to 6 digits for plenty of future headroom.
      final numeric = next.toString().padLeft(6, '0');
      return '$prefix-$numeric';
    });
  }
}
