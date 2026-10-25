abstract class ServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const ServiceException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;

  String get userMessage => message;
  bool get isRetryable => false;
}

class FirestoreException extends ServiceException {
  FirestoreException(super.message, {super.code, super.originalError});

  @override
  bool get isRetryable =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'resource-exhausted';
}

class OrderException extends ServiceException {
  const OrderException(super.message, {super.code});
}

class SessionException extends ServiceException {
  const SessionException(super.message, {super.code});
}

class PaymentException extends ServiceException {
  const PaymentException(super.message, {super.code});
}

class CustomerException extends ServiceException {
  const CustomerException(super.message, {super.code});
}

class TableException extends ServiceException {
  const TableException(super.message, {super.code});
}

class LeaderboardException extends ServiceException {
  const LeaderboardException(super.message, {super.code});
}

class PrinterException extends ServiceException {
  const PrinterException(super.message, {super.code});

  @override
  bool get isRetryable => true;
}

class AuthException extends ServiceException {
  const AuthException(super.message, {super.code});
}

class StorageException extends ServiceException {
  StorageException(super.message, {super.code, super.originalError});

  @override
  bool get isRetryable => true;
}

class ExceptionHandler {
  ExceptionHandler._();

  static ServiceException wrap(dynamic error, {String? context}) {
    if (error is ServiceException) return error;

    final message = context != null
        ? '$context: ${error.toString()}'
        : error.toString();

    if (error.toString().contains('permission-denied')) {
      return FirestoreException(
        'Permission denied. Please check your access rights.',
        code: 'permission-denied',
        originalError: error,
      );
    }
    if (error.toString().contains('not-found')) {
      return FirestoreException(
        'The requested resource was not found.',
        code: 'not-found',
        originalError: error,
      );
    }
    if (error.toString().contains('unavailable')) {
      return FirestoreException(
        'Service temporarily unavailable. Please try again.',
        code: 'unavailable',
        originalError: error,
      );
    }

    return FirestoreException(message, originalError: error);
  }

  static String getUserMessage(dynamic error) {
    if (error is ServiceException) return error.userMessage;

    final errorStr = error.toString();
    if (errorStr.contains('permission-denied')) {
      return 'You don\'t have permission to perform this action.';
    }
    if (errorStr.contains('not-found')) {
      return 'The requested item was not found.';
    }
    if (errorStr.contains('unavailable')) {
      return 'Service is temporarily unavailable. Please try again later.';
    }
    if (errorStr.contains('deadline-exceeded')) {
      return 'The operation timed out. Please try again.';
    }
    if (errorStr.contains('network')) {
      return 'Network error. Please check your connection.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  static bool isRetryable(dynamic error) {
    if (error is ServiceException) return error.isRetryable;

    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('unavailable') ||
        errorStr.contains('timeout') ||
        errorStr.contains('deadline') ||
        errorStr.contains('network');
  }
}

extension ExceptionExtension on Exception {
  String toUserMessage() => ExceptionHandler.getUserMessage(this);
}
