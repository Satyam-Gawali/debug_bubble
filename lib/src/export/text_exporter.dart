import 'dart:convert';

import '../core/debug_log_entry.dart';

/// Formatter and exporter for plain-text log representations per DATA_MODELS.md §9.
class TextExporter {
  const TextExporter();

  /// Maximum character budget for multi-entry export text (D-26).
  static const int clipboardCapChars = 500000;

  /// Formats a single [entry] into a plain-text block per DATA_MODELS.md §9.
  ///
  /// Lines for absent fields are omitted; appends ` (truncated)` when truncated.
  static String formatEntry(DebugLogEntry entry) {
    final buffer = StringBuffer();

    // 1. Header line: [2026-10-25T09:59:58.123Z] ERROR Auth/Login (#1) (truncated)
    buffer.write('[');
    buffer.write(entry.timestamp.toIso8601String());
    buffer.write('] ');
    buffer.write(entry.level.name.toUpperCase());

    final hasTag = entry.tag != null && entry.tag!.isNotEmpty;
    final hasSubTag = entry.subTag != null && entry.subTag!.isNotEmpty;

    if (hasTag && hasSubTag) {
      buffer.write(' ${entry.tag}/${entry.subTag}');
    } else if (hasTag) {
      buffer.write(' ${entry.tag}');
    } else if (hasSubTag) {
      buffer.write(' ${entry.subTag}');
    }

    buffer.write(' (#${entry.id})');
    if (entry.truncated) {
      buffer.write(' (truncated)');
    }
    buffer.writeln();

    // 2. Message
    buffer.writeln(entry.message);

    // 3. Error
    if (entry.error != null) {
      final err = entry.error!;
      if (err.type.isNotEmpty && err.message.isNotEmpty) {
        buffer.writeln('Error: ${err.type}: ${err.message}');
      } else if (err.type.isNotEmpty) {
        buffer.writeln('Error: ${err.type}');
      } else if (err.message.isNotEmpty) {
        buffer.writeln('Error: ${err.message}');
      }
    }

    // 4. Metadata
    if (entry.metadata != null && entry.metadata!.isNotEmpty) {
      try {
        final prettyJson = const JsonEncoder.withIndent('  ')
            .convert(entry.metadata);
        buffer.writeln('Metadata: $prettyJson');
      } catch (_) {
        buffer.writeln('Metadata: ${entry.metadata}');
      }
    }

    // 5. JSON
    if (entry.json != null) {
      try {
        final prettyJson = const JsonEncoder.withIndent('  ')
            .convert(entry.json);
        buffer.writeln('JSON: $prettyJson');
      } catch (_) {
        buffer.writeln('JSON: ${entry.json}');
      }
    }

    // 6. Stack trace
    if (entry.stackTrace != null && entry.stackTrace!.isNotEmpty) {
      buffer.writeln('Stack trace:');
      buffer.writeln(entry.stackTrace);
    }

    return buffer.toString().trimRight();
  }

  /// Exports [entries] in oldest → newest order as plain text (DATA_MODELS.md §9).
  ///
  /// Enforces character budget [maxChars] (default 500,000, D-26). If the text would
  /// exceed the cap, oldest entries in the selection are omitted and the header
  /// reflects the total older entries dropped.
  String export({
    required List<DebugLogEntry> entries,
    required int droppedCount,
    int maxChars = clipboardCapChars,
  }) {
    if (entries.isEmpty) {
      return 'debug_bubble log export — 0 entries ($droppedCount older entries dropped)';
    }

    final formattedBlocks = entries.map(formatEntry).toList();
    var omittedFromSelection = 0;

    while (omittedFromSelection < formattedBlocks.length) {
      final includedCount = formattedBlocks.length - omittedFromSelection;
      final totalOlderDropped = droppedCount + omittedFromSelection;
      final header =
          'debug_bubble log export — $includedCount entries ($totalOlderDropped older entries dropped)';

      final body = formattedBlocks.sublist(omittedFromSelection).join('\n\n');
      final fullText = '$header\n\n$body';

      if (fullText.length <= maxChars) {
        return fullText;
      }

      omittedFromSelection++;
    }

    // If even a single entry cannot fit within maxChars, return header with 0 entries
    final totalOlderDropped = droppedCount + formattedBlocks.length;
    return 'debug_bubble log export — 0 entries ($totalOlderDropped older entries dropped)';
  }
}
