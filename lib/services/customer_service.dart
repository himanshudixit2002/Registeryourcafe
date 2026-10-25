import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';
import '../constants/firestore_collections.dart';
import '../utils/app_logger.dart';

class CustomerService {
  final FirebaseFirestore _db;
  static const int _pageSize = 20;
  static const int _searchLimit = 40;

  CustomerService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Future<List<Customer>> searchCustomers(String query, {int? limit}) async {
    final searchLimit = limit ?? _searchLimit;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final results = <Customer>[];
    final lower = trimmed.toLowerCase();

    try {
      final nameSnap = await _db
          .collection(FirestoreCollections.customers)
          .orderBy('nameLower')
          .startAt([lower])
          .endAt(["$lower\uf8ff"])
          .limit(searchLimit)
          .get();
      results.addAll(nameSnap.docs.map((d) => Customer.fromFirestore(d)));
    } catch (e) {
      AppLogger.warning(
        'Falling back to case-sensitive name search',
        tag: 'CustomerService',
      );
      try {
        final altSnap = await _db
            .collection(FirestoreCollections.customers)
            .orderBy('name')
            .startAt([trimmed])
            .endAt(["$trimmed\uf8ff"])
            .limit(searchLimit)
            .get();
        results.addAll(altSnap.docs.map((d) => Customer.fromFirestore(d)));
      } catch (e, st) {
        AppLogger.error(
          'Customer name fallback search failed',
          tag: 'CustomerService',
          error: e,
          stackTrace: st,
        );
      }
    }

    final isNumeric = RegExp(r'^\d+$').hasMatch(trimmed);
    if (isNumeric) {
      try {
        final phoneSnap = await _db
            .collection(FirestoreCollections.customers)
            .where('phoneNumber', isEqualTo: trimmed)
            .limit(searchLimit)
            .get();
        results.addAll(phoneSnap.docs.map((d) => Customer.fromFirestore(d)));
      } catch (e, st) {
        AppLogger.error(
          'Customer phone search failed',
          tag: 'CustomerService',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (trimmed.contains('-') ||
        trimmed.toUpperCase().startsWith(RegExp(r'^[A-Z]'))) {
      try {
        final membershipSnap = await _db
            .collection(FirestoreCollections.customers)
            .where('membershipId', isEqualTo: trimmed.toUpperCase())
            .limit(searchLimit)
            .get();
        results.addAll(
          membershipSnap.docs.map((d) => Customer.fromFirestore(d)),
        );
      } catch (e, st) {
        AppLogger.error(
          'Customer membershipId search failed',
          tag: 'CustomerService',
          error: e,
          stackTrace: st,
        );
      }
    }

    var deduped = {for (var c in results) c.id: c}.values.toList();

    if (deduped.isEmpty) {
      deduped = await _fallbackSearch(lower, searchLimit);
    }

    return deduped;
  }

  Future<List<Customer>> _fallbackSearch(String lowerQuery, int limit) async {
    try {
      final bulkSnap = await _db
          .collection(FirestoreCollections.customers)
          .limit(1000)
          .get();
      return bulkSnap.docs
          .map((d) => Customer.fromFirestore(d))
          .where((c) => c.name.toLowerCase().contains(lowerQuery))
          .take(limit)
          .toList();
    } catch (e, st) {
      AppLogger.warning(
        'Customer fallback bulk search failed: $e',
        tag: 'CustomerService',
      );
      AppLogger.debug('$st', tag: 'CustomerService');
      return [];
    }
  }

  Future<List<Customer>> getInitialCustomers() async {
    final snapshot = await _db
        .collection(FirestoreCollections.customers)
        .orderBy('name')
        .limit(_pageSize)
        .get();
    return snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList();
  }

  Future<List<Customer>> getMoreCustomers(DocumentSnapshot lastDoc) async {
    final snapshot = await _db
        .collection(FirestoreCollections.customers)
        .orderBy('name')
        .startAfterDocument(lastDoc)
        .limit(_pageSize)
        .get();
    return snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList();
  }

  Future<String> createCustomer(Customer customer) async {
    final docRef = _db.collection(FirestoreCollections.customers).doc();
    await docRef.set(customer.toFirestore());
    AppLogger.firestore(
      'CREATE',
      FirestoreCollections.customers,
      docId: docRef.id,
    );
    return docRef.id;
  }

  Future<void> updateCustomer(Customer customer) async {
    await _db
        .collection(FirestoreCollections.customers)
        .doc(customer.id)
        .update(customer.toFirestore());
    AppLogger.firestore(
      'UPDATE',
      FirestoreCollections.customers,
      docId: customer.id,
    );
  }

  Future<Customer?> getCustomer(String customerId) async {
    final doc = await _db
        .collection(FirestoreCollections.customers)
        .doc(customerId)
        .get();
    return doc.exists ? Customer.fromFirestore(doc) : null;
  }

  Future<Customer?> getCustomerByCreditCode(String creditCode) async {
    final snapshot = await _db
        .collection(FirestoreCollections.customers)
        .where('creditCode', isEqualTo: creditCode)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Customer.fromFirestore(snapshot.docs.first);
  }

  Future<void> updateCredits(String customerId, double newCredits) async {
    await _db.collection(FirestoreCollections.customers).doc(customerId).update(
      {'credits': newCredits, 'updatedAt': FieldValue.serverTimestamp()},
    );
    AppLogger.firestore(
      'UPDATE credits',
      FirestoreCollections.customers,
      docId: customerId,
    );
  }

  Future<void> adjustCredits(
    String customerId,
    double amount, {
    required String type,
    required String method,
    String? note,
    String? performedById,
    String? performedByName,
    String? performedByRole,
    Map<String, dynamic>? reference,
  }) async {
    final customerRef = _db
        .collection(FirestoreCollections.customers)
        .doc(customerId);
    final batch = _db.batch();

    batch.update(customerRef, {
      'credits': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final txRef = customerRef
        .collection(FirestoreCollections.creditTransactions)
        .doc();
    batch.set(txRef, {
      'date': FieldValue.serverTimestamp(),
      'amount': amount,
      'type': type,
      'method': method,
      'note': ?note,
      'performedById': ?performedById,
      'performedByName': ?performedByName,
      'performedByRole': ?performedByRole,
      'reference': ?reference,
    });

    await batch.commit();
    AppLogger.firestore(
      'ADJUST credits',
      FirestoreCollections.customers,
      docId: customerId,
    );
  }

  int get pageSize => _pageSize;
}
