/// Configuration for redacting sensitive values during log ingestion.
class DebugRedactionConfig {
  const DebugRedactionConfig({
    this.enabled = true,
    this.sensitiveKeys = defaultSensitiveKeys,
    this.sensitiveKeyTokens = defaultSensitiveKeyTokens,
    this.valuePatterns = const <RegExp>[],
    this.replacement = '[REDACTED]',
  });

  /// Default substring keys used for sensitive map key matching.
  static const Set<String> defaultSensitiveKeys = {
    'password',
    'passwd',
    'passphrase',
    'secret',
    'token',
    'authorization',
    'cookie',
    'apikey',
    'privatekey',
    'accesskey',
    'credential',
  };

  /// Default whole-token keys used for sensitive map key matching.
  static const Set<String> defaultSensitiveKeyTokens = {
    'pin',
    'otp',
    'cvv',
    'cvc',
    'ssn',
    'card',
    'session',
    'auth',
  };

  /// Whether redaction is active. Cannot be disabled in release builds.
  final bool enabled;

  /// Keys matched as substrings of normalized lowercase keys.
  final Set<String> sensitiveKeys;

  /// Keys matched as exact tokens after tokenizing key identifiers.
  final Set<String> sensitiveKeyTokens;

  /// Regular expression patterns matched against string values and messages.
  final List<RegExp> valuePatterns;

  /// Replacement string for redacted content.
  final String replacement;

  DebugRedactionConfig copyWith({
    bool? enabled,
    Set<String>? sensitiveKeys,
    Set<String>? sensitiveKeyTokens,
    List<RegExp>? valuePatterns,
    String? replacement,
  }) {
    return DebugRedactionConfig(
      enabled: enabled ?? this.enabled,
      sensitiveKeys: sensitiveKeys ?? this.sensitiveKeys,
      sensitiveKeyTokens: sensitiveKeyTokens ?? this.sensitiveKeyTokens,
      valuePatterns: valuePatterns ?? this.valuePatterns,
      replacement: replacement ?? this.replacement,
    );
  }
}
