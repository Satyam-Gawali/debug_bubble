import 'debug_log_entry.dart';
import 'debug_log_level.dart';

/// Filter criteria for querying and exporting log entries.
class DebugLogFilter {
  const DebugLogFilter({
    this.levels = const <DebugLogLevel>{},
    this.query = '',
    this.tag,
  });

  /// Exact-level match; empty set matches all levels.
  final Set<DebugLogLevel> levels;

  /// Substring search query against message, tag, subTag, and error info.
  final String query;

  /// Exact tag filter; null means no tag filter.
  final String? tag;

  /// True when no filtering criteria are set.
  bool get isEmpty => levels.isEmpty && query.trim().isEmpty && tag == null;

  /// Tests whether [entry] satisfies all active filter criteria.
  bool matches(DebugLogEntry entry) {
    if (levels.isNotEmpty && !levels.contains(entry.level)) {
      return false;
    }
    if (tag != null && entry.tag != tag) {
      return false;
    }
    final trimmedQuery = query.trim().toLowerCase();
    if (trimmedQuery.isNotEmpty) {
      final inMessage = entry.message.toLowerCase().contains(trimmedQuery);
      final inTag = entry.tag?.toLowerCase().contains(trimmedQuery) ?? false;
      final inSubTag =
          entry.subTag?.toLowerCase().contains(trimmedQuery) ?? false;
      final inErrorType =
          entry.error?.type.toLowerCase().contains(trimmedQuery) ?? false;
      final inErrorMessage =
          entry.error?.message.toLowerCase().contains(trimmedQuery) ?? false;
      if (!inMessage &&
          !inTag &&
          !inSubTag &&
          !inErrorType &&
          !inErrorMessage) {
        return false;
      }
    }
    return true;
  }

  DebugLogFilter copyWith({
    Set<DebugLogLevel>? levels,
    String? query,
    String? tag,
  }) {
    return DebugLogFilter(
      levels: levels ?? this.levels,
      query: query ?? this.query,
      tag: tag ?? this.tag,
    );
  }
}
