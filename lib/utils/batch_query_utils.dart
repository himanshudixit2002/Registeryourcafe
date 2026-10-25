import 'package:cloud_firestore/cloud_firestore.dart';

class BatchQueryUtils {
  BatchQueryUtils._();

  static const int _batchSize = 10;

  static Future<List<T>> fetchByIds<T>({
    required CollectionReference<Map<String, dynamic>> collectionRef,
    required List<String> ids,
    required T Function(DocumentSnapshot doc) fromFirestore,
  }) async {
    if (ids.isEmpty) return [];

    final List<Future<QuerySnapshot<Map<String, dynamic>>>> futures = [];

    for (var i = 0; i < ids.length; i += _batchSize) {
      final batchIds = ids.sublist(
        i,
        i + _batchSize > ids.length ? ids.length : i + _batchSize,
      );
      futures.add(
        collectionRef.where(FieldPath.documentId, whereIn: batchIds).get(),
      );
    }

    final snapshots = await Future.wait(futures);
    final List<T> results = [];
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        results.add(fromFirestore(doc));
      }
    }
    return results;
  }

  static Future<List<T>> fetchByField<T>({
    required String collection,
    required String field,
    required List<dynamic> values,
    required T Function(DocumentSnapshot doc) fromFirestore,
    FirebaseFirestore? firestore,
  }) async {
    if (values.isEmpty) return [];

    final db = firestore ?? FirebaseFirestore.instance;
    final List<Future<QuerySnapshot<Map<String, dynamic>>>> futures = [];

    for (var i = 0; i < values.length; i += _batchSize) {
      final batchValues = values.sublist(
        i,
        i + _batchSize > values.length ? values.length : i + _batchSize,
      );
      futures.add(
        db.collection(collection).where(field, whereIn: batchValues).get(),
      );
    }

    final snapshots = await Future.wait(futures);
    final List<T> results = [];
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        results.add(fromFirestore(doc));
      }
    }
    return results;
  }

  static Future<void> deleteByIds({
    required String collection,
    required List<String> ids,
    FirebaseFirestore? firestore,
  }) async {
    if (ids.isEmpty) return;

    final db = firestore ?? FirebaseFirestore.instance;
    const maxBatchSize = 500;

    for (var i = 0; i < ids.length; i += maxBatchSize) {
      final batch = db.batch();
      final batchIds = ids.sublist(
        i,
        i + maxBatchSize > ids.length ? ids.length : i + maxBatchSize,
      );
      for (final id in batchIds) {
        batch.delete(db.collection(collection).doc(id));
      }
      await batch.commit();
    }
  }

  static Future<void> updateByIds({
    required String collection,
    required List<String> ids,
    required Map<String, dynamic> data,
    FirebaseFirestore? firestore,
  }) async {
    if (ids.isEmpty) return;

    final db = firestore ?? FirebaseFirestore.instance;
    const maxBatchSize = 500;

    for (var i = 0; i < ids.length; i += maxBatchSize) {
      final batch = db.batch();
      final batchIds = ids.sublist(
        i,
        i + maxBatchSize > ids.length ? ids.length : i + maxBatchSize,
      );
      for (final id in batchIds) {
        batch.update(db.collection(collection).doc(id), data);
      }
      await batch.commit();
    }
  }
}
