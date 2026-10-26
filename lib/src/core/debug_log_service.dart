import 'package:flutter/foundation.dart';

import '../collectors/console_sink.dart';
import '../utils/build_mode.dart';
import 'debug_bubble_config.dart';
import 'debug_log_entry.dart';
import 'debug_log_level.dart';
import 'debug_log_store.dart';
import 'sanitize/entry_sanitizer.dart';
import 'sanitize/redactor.dart';

/// Central ingestion pipeline for debug logs per ARCHITECTURE.md §2.
///
/// Coordinates gates, sanitization, bounded storage, and console output.
/// Guarantees that logging never throws into host application code (NFR-03).
class DebugLogService {
  /// Creates a service with [config] and [store].
  DebugLogService({
    required this.config,
    required this.store,
    ConsoleSink? consoleSink,
    EntrySanitizer? sanitizer,
    this.isActiveGetter,
    this.onEntryIngested,
  }) : consoleSink = consoleSink ?? const ConsoleSink(),
       sanitizer =
           sanitizer ??
           EntrySanitizer(redactor: DebugRedactor(config: config.redaction));

  /// Configuration governing limits, gating, and sinks.
  final DebugBubbleConfig config;

  /// In-memory bounded ring-buffer store.
  final DebugLogStore store;

  /// Console sink emitting plain-text logs.
  final ConsoleSink consoleSink;

  /// Sanitizer applying limits, budgets, and redactions.
  final EntrySanitizer sanitizer;

  /// Optional predicate indicating whether the owning controller is active.
  final bool Function()? isActiveGetter;

  /// Optional callback invoked whenever an entry is stored.
  final void Function(DebugLogEntry entry)? onEntryIngested;

  int _nextId = 1;

  /// Current sequence ID that will be assigned to the next ingested entry.
  @visibleForTesting
  int get nextId => _nextId;

  /// Ingests a log event through the pipeline.
  ///
  /// Steps:
  /// 1. Gating: checks controller active status, build mode, and minLevel.
  /// 2. Sanitization: redaction, limits, budgeting, truncation.
  /// 3. Entry creation: creates an immutable [DebugLogEntry].
  /// 4. Fan out: stores into [store] and outputs to [consoleSink].
  ///
  /// Never throws into host application code.
  DebugLogEntry? log(
    DebugLogLevel level,
    String message, {
    String? tag,
    String? subTag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    Object? json,
    bool isUncaught = false,
    DateTime? timestamp,
  }) {
    try {
      // 1. Active and build-mode gates
      if (isActiveGetter != null && !isActiveGetter!()) {
        return null;
      }
      if (!config.enabled || BuildMode.isRelease) {
        return null;
      }

      // MinLevel gate (D-11)
      if (level < config.minLevel) {
        return null;
      }

      // 2. Sanitize and budget
      final sanitized = sanitizer.sanitize(
        rawMessage: message,
        rawTag: tag,
        rawSubTag: subTag,
        rawError: error,
        rawStackTrace: stackTrace,
        rawMetadata: metadata,
        rawJson: json,
        maxEntryChars: config.maxEntryChars,
        maxMessageLength: config.maxMessageLength,
        maxStackTraceLength: config.maxStackTraceLength,
        maxPayloadLength: config.maxPayloadLength,
      );

      // 3. Create immutable DebugLogEntry (starts at sequence ID 1, UTC timestamp)
      final entry = DebugLogEntry(
        id: _nextId++,
        timestamp: timestamp ?? DateTime.now().toUtc(),
        level: level,
        message: sanitized.message,
        tag: sanitized.tag,
        subTag: sanitized.subTag,
        error: sanitized.error,
        stackTrace: sanitized.stackTrace,
        metadata: sanitized.metadata,
        json: sanitized.json,
        isUncaught: isUncaught,
        truncated: sanitized.truncated,
      );

      // 4. Fan out: store and console
      store.add(entry);

      if (config.consoleOutput) {
        consoleSink.output(entry);
      }

      onEntryIngested?.call(entry);

      return entry;
    } catch (_) {
      // Swallowed per NFR-03 (never crash host app)
      return null;
    }
  }
}
