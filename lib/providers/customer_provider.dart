import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/firestore_collections.dart';
import '../firestore/tenant_firestore.dart';
import '../models/customer.dart';
import '../models/credit_transaction.dart';
import '../models/credit_transaction_with_customer.dart';
import '../utils/app_logger.dart';
import '../utils/firestore_utils.dart';
import 'tenant_provider.dart';

final customerServiceProvider = Provider<CustomerService>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    throw StateError('CustomerService requires an active company tenant');
  }
  return CustomerService(tenant);
});

class CustomerService {
  final TenantRef _tenant;
  static const int _pageSize = 20;

  CustomerService(this._tenant);

  /// Performs a lightweight, server-side search for customers by name prefix
  /// or phone number. This prevents downloading the entire `customers` collection
  /// when the user is simply looking for a single record.
  ///
  /// Firestore does not support true full-text search, so we implement two
  /// targeted queries:
  /// 1. Name prefix search using `orderBy / startAt / endAt` – this is
  ///    case-sensitive but still effective for most scenarios. Developers may
  ///    index a lower-case `nameLower` field for better results.
  /// 2. Direct equality match on `phoneNumber` when the query looks numeric.
  ///
  /// Duplicate documents (e.g., when both name & phone match) are filtered
  /// before returning.
  Future<List<Customer>> searchCustomers(String query, {int limit = 40}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final results = <Customer>[];

    // ---------------- Case-insensitive name prefix using `nameLower` ---------
    final lower = trimmed.toLowerCase();
    // Ensure you have a Firestore composite/ascending index on 'nameLower'.
    try {
      final nameSnap = await _tenant
          .customers()
          .orderBy('nameLower')
          .startAt([lower])
          .endAt(["$lower\uf8ff"]) // Prefix match (lower-case)
          .limit(limit)
          .get();

      results.addAll(nameSnap.docs.map((d) => Customer.fromFirestore(d)));
    } catch (e, st) {
      AppLogger.warning(
        'Customer search nameLower query failed, trying name order: $e',
        tag: 'CustomerService',
      );
      AppLogger.debug('$st', tag: 'CustomerService');
      // Fallback to case-sensitive orderBy('name') if `nameLower` is not indexed.
      try {
        final altSnap = await _tenant
            .customers()
            .orderBy('name')
            .startAt([trimmed])
            .endAt(["$trimmed\uf8ff"])
            .limit(limit)
            .get();
        results.addAll(altSnap.docs.map((d) => Customer.fromFirestore(d)));
      } catch (e2, st2) {
        AppLogger.error(
          'Customer search fallback name query failed',
          tag: 'CustomerService',
          error: e2,
          stackTrace: st2,
        );
      }
    }

    // ------------- Phone search -------------
    final isNumeric = RegExp(r'^\d+$').hasMatch(trimmed);
    if (isNumeric) {
      try {
        final phoneSnap = await _tenant
            .customers()
            .where('phoneNumber', isEqualTo: trimmed)
            .limit(limit)
            .get();

        results.addAll(phoneSnap.docs.map((d) => Customer.fromFirestore(d)));
      } catch (e, st) {
        AppLogger.error(
          'Customer search phone query failed',
          tag: 'CustomerService',
          error: e,
          stackTrace: st,
        );
      }
    }

    // De-duplicate by ID
    final deduped = {for (var c in results) c.id: c}.values.toList();

    // ------------------------------------------------------------------
    // LAST RESORT (legacy data): if still nothing found, download a larger
    // slice of the collection (up to [limit] * 5) and filter in memory. This
    // guarantees we match mixed-case names even when `nameLower` is missing
    // and no prefix index exists. The performance impact is limited because
    // it runs only when the fast indexed queries above failed.
    // ------------------------------------------------------------------
    if (deduped.isEmpty) {
      try {
        // Reduced limit for faster fallback search
        final bulkSnap = await _tenant.customers().limit(500).get();
        final bulk = bulkSnap.docs
            .map((d) => Customer.fromFirestore(d))
            .where((c) => c.name.toLowerCase().startsWith(lower))
            .toList();
        deduped.addAll(bulk);
      } catch (e, st) {
        AppLogger.error(
          'Customer search bulk prefix fallback failed',
          tag: 'CustomerService',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (deduped.isEmpty) {
      // Absolute fallback: limited search instead of downloading everything
      try {
        final snapAll = await _tenant.customers().limit(1000).get();
        final all = snapAll.docs
            .map((d) => Customer.fromFirestore(d))
            .where((c) => c.name.toLowerCase().contains(lower))
            .toList();
        deduped.addAll(all);
      } catch (e, st) {
        AppLogger.error(
          'Customer search absolute fallback failed',
          tag: 'CustomerService',
          error: e,
          stackTrace: st,
        );
      }
    }

    // Final deduplication in case bulk + all added overlapping records
    final unique = {for (var c in deduped) c.id: c}.values.toList();

    return unique;
  }

  Future<List<Customer>> getInitialCustomers() async {
    final snapshot = await _tenant
        .customers()
        .orderBy('name')
        .limit(_pageSize)
        .get();
    return snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList();
  }

  Future<List<Customer>> getMoreCustomers(DocumentSnapshot lastDoc) async {
    final snapshot = await _tenant
        .customers()
        .orderBy('name')
        .startAfterDocument(lastDoc)
        .limit(_pageSize)
        .get();
    return snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList();
  }
}

class PaginatedCustomersNotifier
    extends StateNotifier<AsyncValue<List<Customer>>> {
  PaginatedCustomersNotifier(this.ref) : super(const AsyncLoading()) {
    _fetchInitialCustomers();
  }

  final Ref ref;
  final List<Customer> _customers = [];
  QueryDocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;

  static const int _pageSize = 20;

  Future<void> _fetchInitialCustomers() async {
    _isLoading = true;
    try {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) {
        state = AsyncData([]);
        return;
      }
      final query = tenant.customers().orderBy('name').limit(_pageSize);
      final snapshot = await query.get();

      final customers = snapshot.docs
          .map((doc) => Customer.fromFirestore(doc))
          .toList();
      _customers.clear();
      _customers.addAll(customers);

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      _hasMore = customers.length == _pageSize;
      state = AsyncData(_customers);
    } catch (e, s) {
      state = AsyncError(e, s);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> fetchMore() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    _isLoading = true;

    // Set loading state while preserving current data for the UI
    state = const AsyncLoading<List<Customer>>().copyWithPrevious(state);

    try {
      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) return;
      final query = tenant
          .customers()
          .orderBy('name')
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);
      final snapshot = await query.get();

      final newCustomers = snapshot.docs
          .map((doc) => Customer.fromFirestore(doc))
          .toList();
      _customers.addAll(newCustomers);

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      _hasMore = newCustomers.length == _pageSize;

      state = AsyncData(_customers);
    } catch (e, s) {
      // In case of error, report it but keep old data
      state = AsyncValue<List<Customer>>.error(e, s).copyWithPrevious(state);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    await _fetchInitialCustomers();
  }
}

final customerListProvider =
    StateNotifierProvider<
      PaginatedCustomersNotifier,
      AsyncValue<List<Customer>>
    >((ref) {
      return PaginatedCustomersNotifier(ref);
    });

final singleCustomerProvider = StreamProvider.autoDispose
    .family<Customer?, String>((ref, customerId) {
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) {
        return Stream<Customer?>.value(null);
      }
      final docSnapshot = tenant.customers().doc(customerId).snapshots();
      return docSnapshot.map((snapshot) {
        if (snapshot.exists) {
          return Customer.fromFirestore(snapshot);
        }
        return null;
      });
    });

final lowCreditCustomersProvider = StreamProvider<List<Customer>>((ref) {
  ref.keepAlive();

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(<Customer>[]);
  }
  return tenant
      .customers()
      .where('alerts.lowCredit', isEqualTo: true)
      .orderBy('updatedAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList(),
      );
});

