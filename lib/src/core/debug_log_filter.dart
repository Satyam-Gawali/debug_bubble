import 'package:flutter/foundation.dart';

import '../filters/filter_matcher.dart';
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
  bool matches(DebugLogEntry entry) => FilterMatcher.matches(this, entry);

  /// Creates a copy of this filter with the given fields replaced.
  ///
  /// Set [clearTag] to `true` to explicitly reset [tag] to `null`.
  DebugLogFilter copyWith({
    Set<DebugLogLevel>? levels,
    String? query,
    String? tag,
    bool clearTag = false,
  }) {
    return DebugLogFilter(
      levels: levels ?? this.levels,
      query: query ?? this.query,
      tag: clearTag ? null : (tag ?? this.tag),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebugLogFilter &&
          runtimeType == other.runtimeType &&
          setEquals(levels, other.levels) &&
          query == other.query &&
          tag == other.tag;

  @override
  int get hashCode => Object.hash(Object.hashAll(levels), query, tag);

  @override
  String toString() =>
      'DebugLogFilter(levels: $levels, query: "$query", tag: $tag)';
}
