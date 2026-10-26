/// Sanitized exception/error details captured during logging.
class DebugErrorInfo {
  const DebugErrorInfo({required this.type, required this.message});

  /// The runtime type name of the error object (guarded and capped).
  final String type;

  /// The error message (redacted and truncated).
  final String message;

  Map<String, Object?> toJson() => {'type': type, 'message': message};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebugErrorInfo &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          message == other.message;

  @override
  int get hashCode => Object.hash(type, message);

  @override
  String toString() => '$type: $message';
}
