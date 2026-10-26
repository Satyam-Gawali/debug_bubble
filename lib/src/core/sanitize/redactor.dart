import '../../utils/build_mode.dart';
import '../debug_redaction_config.dart';

/// Redaction engine for sanitizing sensitive keys and values during ingestion.
///
/// Implements key normalization, token splitting, value regex scanning, scan
/// window bounding, fail-closed handling, and build-mode forcing per
/// SECURITY_PERFORMANCE.md §3 and PROJECT_SPEC.md (D-05, D-28).
class DebugRedactor {
  /// Creates a redactor with the provided [config].
  DebugRedactor({this.config = const DebugRedactionConfig()})
    : _normalizedSensitiveKeys = config.sensitiveKeys
          .map(normalizeKey)
          .where((k) => k.isNotEmpty)
          .toSet(),
      _normalizedSensitiveKeyTokens = config.sensitiveKeyTokens
          .map((t) => t.toLowerCase())
          .where((t) => t.isNotEmpty)
          .toSet();

  /// The redaction configuration in effect.
  final DebugRedactionConfig config;

  final Set<String> _normalizedSensitiveKeys;
  final Set<String> _normalizedSensitiveKeyTokens;

  /// Replacement string for redacted content.
  String get replacement => config.replacement;

  /// Marker string used when redaction encounters an unexpected error.
  static const String redactionError = '[REDACTION_ERROR]';

  static final RegExp _nonAlphaNumericRegex = RegExp(r'[^a-z0-9]');
  static final RegExp _tokenSplitRegex = RegExp(
    r'[A-Z]+(?=[A-Z][a-z0-9])|[A-Z]?[a-z0-9]+|[A-Z]+',
  );

  /// Whether redaction is actively performing matching and masking.
  ///
  /// Redaction cannot be disabled when running in release mode (or simulated
  /// release mode via [BuildMode.isRelease]), serving as defense in depth (D-04, D-28).
  bool get isRedactionActive => BuildMode.isRelease || config.enabled;

  /// Normalizes a key by converting to lowercase and stripping non-alphanumeric characters.
  static String normalizeKey(String key) {
    return key.toLowerCase().replaceAll(_nonAlphaNumericRegex, '');
  }

  /// Splits a key into constituent tokens at non-alphanumerics, camelCase,
  /// and acronym boundaries, returning lowercased tokens.
  static List<String> tokenizeKey(String key) {
    if (key.isEmpty) return const <String>[];
    return _tokenSplitRegex
        .allMatches(key)
        .map((m) => m.group(0)!.toLowerCase())
        .toList();
  }

  /// Evaluates whether [key] is deemed sensitive per key matching rules.
  ///
  /// Evaluates:
  /// 1. Substring match against [DebugRedactionConfig.sensitiveKeys] after normalization.
  /// 2. Exact token match against [DebugRedactionConfig.sensitiveKeyTokens] after tokenizing.
  ///
  /// Returns `false` if [isRedactionActive] is `false`.
  bool isSensitiveKey(String key) {
    if (!isRedactionActive) return false;
    if (key.isEmpty) return false;

    // 1. Normalized key substring match
    final normalized = normalizeKey(key);
    if (normalized.isNotEmpty) {
      for (final sensitiveKey in _normalizedSensitiveKeys) {
        if (sensitiveKey.isNotEmpty && normalized.contains(sensitiveKey)) {
          return true;
        }
      }
    }

    // 2. Tokenized exact match
    final tokens = tokenizeKey(key);
    for (final token in tokens) {
      if (_normalizedSensitiveKeyTokens.contains(token)) {
        return true;
      }
    }

    return false;
  }

  /// Applies value patterns to [text] within [maxScanChars].
  ///
  /// To keep regex cost bounded, only the first [maxScanChars] characters are scanned
  /// and any remainder is discarded. If redaction throws, returns [redactionError] (fail-closed).
  String redact(String text, {int? maxScanChars}) {
    if (!isRedactionActive) return text;
    if (config.valuePatterns.isEmpty || text.isEmpty) return text;

    try {
      var scanned = text;
      if (maxScanChars != null && text.length > maxScanChars) {
        scanned = text.substring(0, maxScanChars);
      }

      for (final pattern in config.valuePatterns) {
        scanned = scanned.replaceAll(pattern, replacement);
      }
      return scanned;
    } catch (_) {
      return redactionError;
    }
  }

  /// Redacts nullable text, returning null if [text] is null.
  String? redactNullable(String? text, {int? maxScanChars}) {
    if (text == null) return null;
    return redact(text, maxScanChars: maxScanChars);
  }

  /// Redacts a log message within the message scan window (2 * [maxMessageLength]).
  String redactMessage(String message, {int maxMessageLength = 8000}) {
    return redact(message, maxScanChars: 2 * maxMessageLength);
  }

  /// Redacts an error message within the message scan window (2 * [maxMessageLength]).
  String redactErrorMessage(
    String errorMessage, {
    int maxMessageLength = 8000,
  }) {
    return redact(errorMessage, maxScanChars: 2 * maxMessageLength);
  }

  /// Redacts a stack trace within the stack trace scan window (2 * [maxStackTraceLength]).
  String redactStackTrace(
    String stackTrace, {
    int maxStackTraceLength = 16000,
  }) {
    return redact(stackTrace, maxScanChars: 2 * maxStackTraceLength);
  }

  /// Redacts a tag or subTag within the tag scan window (2 * 100 = 200).
  String redactTag(String tag) {
    return redact(tag, maxScanChars: 200);
  }

  /// Redacts a payload string value within the payload string scan window (4,000 chars).
  String redactPayloadString(String value) {
    return redact(value, maxScanChars: 4000);
  }

  /// Recursively redacts maps, lists, and string values in [data].
  ///
  /// Sensitive map keys have their values replaced by [replacement] without
  /// traversing their subtree (SECURITY_PERFORMANCE.md §3).
  Object? redactPayload(Object? data) {
    if (!isRedactionActive) return data;
    if (data == null) return null;

    if (data is Map) {
      final result = <String, Object?>{};
      for (final entry in data.entries) {
        final keyStr = entry.key?.toString() ?? 'null';
        if (isSensitiveKey(keyStr)) {
          result[keyStr] = replacement;
        } else {
          result[keyStr] = redactPayload(entry.value);
        }
      }
      return result;
    }

    if (data is List) {
      return data.map((item) => redactPayload(item)).toList();
    }

    if (data is Set) {
      return data.map((item) => redactPayload(item)).toSet();
    }

    if (data is String) {
      return redactPayloadString(data);
    }

    return data;
  }
}

/// Alias for [DebugRedactor] per IMPLEMENTATION_ROADMAP.md naming.
typedef Redactor = DebugRedactor;