final expiringMembershipsProvider = StreamProvider<List<Customer>>((ref) {
  ref.keepAlive();

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(<Customer>[]);
  }
  return tenant
      .customers()
      .where('alerts.membershipExpiry', isEqualTo: true)
      .orderBy('updatedAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList(),
      );
});

final creditTransactionsProvider =
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

const int _creditTxLimit = 200;

/// Rows fetched per customer before merging (avoids collectionGroup reads that
/// Firestore rules reject for this schema).
const int _creditTxPerCustomerCap = 40;

Future<List<CreditTransaction>> _mergedCreditTransactionsForCustomers(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> customerDocs,
) async {
  final lists = await Future.wait(
    customerDocs.map((customerDoc) async {
      final txSnap = await customerDoc.reference
          .collection(FirestoreCollections.creditTransactions)
          .orderBy('date', descending: true)
          .limit(_creditTxPerCustomerCap)
          .get();
      return txSnap.docs
          .map((d) => CreditTransaction.fromFirestore(d))
          .toList();
    }),
  );
  final merged = lists.expand((e) => e).toList();
  merged.sort((a, b) => b.date.compareTo(a.date));
  if (merged.length > _creditTxLimit) {
    return merged.sublist(0, _creditTxLimit);
  }
  return merged;
}

Future<List<CreditTransactionWithCustomer>> _mergedCreditTransactionsWithCustomer(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> customerDocs,
) async {
  final lists = await Future.wait(
    customerDocs.map((customerDoc) async {
      final data = customerDoc.data();
      final name = data['name'] as String? ?? 'Unknown';
      final phone = data['phoneNumber'] as String?;
      final membershipId = data['membershipId'] as String?;
      final txSnap = await customerDoc.reference
          .collection(FirestoreCollections.creditTransactions)
          .orderBy('date', descending: true)
          .limit(_creditTxPerCustomerCap)
          .get();
      return txSnap.docs
          .map(
            (d) => CreditTransactionWithCustomer(
              transaction: CreditTransaction.fromFirestore(d),
              customerId: customerDoc.id,
              customerName: name,
              phoneNumber: phone,
              membershipId: membershipId,
            ),
          )
          .toList();
    }),
  );
  final merged = lists.expand((e) => e).toList();
  merged.sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
  if (merged.length > _creditTxLimit) {
    return merged.sublist(0, _creditTxLimit);
  }
  return merged;
}

