class Validators {
  Validators._();

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 10) return 'Phone number must be 10 digits';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return 'Invalid phone number format';
    }
    return null;
  }

  static bool isValidPhone(String? value) => validatePhone(value) == null;

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }

  static String? validateOptionalEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    return validateEmail(value);
  }

  static bool isValidEmail(String? value) => validateEmail(value) == null;

  static String? validateName(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(value.trim())) {
      return '$fieldName contains invalid characters';
    }
    return null;
  }

  static bool isValidName(String? value) => validateName(value) == null;

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain an uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain a lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(value)) return 'Password must contain a number';
    return null;
  }

  static String? validatePositiveNumber(
    String? value, {
    String fieldName = 'Value',
  }) {
    if (value == null || value.isEmpty) return '$fieldName is required';
    final number = double.tryParse(value);
    if (number == null) return '$fieldName must be a valid number';
    if (number <= 0) return '$fieldName must be greater than 0';
    return null;
  }

  static String? validateNonNegativeNumber(
    String? value, {
    String fieldName = 'Value',
  }) {
    if (value == null || value.isEmpty) return '$fieldName is required';
    final number = double.tryParse(value);
    if (number == null) return '$fieldName must be a valid number';
    if (number < 0) return '$fieldName cannot be negative';
    return null;
  }

  static String? validatePincode(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return 'Pincode must be 6 digits';
    return null;
  }

  static String? validateCreditCode(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Credit code must be 6 digits';
    }
    return null;
  }

  static String? validateRequired(
    String? value, {
    String fieldName = 'This field',
  }) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? validateAmount(
    String? value, {
    String fieldName = 'Amount',
    double? minAmount,
    double? maxAmount,
  }) {
    if (value == null || value.isEmpty) return '$fieldName is required';
    final amount = double.tryParse(value);
    if (amount == null) return '$fieldName must be a valid number';
    if (amount < 0) return '$fieldName cannot be negative';
    if (minAmount != null && amount < minAmount) {
      return '$fieldName must be at least ₹$minAmount';
    }
    if (maxAmount != null && amount > maxAmount) {
      return '$fieldName cannot exceed ₹$maxAmount';
    }
    return null;
  }
}

extension ValidationResult on String? {
  bool get isValid => this == null;
  bool get hasError => this != null;
}
