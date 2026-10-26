import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/core/sanitize/redactor.dart';
import 'package:debug_bubble/src/utils/build_mode.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: deprecated_implement
class _ThrowingRegExp implements RegExp {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('Simulated regex error');
  }
}

void main() {
  tearDown(() {
    BuildMode.reset();
  });

  group(
    'Key Normalization & Substring Matching (D-28, SECURITY_PERFORMANCE §3)',
    () {
      final redactor = DebugRedactor();

      test('Matches sensitive keys across case variations and formatting', () {
        final sensitiveKeys = [
          'password',
          'Password',
          'PASSWORD',
          'userPassword',
          'API_KEY',
          'apikey',
          'apiKey',
          'my_api_key',
          'accessToken',
          'access_token',
          'ACCESSTOKEN',
          'x-auth-token',
          'X-Auth-Token',
          'Set-Cookie',
          'cookie',
          'myCookie',
          'authorization',
          'AUTHORIZATION',
          'privatekey',
          'private_key',
          'credential',
          'user_credentials',
        ];

        for (final key in sensitiveKeys) {
          expect(
            redactor.isSensitiveKey(key),
            isTrue,
            reason: 'Expected "$key" to be recognized as sensitive key',
          );
        }
      });

      test('Does not match insensitive keys', () {
        final nonSensitiveKeys = [
          'username',
          'email',
          'status',
          'count',
          'items',
          'timestamp',
          'data',
        ];

        for (final key in nonSensitiveKeys) {
          expect(
            redactor.isSensitiveKey(key),
            isFalse,
            reason: 'Expected "$key" to not be recognized as sensitive',
          );
        }
      });
    },
  );

  group(
    'Token-Only Keys & Word Boundaries (D-28, SECURITY_PERFORMANCE §3)',
    () {
      final redactor = DebugRedactor();

      test('Matches whole tokens at boundaries', () {
        final sensitiveTokenKeys = [
          'pin',
          'user_pin',
          'userPin',
          'PIN',
          'pin_code',
          'card',
          'creditCard',
          'userCardNumber',
          'otp',
          'user_otp',
          'cvv',
          'cvc',
          'ssn',
          'session',
          'sessionId',
          'auth',
        ];

        for (final key in sensitiveTokenKeys) {
          expect(
            redactor.isSensitiveKey(key),
            isTrue,
            reason: 'Expected "$key" with token to be sensitive',
          );
        }
      });

      test(
        'Reduces false positives for short words (shipping, spin, wildcard)',
        () {
          final safeKeys = [
            'shipping',
            'shipping_address',
            'spin',
            'opinion',
            'wildcard',
            'discard',
            'hotpot',
            'concession',
            'authentic',
            'author',
          ];

          for (final key in safeKeys) {
            expect(
              redactor.isSensitiveKey(key),
              isFalse,
              reason: 'Expected "$key" not to match token-only sensitive keys',
            );
          }
        },
      );
    },
  );

  group('Documented False Positives & Negatives (SECURITY_PERFORMANCE §3)', () {
    final redactor = DebugRedactor();

    test('Asserts documented false positives', () {
      // "secretary" contains substring "secret"
      expect(redactor.isSensitiveKey('secretary'), isTrue);

      // "tokenizer" contains substring "token"
      expect(redactor.isSensitiveKey('tokenizer'), isTrue);

      // "cardType" matches token "card"
      expect(redactor.isSensitiveKey('cardType'), isTrue);
    });

    test('Asserts documented true positive via token and false negative', () {
      // "ssn_last4" is caught via token "ssn"
      expect(redactor.isSensitiveKey('ssn_last4'), isTrue);

      // "data" is a documented false negative when containing secrets without value pattern
      expect(redactor.isSensitiveKey('data'), isFalse);
    });
  });

  group('Value Pattern Redaction (SECURITY_PERFORMANCE §3)', () {
    test('Replaces pattern matches with replacement in string fields', () {
      final config = DebugRedactionConfig(
        valuePatterns: [
          RegExp(r'Bearer\s+[A-Za-z0-9\-_.]+'),
          RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b'),
        ],
      );
      final redactor = DebugRedactor(config: config);

      final message =
          'Request sent with Bearer eyJhbGciOi.secret and card 1234-5678-9012-3456';
      final redacted = redactor.redactMessage(message);

      expect(
        redacted,
        equals('Request sent with [REDACTED] and card [REDACTED]'),
      );
    });

    test(
      'Map keys are NOT scanned by value patterns (documented limitation)',
      () {
        final config = DebugRedactionConfig(
          valuePatterns: [RegExp(r'CUSTOM_PATTERN_XYZ')],
        );
        final redactor = DebugRedactor(config: config);

        // Even if key matches valuePattern, keys themselves are only filtered by key rules
        expect(redactor.isSensitiveKey('CUSTOM_PATTERN_XYZ'), isFalse);
      },
    );
  });

  group('Scan Window & Truncation (SECURITY_PERFORMANCE §3)', () {
    test(
      'Discards characters beyond maxScanChars before pattern replacement',
      () {
        final config = DebugRedactionConfig(valuePatterns: [RegExp(r'SECRET')]);
        final redactor = DebugRedactor(config: config);

        // 10 chars + SECRET + 20 chars
        final text = '0123456789SECRET01234567890123456789';
        // Scan window = 16: first 16 chars = '0123456789SECRET', rest discarded
        final redacted = redactor.redact(text, maxScanChars: 16);
        expect(redacted, equals('0123456789[REDACTED]'));
      },
    );

    test(
      'Secret straddling scan window edge is truncated with discarded part',
      () {
        final config = DebugRedactionConfig(valuePatterns: [RegExp(r'SECRET')]);
        final redactor = DebugRedactor(config: config);

        // Text where 'SECRET' straddles index 10 (window cut at 12 cuts 'SEC')
        final text = '0123456789SECRETEXTRA';
        final redacted = redactor.redact(text, maxScanChars: 12);
        expect(redacted, equals('0123456789SE'));
        expect(redacted.contains('SECRET'), isFalse);
      },
    );
  });

  group('Fail-Closed Error Handling (SECURITY_PERFORMANCE §3)', () {
    test('Returns [REDACTION_ERROR] when regex pattern throws', () {
      final config = DebugRedactionConfig(valuePatterns: [_ThrowingRegExp()]);
      final redactor = DebugRedactor(config: config);

      final result = redactor.redact('some sensitive string');
      expect(result, equals(DebugRedactor.redactionError));
      expect(result, equals('[REDACTION_ERROR]'));
    });
  });

  group('Build-Mode Policy & Release Forcing (D-04, D-28, SECURITY §2)', () {
    test('Honors enabled: false in debug mode', () {
      BuildMode.releaseOverride = false;
      final config = const DebugRedactionConfig(enabled: false);
      final redactor = DebugRedactor(config: config);

      expect(redactor.isRedactionActive, isFalse);
      expect(redactor.isSensitiveKey('password'), isFalse);
      expect(redactor.redact('password'), equals('password'));
    });

    test('Forces redaction ON in release mode even if enabled is false', () {
      BuildMode.releaseOverride = true;
      final config = const DebugRedactionConfig(enabled: false);
      final redactor = DebugRedactor(config: config);

      expect(redactor.isRedactionActive, isTrue);
      expect(redactor.isSensitiveKey('password'), isTrue);
    });
  });

  group(
    'Sentinel Secret Non-Retention & Nested Structures (D-28, SECURITY §3)',
    () {
      const sentinelSecret = 'SENTINEL_SECRET_TOKEN_XYZ_999';

      test(
        'Sentinel secret is redacted in nested maps and maps inside lists',
        () {
          final redactor = DebugRedactor();

          final payload = {
            'user': {'name': 'Alice', 'password': sentinelSecret},
            'records': [
              {'type': 'oauth', 'accessToken': sentinelSecret},
              {'type': 'security', 'user_pin': sentinelSecret},
            ],
          };

          final sanitized = redactor.redactPayload(payload);
          final sanitizedString = sanitized.toString();

          expect(sanitizedString.contains(sentinelSecret), isFalse);
          expect(
            sanitized,
            equals({
              'user': {'name': 'Alice', 'password': '[REDACTED]'},
              'records': [
                {'type': 'oauth', 'accessToken': '[REDACTED]'},
                {'type': 'security', 'user_pin': '[REDACTED]'},
              ],
            }),
          );
        },
      );

      test('Custom replacement string is applied cleanly', () {
        const customReplacement = '<MASKED>';
        final config = const DebugRedactionConfig(
          replacement: customReplacement,
        );
        final redactor = DebugRedactor(config: config);

        final payload = {'password': sentinelSecret};
        final sanitized =
            redactor.redactPayload(payload) as Map<String, Object?>;

        expect(sanitized['password'], equals(customReplacement));
      });
    },
  );
}
