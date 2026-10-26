import '../core/debug_log_entry.dart';
import '../core/debug_log_filter.dart';

/// Pure matcher utility implementing exact filtering semantics per DATA_MODELS.md §4.
class FilterMatcher {
  const FilterMatcher._();

  /// Tests whether [entry] satisfies all active criteria in [filter].
  ///
  /// Criteria matching rules:
  /// - [levels]: Exact match; empty set matches all levels (not a minimum threshold).
  /// - [tag]: Exact, case-sensitive match; `null` matches all tags.
  /// - [query]: Trimmed; empty after trim matches everything. Case-insensitive
  ///   substring matching against `message`, `tag`, `subTag`, `error.type`,
  ///   and `error.message`. Excludes `stackTrace`, `metadata`, and `json` (D-22).
  /// - All present criteria combine with AND.
  static bool matches(DebugLogFilter filter, DebugLogEntry entry) {
    if (filter.levels.isNotEmpty && !filter.levels.contains(entry.level)) {
      return false;
    }
    if (filter.tag != null && entry.tag != filter.tag) {
      return false;
    }
    final trimmedQuery = filter.query.trim().toLowerCase();
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
}
