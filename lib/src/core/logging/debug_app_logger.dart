import 'package:flutter/foundation.dart';

import 'app_logger.dart';

class DebugAppLogger implements AppLogger {
  const DebugAppLogger();

  @override
  void info(String message, {Map<String, Object?> context = const {}}) {
    debugPrint('[info] $message ${_formatContext(context)}');
  }

  @override
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    debugPrint('[warning] $message ${_formatContext(context)}');
    if (error != null) {
      debugPrint('  error: $error');
    }
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    debugPrint('[error] $message ${_formatContext(context)}');
    if (error != null) {
      debugPrint('  error: $error');
    }
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _formatContext(Map<String, Object?> context) {
    if (context.isEmpty) {
      return '';
    }

    return context.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
  }
}
