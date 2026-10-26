import 'dart:convert';

import '../core/debug_bubble_config.dart';
import '../core/debug_log_entry.dart';
import '../core/debug_log_filter.dart';
import '../utils/build_mode.dart';
import '../version.dart';

/// Exporter for Schema v1 versioned JSON representations per DATA_MODELS.md §8.
class JsonExporter {
  const JsonExporter();

  /// Schema version constant.
  static const int schemaVersion = 1;

  /// Builds a schema v1 map from the given parameters.
  Map<String, Object?> buildDocument({
    required List<DebugLogEntry> entries,
    required DebugBubbleConfig config,
    required int totalEntries,
    required int droppedCount,
    required DebugLogFilter filter,
    String? buildMode,
    DateTime? exportedAt,
  }) {
    final mode = buildMode ?? (BuildMode.isProfile ? 'profile' : 'debug');

    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'exportedAt': (exportedAt ?? DateTime.now().toUtc()).toIso8601String(),
      'packageVersion': debugBubbleVersion,
      'buildMode': mode,
      'redaction': <String, Object?>{
        'enabled': config.redaction.enabled,
        'valuePatternCount': config.redaction.valuePatterns.length,
      },
      'limits': <String, Object?>{
        'maxEntries': config.maxEntries,
        'maxEntryChars': config.maxEntryChars,
        'maxMessageLength': config.maxMessageLength,
        'maxStackTraceLength': config.maxStackTraceLength,
        'maxPayloadLength': config.maxPayloadLength,
      },
      'totalEntries': totalEntries,
      'exportedEntries': entries.length,
      'droppedCount': droppedCount,
      'filter': <String, Object?>{
        'levels': filter.levels.map((l) => l.name).toList(),
        'query': filter.query,
        'tag': filter.tag,
      },
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  /// Serializes [buildDocument] as a pretty-printed JSON string (2-space indent).
  String export({
    required List<DebugLogEntry> entries,
    required DebugBubbleConfig config,
    required int totalEntries,
    required int droppedCount,
    required DebugLogFilter filter,
    String? buildMode,
    DateTime? exportedAt,
  }) {
    final doc = buildDocument(
      entries: entries,
      config: config,
      totalEntries: totalEntries,
      droppedCount: droppedCount,
      filter: filter,
      buildMode: buildMode,
      exportedAt: exportedAt,
    );
    return const JsonEncoder.withIndent('  ').convert(doc);
  }
}
