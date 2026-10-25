import 'package:cloud_firestore/cloud_firestore.dart';
import '../firestore/tenant_firestore.dart';
import 'result.dart';
import 'app_logger.dart';
import 'firestore_utils.dart';

class FirestoreTransactionHelper {
  FirestoreTransactionHelper._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int defaultMaxRetries = 3;

  static Future<Result<T, String>> runTransaction<T>({
    required Future<T> Function(Transaction transaction) handler,
    String description = 'Transaction',
    int maxRetries = defaultMaxRetries,
  }) async {
    int attempts = 0;
    Object? lastError;

    while (attempts < maxRetries) {
      attempts++;
      try {
        final result = await _firestore.runTransaction(handler);
        return Result.success(result);
      } on FirebaseException catch (e) {
        lastError = e;
        if (_isRetryableError(e) && attempts < maxRetries) {
          AppLogger.warning(
            '$description failed (attempt $attempts), retrying...',
            tag: 'FirestoreTransaction',
          );
          await Future<void>.delayed(Duration(milliseconds: 100 * attempts));
          continue;
        }
        return Result.failure(_parseFirebaseError(e, description));
      } catch (e) {
        lastError = e;
        return Result.failure('$description failed: $e');
      }
    }
    return Result.failure(
      '$description failed after $attempts attempts: $lastError',
    );
  }

  static Future<Result<void, String>> runBatch({
    required void Function(WriteBatch batch) operations,
    String description = 'Batch operation',
    int maxRetries = defaultMaxRetries,
  }) async {
    int attempts = 0;
    Object? lastError;

    while (attempts < maxRetries) {
      attempts++;
      try {
        final batch = _firestore.batch();
        operations(batch);
        await batch.commit();
        return const Result.success(null);
      } on FirebaseException catch (e) {
        lastError = e;
        if (_isRetryableError(e) && attempts < maxRetries) {
          AppLogger.warning(
            '$description failed (attempt $attempts), retrying...',
            tag: 'FirestoreTransaction',
          );
          await Future<void>.delayed(Duration(milliseconds: 100 * attempts));
          continue;
        }
        return Result.failure(_parseFirebaseError(e, description));
      } catch (e) {
        lastError = e;
        return Result.failure('$description failed: $e');
      }
    }
    return Result.failure(
      '$description failed after $attempts attempts: $lastError',
    );
  }

  static Future<Result<void, String>> atomicUpdate({
    required DocumentReference docRef,
    required Map<String, dynamic> Function(Map<String, dynamic> currentData)
    updater,
    String description = 'Atomic update',
  }) async {
    return runTransaction(
      handler: (transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Document does not exist');
        final currentData = snapshot.data() as Map<String, dynamic>;
        transaction.update(docRef, updater(currentData));
      },
      description: description,
    );
  }

  static Future<Result<void, String>> transferCredits({
    required TenantRef tenant,
    required String fromCustomerId,
    required String toCustomerId,
    required double amount,
    required String reason,
    required String performedById,
    required String performedByName,
    required String performedByRole,
  }) async {
    if (amount <= 0) {
      return const Result.failure('Transfer amount must be positive');
    }

    return runTransaction(
      handler: (transaction) async {
        final fromRef = tenant.customers().doc(fromCustomerId);
        final toRef = tenant.customers().doc(toCustomerId);

        final fromSnap = await transaction.get(fromRef);
        final toSnap = await transaction.get(toRef);

        if (!fromSnap.exists || !toSnap.exists) {
          throw Exception('One or both customers not found');
        }

        final fromCredits = parseFirestoreDouble(fromSnap.data()?['credits']);
        if (fromCredits < amount) {
          throw Exception('Insufficient credits for transfer');
        }

        // Debit from source customer
        transaction.update(fromRef, {
          'credits': FieldValue.increment(-amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final fromTxRef = fromRef.collection('credit_transactions').doc();
        transaction.set(fromTxRef, {
          'date': FieldValue.serverTimestamp(),
          'amount': -amount,
          'type': 'debit',
          'method': 'credits',
          'note': 'Transfer to customer: $reason',
          'performedById': performedById,
          'performedByName': performedByName,
          'performedByRole': performedByRole,
          'reference': {
            'type': 'transfer',
            'id': toCustomerId,
            'transferTo': toCustomerId,
          },
        });

        transaction.update(toRef, {
          'credits': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final toTxRef = toRef.collection('credit_transactions').doc();
        transaction.set(toTxRef, {
          'date': FieldValue.serverTimestamp(),
          'amount': amount,
          'type': 'credit',
          'method': 'credits',
          'note': 'Transfer from customer: $reason',
          'performedById': performedById,
          'performedByName': performedByName,
          'performedByRole': performedByRole,
          'reference': {
            'type': 'transfer',
            'id': fromCustomerId,
            'transferFrom': fromCustomerId,
          },
        });
      },
      description: 'Credit transfer',
    );
  }

  static bool _isRetryableError(FirebaseException e) {
    return [
      'unavailable',
      'deadline-exceeded',
      'resource-exhausted',
      'aborted',
    ].contains(e.code);
  }

  static String _parseFirebaseError(FirebaseException e, String context) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied for $context';
      case 'not-found':
        return 'Document not found during $context';
      case 'already-exists':
        return 'Document already exists during $context';
      case 'resource-exhausted':
        return 'Too many requests. Please try again later.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'deadline-exceeded':
        return 'Operation timed out. Please try again.';
      case 'aborted':
        return 'Operation was cancelled. Please try again.';
      default:
        return '$context failed: ${e.message ?? e.code}';
    }
  }
}
