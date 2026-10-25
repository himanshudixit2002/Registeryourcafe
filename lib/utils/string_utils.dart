extension StringExtension on String {
  String get capitalize {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }

  String get capitalizeWords {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  String get camelToTitle {
    if (isEmpty) return '';
    return replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (Match m) => ' ${m[0]!}',
    ).capitalize;
  }

  String get formatDiscountName {
    if (isEmpty) return '';
    return replaceAll('Percentage', '').camelToTitle;
  }

  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }

  String get removeLeadingZeros {
    if (isEmpty) return this;
    return replaceFirst(RegExp(r'^0+'), '');
  }

  bool get isValidPhone => RegExp(r'^\d{10}$').hasMatch(this);
  bool get isValidEmail =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  bool get isNumeric => RegExp(r'^\d+$').hasMatch(this);

  String get maskedPhone {
    if (length < 10) return this;
    return '${substring(0, 2)}****${substring(length - 4)}';
  }

  String get maskedEmail {
    final parts = split('@');
    if (parts.length != 2) return this;
    final name = parts[0];
    if (name.isEmpty) return this;
    return '${name[0]}***@${parts[1]}';
  }
}

class AppStringUtils {
  AppStringUtils._();

  static String getInitials(String name, {int maxLength = 2}) {
    if (name.isEmpty) return '';
    final words = name.trim().split(RegExp(r'\s+'));
    return words
        .take(maxLength)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String pluralize(int count, String singular, {String? plural}) {
    if (count == 1) return singular;
    return plural ?? '${singular}s';
  }
}
