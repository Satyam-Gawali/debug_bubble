import 'dart:async';

import 'package:flutter/widgets.dart';

import 'debug_bubble_theme.dart';
import 'debug_log_level.dart';
import 'debug_redaction_config.dart';

/// Configuration options for the debug bubble toolkit.
class DebugBubbleConfig {
  const DebugBubbleConfig({
    this.enabled = true,
    this.minLevel = DebugLogLevel.debug,
    this.maxEntries = 1000,
    this.maxEntryChars = 40000,
    this.maxMessageLength = 8000,
    this.maxStackTraceLength = 16000,
    this.maxPayloadLength = 32000,
    this.consoleOutput = true,
    this.captureUncaughtErrors = false,
    this.redaction = const DebugRedactionConfig(),
    this.theme = const DebugBubbleTheme(),
    this.initialBubbleAlignment = Alignment.centerRight,
    this.onExport,
  });

  /// Master switch; can only turn the package off. Effective activity also requires non-release build mode.
  final bool enabled;

  /// Minimum severity level accepted by the pipeline.
  final DebugLogLevel minLevel;

  /// Maximum number of entries stored in memory before evicting oldest.
  final int maxEntries;

  /// Combined per-entry character budget across all retained fields.
  final int maxEntryChars;

  /// Maximum length for message and error message fields.
  final int maxMessageLength;

  /// Maximum length for stack trace field.
  final int maxStackTraceLength;

  /// Shared budget for metadata and JSON payloads.
  final int maxPayloadLength;

  /// Whether to print sanitized log entries to the system console.
  final bool consoleOutput;

  /// Whether to capture uncaught Flutter and platform dispatcher errors (opt-in).
  final bool captureUncaughtErrors;

  /// Redaction rules for sensitive keys and value patterns.
  final DebugRedactionConfig redaction;

  /// UI theming configuration.
  final DebugBubbleTheme theme;

  /// Initial alignment of the floating bubble on screen.
  final Alignment initialBubbleAlignment;

  /// Optional host callback invoked when the user triggers an export.
  final FutureOr<void> Function(String json)? onExport;

  DebugBubbleConfig copyWith({
    bool? enabled,
    DebugLogLevel? minLevel,
    int? maxEntries,
    int? maxEntryChars,
    int? maxMessageLength,
    int? maxStackTraceLength,
    int? maxPayloadLength,
    bool? consoleOutput,
    bool? captureUncaughtErrors,
    DebugRedactionConfig? redaction,
    DebugBubbleTheme? theme,
    Alignment? initialBubbleAlignment,
    FutureOr<void> Function(String json)? onExport,
  }) {
    return DebugBubbleConfig(
      enabled: enabled ?? this.enabled,
      minLevel: minLevel ?? this.minLevel,
      maxEntries: maxEntries ?? this.maxEntries,
      maxEntryChars: maxEntryChars ?? this.maxEntryChars,
      maxMessageLength: maxMessageLength ?? this.maxMessageLength,
      maxStackTraceLength: maxStackTraceLength ?? this.maxStackTraceLength,
      maxPayloadLength: maxPayloadLength ?? this.maxPayloadLength,
      consoleOutput: consoleOutput ?? this.consoleOutput,
      captureUncaughtErrors:
          captureUncaughtErrors ?? this.captureUncaughtErrors,
      redaction: redaction ?? this.redaction,
      theme: theme ?? this.theme,
      initialBubbleAlignment:
          initialBubbleAlignment ?? this.initialBubbleAlignment,
      onExport: onExport ?? this.onExport,
    );
  }
}
