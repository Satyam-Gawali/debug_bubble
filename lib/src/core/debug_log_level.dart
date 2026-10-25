/// Severity level of a log entry.
///
/// Levels are ordered from least to most severe:
/// [debug] < [info] < [success] < [warning] < [error] < [critical].
enum DebugLogLevel {
  debug,
  info,
  success,
  warning,
  error,
  critical;

  /// True if this level represents an error ([error] or [critical]).
  bool get isError =>
      this == DebugLogLevel.error || this == DebugLogLevel.critical;

  /// Compares severity index according to the defined level ordering.
  bool operator >=(DebugLogLevel other) => index >= other.index;

  /// Compares severity index according to the defined level ordering.
  bool operator >(DebugLogLevel other) => index > other.index;

  /// Compares severity index according to the defined level ordering.
  bool operator <=(DebugLogLevel other) => index <= other.index;

  /// Compares severity index according to the defined level ordering.
  bool operator <(DebugLogLevel other) => index < other.index;
}
