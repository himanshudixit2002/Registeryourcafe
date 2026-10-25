import '../firestore/tenant_firestore.dart';
import '../models/membership_type_definition.dart';
import '../utils/firestore_utils.dart';

class MembershipService {
  MembershipService._();

  /// Generates the next membership id for [def] in the format
  /// `PREFIX-XXX` where XXX is a 3-digit incremental counter.
  ///
  /// The counter is stored in [membership_counters] under doc [effectiveIdPrefix].
  static Future<String> generateMembershipId(
    TenantRef tenant,
    MembershipTypeDefinition def,
  ) async {
    if (def.isRegular) {
      throw ArgumentError('Cannot generate ID for regular membership');
    }
    final typeKey = def.effectiveIdPrefix;
    if (typeKey.isEmpty) {
      throw ArgumentError(
        'Membership plan needs an ID prefix for card numbers',
      );
    }

    return tenant.db.runTransaction<String>((transaction) async {
      final docRef = tenant.membershipCounters().doc(typeKey);
      final snapshot = await transaction.get(docRef);

      int lastNumber = 0;
      if (snapshot.exists) {
        lastNumber = parseFirestoreInt(snapshot.data()?['lastNumber']);
      }

      final newNumber = lastNumber + 1;
      transaction.set(docRef, {'lastNumber': newNumber});

      final formatted = newNumber.toString().padLeft(3, '0');
      return '$typeKey-$formatted';
    });
  }
}
