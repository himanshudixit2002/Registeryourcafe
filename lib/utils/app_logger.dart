import 'dart:async';

import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, visibleForTesting;

import '../app_build_info.dart';

/// One captured [AppLogger.error] entry for in-app diagnostics / support copy.
class AppLogErrorRecord {
  AppLogErrorRecord({
    required this.at,
    required this.message,
    this.tag,
    this.errorString,
    this.stackTraceSnippet,
  });

  final DateTime at;
  final String message;
  final String? tag;
  final String? errorString;
  final String? stackTraceSnippet;

  String get lineSummary {
    final t = tag ?? '—';
    final err = errorString != null ? ' | $errorString' : '';
    return '[${at.toIso8601String()}] [$t] $message$err';
  }
}

class AppLogger {
  AppLogger._();

  static const String _defaultTag = 'CueAndCoffee';

  /// Max entries kept in [recentErrorRecords] / [supportSnippet].
  static const int recentErrorCapacity = 5;

  static final List<AppLogErrorRecord> _recentErrors = [];

  /// Last [error] calls (oldest evicted first), capped at [recentErrorCapacity].
  static List<AppLogErrorRecord> get recentErrorRecords =>
      List<AppLogErrorRecord>.unmodifiable(_recentErrors);

  /// Plain-text block for support email / chat (no PII beyond what errors already contain).
  static String supportSnippet() {
    final header = StringBuffer()
      ..writeln('App: ${AppBuildInfo.label}')
      ..writeln('debug: $kDebugMode, web: $kIsWeb')
      ..writeln('---');

    if (_recentErrors.isEmpty) {
      return '${header}No recent errors recorded in this session.';
    }
    final buf = StringBuffer()..write(header);
    for (var i = 0; i < _recentErrors.length; i++) {
      if (i > 0) buf.writeln('\n---\n');
      final r = _recentErrors[i];
      buf.writeln(r.lineSummary);
      if (r.stackTraceSnippet?.trim().isNotEmpty ?? false) {
        buf.writeln(r.stackTraceSnippet);
      }
    }
    return buf.toString();
  }

  @visibleForTesting
  static void clearRecentErrorsForTest() {
    _recentErrors.clear();
  }

  static void _recordError({
    required String message,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final errStr = error?.toString();
    String? stStr;
    if (stackTrace != null) {
      final raw = stackTrace.toString();
      stStr = raw.length <= 1600 ? raw : '${raw.substring(0, 1600)}\n… (truncated)';
    }
    _recentErrors.add(
      AppLogErrorRecord(
        at: DateTime.now().toUtc(),
        message: message,
        tag: tag,
        errorString: errStr,
        stackTraceSnippet: stStr,
      ),
    );
    while (_recentErrors.length > recentErrorCapacity) {
      _recentErrors.removeAt(0);
    }
  }

  /// Optional release-time sink (e.g. Firebase Crashlytics). Called from [error]
  /// after debug console output. Leave unset if you only use debug logs.
  static void Function(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  })? onErrorReport;

  static void info(String message, {String? tag}) {
    if (kDebugMode) print('[info] [${tag ?? _defaultTag}] $message');
  }

  static void debug(String message, {String? tag}) {
    if (kDebugMode) print('[dbg] [${tag ?? _defaultTag}] $message');
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) print('[warn] [${tag ?? _defaultTag}] $message');
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    bool skipExternalReport = false,
  }) {
    _recordError(message: message, tag: tag, error: error, stackTrace: stackTrace);
    if (kDebugMode) {
      print('[err] [${tag ?? _defaultTag}] $message');
      if (error != null) print('   Error: $error');
      if (stackTrace != null) print('   Stack Trace: $stackTrace');
    }
    if (skipExternalReport) return;
    final r = onErrorReport;
    if (r != null) {
      r(message, error: error, stackTrace: stackTrace, tag: tag);
    }
  }

  /// Firestore [permission-denied] / insufficient permissions (some roles or rules).
  static bool isLikelyFirestorePermissionDenied(Object error) {
    final s = error.toString();
    return s.contains('permission-denied') ||
        s.contains('Permission') ||
        s.contains('PERMISSION_DENIED') ||
        s.contains('Missing or insufficient permissions');
  }

  /// Non-fatal provider work (e.g. default seed). Permission denials log as [warning]
  /// without a stack trace to cut noise and odd web hot-restart scheduler churn.
  static void logNonFatalProviderSideEffect(
    String message,
    Object error,
    StackTrace stackTrace, {
    String? tag,
  }) {
    if (isLikelyFirestorePermissionDenied(error)) {
      scheduleMicrotask(
        () => warning('$message — $error', tag: tag),
      );
    } else {
      AppLogger.error(
        message,
        tag: tag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void success(String message, {String? tag}) {
    if (kDebugMode) print('[ok] [${tag ?? _defaultTag}] $message');
  }

  static void firestore(String operation, String collection, {String? docId}) {
    if (kDebugMode) {
      final docInfo = docId != null ? ' (doc: $docId)' : '';
      print('[fs] [Firestore] $operation on $collection$docInfo');
    }
  }

  static void print_(String message) {
    if (kDebugMode) print('[print] [Printer] $message');
  }
}
