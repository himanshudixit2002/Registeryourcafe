import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/credit_transaction.dart';
import 'tenant_provider.dart';

final customerCreditLedgerProvider =
    StreamProvider.family<List<CreditTransaction>, String>((ref, customerId) {
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) {
        return Stream.value(<CreditTransaction>[]);
      }
      return tenant.creditTransactions(customerId).snapshots().map((snap) {
        final list = snap.docs
            .map((d) => CreditTransaction.fromFirestore(d))
            .toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });
    });
