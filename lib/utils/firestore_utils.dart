import 'package:cloud_firestore/cloud_firestore.dart';
import 'result.dart';
import 'app_logger.dart';

class FirestoreUtils {
  FirestoreUtils._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Result<T, String>> getDocument<T>({
    required String collection,
    required String docId,
    required T Function(DocumentSnapshot doc) fromFirestore,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(docId).get();
      if (!doc.exists) return Result.failure('Document not found');
      return Result.success(fromFirestore(doc));
    } on FirebaseException catch (e) {
      final message = _parseFirebaseError(e);
      AppLogger.error('Firestore get error: $message', error: e);
      return Result.failure(message);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error fetching document',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure('Failed to fetch document: $e');
    }
  }

  static Future<Result<List<T>, String>> getDocuments<T>({
    required Query<Map<String, dynamic>> query,
    required T Function(DocumentSnapshot doc) fromFirestore,
  }) async {
    try {
      final snapshot = await query.get();
      final items = snapshot.docs.map(fromFirestore).toList();
      return Result.success(items);
    } on FirebaseException catch (e) {
      final message = _parseFirebaseError(e);
      AppLogger.error('Firestore query error: $message', error: e);
      return Result.failure(message);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error querying documents',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure('Failed to query documents: $e');
    }
  }

  static Future<Result<void, String>> setDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    try {
      await _firestore
          .collection(collection)
          .doc(docId)
          .set(data, SetOptions(merge: merge));
      return const Result.success(null);
    } on FirebaseException catch (e) {
      final message = _parseFirebaseError(e);
      AppLogger.error('Firestore set error: $message', error: e);
      return Result.failure(message);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error setting document',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure('Failed to save document: $e');
    }
  }

  static Future<Result<void, String>> updateDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
      return const Result.success(null);
    } on FirebaseException catch (e) {
      final message = _parseFirebaseError(e);
      AppLogger.error('Firestore update error: $message', error: e);
      return Result.failure(message);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error updating document',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure('Failed to update document: $e');
    }
  }

  static Future<Result<void, String>> deleteDocument({
    required String collection,
    required String docId,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
      return const Result.success(null);
    } on FirebaseException catch (e) {
      final message = _parseFirebaseError(e);
      AppLogger.error('Firestore delete error: $message', error: e);
      return Result.failure(message);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error deleting document',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure('Failed to delete document: $e');
    }
  }

  static Future<Result<String, String>> addDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    try {
      final docRef = await _firestore.collection(collection).add(data);
      return Result.success(docRef.id);
    } on FirebaseException catch (e) {
      final message = _parseFirebaseError(e);
      AppLogger.error('Firestore add error: $message', error: e);
      return Result.failure(message);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error adding document',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure('Failed to add document: $e');
    }
  }

  static Future<Result<T, String>> runTransaction<T>({
    required Future<T> Function(Transaction transaction) handler,
    String context = 'Transaction',
  }) async {
    try {
      final result = await _firestore.runTransaction(handler);
      return Result.success(result);
    } on FirebaseException catch (e) {
      final message = _parseFirebaseError(e);
      AppLogger.error('$context error: $message', error: e);
      return Result.failure(message);
    } catch (e, stackTrace) {
      AppLogger.error('$context failed', error: e, stackTrace: stackTrace);
      return Result.failure('$context failed: $e');
    }
  }

  static Future<Result<void, String>> runBatch({
    required void Function(WriteBatch batch) batchOperations,
    String context = 'Batch operation',
  }) async {
    try {
      final batch = _firestore.batch();
      batchOperations(batch);
      await batch.commit();
      return const Result.success(null);
    } on FirebaseException catch (e) {
      final message = _parseFirebaseError(e);
      AppLogger.error('$context error: $message', error: e);
      return Result.failure(message);
    } catch (e, stackTrace) {
      AppLogger.error('$context failed', error: e, stackTrace: stackTrace);
      return Result.failure('$context failed: $e');
    }
  }

  static String _parseFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You don\'t have permission to perform this action';
      case 'not-found':
        return 'The requested resource was not found';
      case 'already-exists':
        return 'This item already exists';
      case 'resource-exhausted':
        return 'Too many requests. Please try again later';
      case 'failed-precondition':
        return 'Operation cannot be performed in current state';
      case 'aborted':
        return 'Operation was cancelled. Please try again';
      case 'out-of-range':
        return 'Operation was out of valid range';
      case 'unimplemented':
        return 'This feature is not available';
      case 'internal':
        return 'An internal error occurred. Please try again';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please try again';
      case 'data-loss':
        return 'Data could not be recovered';
      case 'unauthenticated':
        return 'Please sign in to continue';
      case 'cancelled':
        return 'Operation was cancelled';
      case 'invalid-argument':
        return 'Invalid data provided';
      case 'deadline-exceeded':
        return 'Operation timed out. Please try again';
      default:
        return e.message ?? 'An error occurred';
    }
  }
}

/// Parses Firestore / JSON values expected to be numeric. [bool] and other
/// non-numeric types yield [fallback] (or null for [parseFirestoreDoubleOrNull]).
double parseFirestoreDouble(dynamic value, {double fallback = 0.0}) {
  return parseFirestoreDoubleOrNull(value) ?? fallback;
}

double? parseFirestoreDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }
  return null;
}

int parseFirestoreInt(dynamic value, {int fallback = 0}) {
  return parseFirestoreIntOrNull(value) ?? fallback;
}

int? parseFirestoreIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }
  return null;
}

/// UIDs and string ids stored as [String], [int], or [num] in legacy imports.
String? parseFirestoreStringOrNull(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final s = value.trim();
    return s.isEmpty ? null : s;
  }
  if (value is int) return value.toString();
  if (value is double) {
    final r = value.roundToDouble();
    return r == value ? value.toInt().toString() : value.toString();
  }
  if (value is num) return value.toString();
  return null;
}

extension SafeDocumentSnapshot on DocumentSnapshot<Map<String, dynamic>> {
  T getField<T>(String key, T defaultValue) {
    final data = this.data();
    if (data == null || !data.containsKey(key)) return defaultValue;
    final value = data[key];
    if (value is T) return value;
    return defaultValue;
  }

  T? getFieldOrNull<T>(String key) {
    final data = this.data();
    if (data == null || !data.containsKey(key)) return null;
    final value = data[key];
    if (value is T) return value;
    return null;
  }

  double getDouble(String key, [double defaultValue = 0.0]) {
    final data = this.data();
    if (data == null || !data.containsKey(key)) return defaultValue;
    return parseFirestoreDouble(data[key], fallback: defaultValue);
  }

  int getInt(String key, [int defaultValue = 0]) {
    final data = this.data();
    if (data == null || !data.containsKey(key)) return defaultValue;
    return parseFirestoreInt(data[key], fallback: defaultValue);
  }

  DateTime? getDateTime(String key) {
    final data = this.data();
    if (data == null || !data.containsKey(key)) return null;
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
