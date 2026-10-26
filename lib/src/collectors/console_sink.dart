import 'package:flutter/foundation.dart';

import '../core/debug_log_entry.dart';
import '../core/debug_log_level.dart';
import '../export/text_exporter.dart';

/// Sink for printing sanitized log entries to standard console with severity-based ANSI colors.
///
/// Implements guarded formatting per DATA_MODELS.md §9 and emits to [debugPrint]
/// or a configured [outputCallback] exactly once per entry.
class ConsoleSink {
  const ConsoleSink({
    this.useColor = true,
    this.outputCallback,
  });

  /// Whether ANSI terminal colors are enabled by default.
  final bool useColor;

  /// Optional custom output callback. If null, [debugPrint] is used.
  final void Function(String formatted)? outputCallback;

  /// Test seam for observing console output in unit tests.
  @visibleForTesting
  static void Function(String formatted, DebugLogEntry entry)? testListener;

  /// ANSI escape code to reset terminal formatting.
  static const String resetAnsi = '\x1B[0m';

  /// ANSI color codes mapped by severity level.
  static const Map<DebugLogLevel, String> levelAnsiColors = {
    DebugLogLevel.debug: '\x1B[90m', // Grey (Bright Black)
    DebugLogLevel.info: '\x1B[36m', // Cyan
    DebugLogLevel.success: '\x1B[32m', // Green
    DebugLogLevel.warning: '\x1B[33m', // Yellow
    DebugLogLevel.error: '\x1B[31m', // Red
    DebugLogLevel.critical: '\x1B[35m', // Magenta
  };

  /// Returns the ANSI color code for [level].
  static String ansiColorForLevel(DebugLogLevel level) =>
      levelAnsiColors[level] ?? resetAnsi;

  /// Formats [entry] into a text block per DATA_MODELS.md §9.
  ///
  /// When [color] is true (or null when [useColor] is true), wraps the output in
  /// severity-specific ANSI escape codes followed by [resetAnsi].
  String format(DebugLogEntry entry, {bool? color}) {
    final plainText = TextExporter.formatEntry(entry);
    final shouldColor = color ?? useColor;
    if (!shouldColor) return plainText;

    final ansi = ansiColorForLevel(entry.level);
    return '$ansi$plainText$resetAnsi';
  }

  /// Outputs [entry] to console. Wrapped in try/catch to never throw.
  ///
  /// Emits the log entry exactly once via [outputCallback] (if set) or [debugPrint].
  void output(DebugLogEntry entry) {
    try {
      final formatted = format(entry);

      // Invoke test seam listener if registered
      testListener?.call(formatted, entry);

      // Output to console exactly once via outputCallback or debugPrint
      if (outputCallback != null) {
        outputCallback!(formatted);
      } else {
        debugPrint(formatted);
      }
    } catch (_) {
      // Swallowed safely per NFR-03
    }
  }
}
