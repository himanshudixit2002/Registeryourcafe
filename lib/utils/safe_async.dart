import 'dart:async';
import 'package:flutter/material.dart';
import 'package:registeryourcafe/theme/app_theme.dart';
import 'result.dart';
import 'app_logger.dart';

class SafeAsync {
  SafeAsync._();

  static Future<Result<T, String>> run<T>(
    Future<T> Function() operation, {
    String? context,
  }) async {
    try {
      final value = await operation();
      return Result.success(value);
    } catch (e, stackTrace) {
      final message = context != null ? '$context: $e' : e.toString();
      AppLogger.error(message, error: e, stackTrace: stackTrace);
      return Result.failure(message);
    }
  }

  static Future<Result<T, String>> runWithTimeout<T>(
    Future<T> Function() operation, {
    required Duration timeout,
    String? context,
    String timeoutMessage = 'Operation timed out',
  }) async {
    try {
      final value = await operation().timeout(timeout);
      return Result.success(value);
    } on TimeoutException {
      final message = context != null
          ? '$context: $timeoutMessage'
          : timeoutMessage;
      AppLogger.warning(message);
      return Result.failure(message);
    } catch (e, stackTrace) {
      final message = context != null ? '$context: $e' : e.toString();
      AppLogger.error(message, error: e, stackTrace: stackTrace);
      return Result.failure(message);
    }
  }

  static Future<Result<T, String>> runWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    String? context,
    bool Function(Object error)? shouldRetry,
  }) async {
    Object? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final value = await operation();
        return Result.success(value);
      } catch (e, stackTrace) {
        lastError = e;

        final shouldRetryError = shouldRetry?.call(e) ?? true;
        if (!shouldRetryError || attempt == maxRetries) {
          final message = context != null
              ? '$context (after $attempt attempts): $e'
              : 'Failed after $attempt attempts: $e';
          AppLogger.error(message, error: e, stackTrace: stackTrace);
          return Result.failure(message);
        }

        AppLogger.warning(
          '${context ?? 'Operation'} failed (attempt $attempt/$maxRetries), retrying...',
        );
        await Future<void>.delayed(retryDelay * attempt);
      }
    }

    return Result.failure(lastError?.toString() ?? 'Unknown error');
  }

  static Future<List<Result<T, String>>> runAll<T>(
    List<Future<T> Function()> operations, {
    String? context,
  }) async {
    return Future.wait(operations.map((op) => run(op, context: context)));
  }
}

extension ResultSnackbarExtension<T> on Result<T, String> {
  void showErrorSnackbar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    when(
      success: (_) {},
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: TextStyle(color: cs.onError)),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void showResultSnackbar(
    BuildContext context, {
    required String successMessage,
  }) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMessage,
              style: TextStyle(color: sem.onSuccessContainer),
            ),
            backgroundColor: sem.successContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: TextStyle(color: cs.onError)),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}

extension AsyncStateExtension<T> on Future<Result<T, String>> {
  Future<Result<T, String>> withLoadingDialog(
    BuildContext context, {
    String message = 'Loading...',
  }) async {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await this;
      if (context.mounted) Navigator.of(context).pop();
      return result;
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      rethrow;
    }
  }
}