final allCreditTransactionsProvider = StreamProvider<List<CreditTransaction>>((
  ref,
) {
  ref.keepAlive();
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(<CreditTransaction>[]);
  }

  return tenant.customers().snapshots().asyncMap(
        (snap) => _mergedCreditTransactionsForCustomers(snap.docs),
      );
});

final allCreditTransactionsWithCustomerProvider =
    StreamProvider<List<CreditTransactionWithCustomer>>((ref) {
      ref.keepAlive();
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) {
        return Stream.value(<CreditTransactionWithCustomer>[]);
      }

      return tenant.customers().snapshots().asyncMap(
            (snap) => _mergedCreditTransactionsWithCustomer(snap.docs),
          );
    });

final totalCreditsBalanceProvider = StreamProvider<double>((ref) {
  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(0.0);
  }
  return tenant.customers().snapshots().map((snap) {
    double total = 0;
    for (var doc in snap.docs) {
      total += parseFirestoreDouble(doc.data()['credits']);
    }
    return total;
  });
});

final searchCustomersProvider = FutureProvider.autoDispose
    .family<List<Customer>, String>((ref, query) async {
      final service = ref.read(customerServiceProvider);
      return service.searchCustomers(query);
    });

/// Provider for recently added customers (sorted by createdAt descending)
/// Useful for showing newly added customers at the top of search
final recentlyAddedCustomersProvider = StreamProvider<List<Customer>>((ref) {
  ref.keepAlive();

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) {
    return Stream.value(<Customer>[]);
  }
  return tenant
      .customers()
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList(),
      );
});
