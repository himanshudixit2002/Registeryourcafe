import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {
  String get formattedDateTime => DateFormat('dd MMM, hh:mm a').format(this);
  String get formattedDate => DateFormat('dd MMM yyyy').format(this);
  String get formattedTime => DateFormat('hh:mm a').format(this);
  String get formattedForPrint => DateFormat('dd/MM/yyyy HH:mm').format(this);

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  Timestamp get toTimestamp => Timestamp.fromDate(this);
  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);
}

extension DurationExtension on Duration {
  String get formattedHoursMinutes {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  String get humanReadable {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  double get inHoursDecimal => inMinutes / 60.0;
}

extension TimestampExtension on Timestamp {
  DateTime get dateTime => toDate();
  String get formattedDateTime => toDate().formattedDateTime;
  String get formattedDate => toDate().formattedDate;
}

class AppDateUtils {
  AppDateUtils._();

  static DateTime get todayStart => DateTime.now().startOfDay;
  static DateTime get todayEnd => DateTime.now().endOfDay;

  static DateTimeRange lastNDays(int days) {
    final now = DateTime.now();
    return DateTimeRange(
      start: now.subtract(Duration(days: days)).startOfDay,
      end: now.endOfDay,
    );
  }

  static DateTimeRange get thisWeek {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1)).startOfDay;
    return DateTimeRange(start: monday, end: now.endOfDay);
  }

  static DateTimeRange get thisMonth {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    return DateTimeRange(start: firstDay, end: now.endOfDay);
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  DateTimeRange({required this.start, required this.end});
  Duration get duration => end.difference(start);
}
