class PhoneUtils {
  PhoneUtils._();

  static const String defaultCountryCode = '91';
  static const int minDigits = 10;

  static String sanitize(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  static String withCountryCode(
    String phone, {
    String countryCode = defaultCountryCode,
  }) {
    final digits = sanitize(phone);
    if (digits.length == minDigits) return '$countryCode$digits';
    return digits;
  }

  static bool isValid(String phone) => sanitize(phone).length >= minDigits;

  static bool hasCountryCode(String phone) =>
      sanitize(phone).length > minDigits;

  static String formatForDisplay(String phone) {
    final digits = sanitize(phone);
    if (digits.length == 10) {
      return '${digits.substring(0, 5)} ${digits.substring(5)}';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    }
    return phone;
  }

  static String getWhatsAppUrl(String phone, {String? message}) {
    final digits = withCountryCode(phone);
    if (digits.length < 11) throw ArgumentError('Invalid phone number: $phone');

    if (message != null && message.isNotEmpty) {
      return 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}';
    }
    return 'https://wa.me/$digits';
  }

  static String mask(String phone) {
    final digits = sanitize(phone);
    if (digits.length < 4) return phone;
    return '****${digits.substring(digits.length - 4)}';
  }
}
