import '../models/session.dart';
import '../models/customer.dart';

class BusinessValidators {
  BusinessValidators._();

  static void validateSessionCanEnd(TableSession session) {
    if (session.status != SessionStatus.active) {
      throw InvalidStateException(
        'Session is not active (current: ${session.status.name})',
      );
    }
  }

  static void validateSessionCanRefund(TableSession session) {
    if (session.status == SessionStatus.active) {
      throw InvalidStateException('Cannot refund an active session');
    }
    if (session.isRefunded) {
      throw InvalidStateException('Session has already been refunded');
    }
  }

  static void validateRefundAmount(double refundAmount, double maxAmount) {
    if (refundAmount <= 0) {
      throw InvalidAmountException('Refund amount must be greater than zero');
    }
    if (refundAmount > maxAmount) {
      throw InvalidAmountException(
        'Refund ₹${refundAmount.toStringAsFixed(2)} exceeds max ₹${maxAmount.toStringAsFixed(2)}',
      );
    }
  }

  static void validateSufficientCredits(Customer customer, double required) {
    if (customer.credits < required) {
      throw InsufficientCreditsException(
        'Available: ₹${customer.credits.toStringAsFixed(2)}, Required: ₹${required.toStringAsFixed(2)}',
      );
    }
  }

  static void validateOrderCanRefund({
    required bool isRefunded,
    required String? sessionId,
    required bool isActiveSession,
    required bool allowActiveSessionRefund,
  }) {
    if (isRefunded) {
      throw InvalidStateException('Order already refunded');
    }
    if (sessionId != null && isActiveSession && !allowActiveSessionRefund) {
      throw InvalidStateException('Cannot refund order from active session');
    }
  }

  static void validateStockAvailability({
    required String itemName,
    required double available,
    required double requested,
  }) {
    if (available < requested) {
      throw InsufficientStockException(
        '"$itemName": available ${available.toStringAsFixed(1)}, requested ${requested.toStringAsFixed(1)}',
      );
    }
  }

  static void validateItemsNotEmpty(List items, String itemType) {
    if (items.isEmpty) {
      throw InvalidInputException('At least one $itemType is required');
    }
  }

  static void validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      throw InvalidInputException('$fieldName is required');
    }
  }

  static void validateIdExists(String? id, String entityName) {
    if (id == null || id.isEmpty) {
      throw NotFoundException('$entityName ID is required');
    }
  }
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => message;
}

class InvalidStateException implements Exception {
  final String message;
  InvalidStateException(this.message);
  @override
  String toString() => message;
}

class InvalidAmountException implements Exception {
  final String message;
  InvalidAmountException(this.message);
  @override
  String toString() => message;
}

class InsufficientCreditsException implements Exception {
  final String message;
  InsufficientCreditsException(this.message);
  @override
  String toString() => message;
}

class InsufficientStockException implements Exception {
  final String message;
  InsufficientStockException(this.message);
  @override
  String toString() => message;
}

class InvalidInputException implements Exception {
  final String message;
  InvalidInputException(this.message);
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
  @override
  String toString() => message;
}

extension BusinessExceptionExtension on Exception {
  String get userMessage {
    if (this is UnauthorizedException) {
      return (this as UnauthorizedException).message;
    }
    if (this is InvalidStateException) {
      return (this as InvalidStateException).message;
    }
    if (this is InvalidAmountException) {
      return (this as InvalidAmountException).message;
    }
    if (this is InsufficientCreditsException) {
      return (this as InsufficientCreditsException).message;
    }
    if (this is InsufficientStockException) {
      return (this as InsufficientStockException).message;
    }
    if (this is InvalidInputException) {
      return (this as InvalidInputException).message;
    }
    if (this is NotFoundException) return (this as NotFoundException).message;
    return 'An unexpected error occurred';
  }
}
