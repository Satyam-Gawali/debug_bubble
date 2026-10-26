import 'debug_error_info.dart';
import 'debug_log_level.dart';

/// An immutable, sanitized log entry recorded by the toolkit.
class DebugLogEntry {
  DebugLogEntry({
    required this.id,
    required DateTime timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.subTag,
    this.error,
    this.stackTrace,
    Map<String, Object?>? metadata,
    Object? json,
    this.isUncaught = false,
    this.truncated = false,
  }) : timestamp = timestamp.toUtc(),
       metadata = metadata != null ? Map.unmodifiable(metadata) : null,
       json = _wrapUnmodifiable(json);

  /// Monotonic sequence ID per controller, starting at 1.
  final int id;

  /// UTC timestamp taken at ingestion.
  final DateTime timestamp;

  /// Severity level of this entry.
  final DebugLogLevel level;

  /// Log message (redacted and truncated).
  final String message;

  /// Optional primary tag.
  final String? tag;

  /// Optional secondary sub-tag.
  final String? subTag;

  /// Optional sanitized error info.
  final DebugErrorInfo? error;

  /// Optional stack trace string (redacted and truncated).
  final String? stackTrace;

  /// Sanitized JSON-safe metadata map.
  final Map<String, Object?>? metadata;

  /// Sanitized JSON-safe payload.
  final Object? json;

  /// True if captured by uncaught-error hooks.
  final bool isUncaught;

  /// True if any budget or limit caused data to be cut or omitted.
  final bool truncated;

  static Object? _wrapUnmodifiable(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.unmodifiable(
        value.map((k, v) => MapEntry(k.toString(), _wrapUnmodifiable(v))),
      );
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_wrapUnmodifiable));
    }
    return value;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    'tag': tag,
    'subTag': subTag,
    'error': error?.toJson(),
    'stackTrace': stackTrace,
    'metadata': metadata,
    'json': json,
    'isUncaught': isUncaught,
    'truncated': truncated,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebugLogEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DebugLogEntry(#$id, ${level.name}, tag: ${tag ?? '-'}/${subTag ?? '-'}, message: $message)';
}
