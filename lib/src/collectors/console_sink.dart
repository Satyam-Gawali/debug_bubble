import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../core/debug_log_entry.dart';
import '../core/debug_log_level.dart';
import '../export/text_exporter.dart';

/// Sink for printing sanitized log entries to standard console and developer log.
///
/// Implements guarded plain-text formatting per DATA_MODELS.md §9 and emits to
/// [debugPrint] and [dart:developer] log.
class ConsoleSink {
  const ConsoleSink();

  /// Test seam for observing console output in unit tests.
  @visibleForTesting
  static void Function(String formatted, DebugLogEntry entry)? testListener;

  /// Formats [entry] into a plain-text block per DATA_MODELS.md §9.
  String format(DebugLogEntry entry) => TextExporter.formatEntry(entry);

  /// Outputs [entry] to console. Wrapped in try/catch to never throw.
  void output(DebugLogEntry entry) {
    try {
      final formatted = format(entry);

      // Invoke test seam listener if registered
      testListener?.call(formatted, entry);

      // Output to Flutter debug console
      debugPrint(formatted);

      // Output to Dart developer logging protocol
      developer.log(
        formatted,
        name: 'debug_bubble',
        time: entry.timestamp,
        level: _toDeveloperLogLevel(entry.level),
        error: entry.error,
        stackTrace: entry.stackTrace != null
            ? StackTrace.fromString(entry.stackTrace!)
            : null,
      );
    } catch (_) {
      // Swallowed safely per NFR-03
    }
  }

  static int _toDeveloperLogLevel(DebugLogLevel level) {
    switch (level) {
      case DebugLogLevel.debug:
        return 500;
      case DebugLogLevel.info:
        return 800;
      case DebugLogLevel.success:
        return 850;
      case DebugLogLevel.warning:
        return 900;
      case DebugLogLevel.error:
        return 1000;
      case DebugLogLevel.critical:
        return 1200;
    }
  }
}
