import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebugLogFilter (DATA_MODELS §4)', () {
    final now = DateTime.now().toUtc();

    test('Default filter is empty and matches all entries', () {
      const filter = DebugLogFilter();
      expect(filter.isEmpty, isTrue);

      final entry = DebugLogEntry(
        id: 1,
        timestamp: now,
        level: DebugLogLevel.debug,
        message: 'A debug message',
      );
      expect(filter.matches(entry), isTrue);
    });

    test('Exact level matching (not a minimum, empty = all)', () {
      const filter = DebugLogFilter(
        levels: {DebugLogLevel.warning, DebugLogLevel.critical},
      );
      expect(filter.isEmpty, isFalse);

      final debugEntry = DebugLogEntry(
        id: 1,
        timestamp: now,
        level: DebugLogLevel.debug,
        message: 'debug',
      );
      final warningEntry = DebugLogEntry(
        id: 2,
        timestamp: now,
        level: DebugLogLevel.warning,
        message: 'warning',
      );
      final errorEntry = DebugLogEntry(
        id: 3,
        timestamp: now,
        level: DebugLogLevel.error,
        message: 'error',
      );
      final criticalEntry = DebugLogEntry(
        id: 4,
        timestamp: now,
        level: DebugLogLevel.critical,
        message: 'critical',
      );

      expect(filter.matches(debugEntry), isFalse);
      expect(filter.matches(warningEntry), isTrue);
      expect(
        filter.matches(errorEntry),
        isFalse,
      ); // error is not in {warning, critical}
      expect(filter.matches(criticalEntry), isTrue);
    });

    test('Query search matches message, tag, subTag, error type, error message (case-insensitive)', () {
      final baseEntry = DebugLogEntry(
        id: 1,
        timestamp: now,
        level: DebugLogLevel.info,
        message: 'User authentication succeeded',
        tag: 'SecurityModule',
        subTag: 'OAuth2',
        error: const DebugErrorInfo(
          type: 'AuthTokenError',
          message: 'ExpiredToken',
        ),
        stackTrace: 'secret_stack_trace_token',
        metadata: {'secretKey': 'secret_metadata_value'},
        json: {'secretJson': 'secret_json_value'},
      );

      // Matches message (case-insensitive substring)
      expect(
        const DebugLogFilter(query: 'AUTHENTICATION').matches(baseEntry),
        isTrue,
      );
      // Matches tag
      expect(
        const DebugLogFilter(query: 'security').matches(baseEntry),
        isTrue,
      );
      // Matches subTag
      expect(const DebugLogFilter(query: 'oauth').matches(baseEntry), isTrue);
      // Matches error type
      expect(
        const DebugLogFilter(query: 'authtoken').matches(baseEntry),
        isTrue,
      );
      // Matches error message
      expect(const DebugLogFilter(query: 'expired').matches(baseEntry), isTrue);

      // Whitespace-only query is treated as empty query
      expect(const DebugLogFilter(query: '   ').matches(baseEntry), isTrue);

      // Does NOT match against stackTrace, metadata, or json (D-22)
      expect(
        const DebugLogFilter(query: 'secret_stack_trace_token')
            .matches(baseEntry),
        isFalse,
      );
      expect(
        const DebugLogFilter(query: 'secret_metadata_value').matches(baseEntry),
        isFalse,
      );
      expect(
        const DebugLogFilter(query: 'secret_json_value').matches(baseEntry),
        isFalse,
      );
    });

    test('Tag filter matches tag exactly and case-sensitively', () {
      const filter = DebugLogFilter(tag: 'Network');

      final matchEntry = DebugLogEntry(
        id: 1,
        timestamp: now,
        level: DebugLogLevel.info,
        message: 'Req',
        tag: 'Network',
      );
      final caseMismatchEntry = DebugLogEntry(
        id: 2,
        timestamp: now,
        level: DebugLogLevel.info,
        message: 'Req',
        tag: 'network',
      );
      final nullTagEntry = DebugLogEntry(
        id: 3,
        timestamp: now,
        level: DebugLogLevel.info,
        message: 'Req',
      );

      expect(filter.matches(matchEntry), isTrue);
      expect(filter.matches(caseMismatchEntry), isFalse);
      expect(filter.matches(nullTagEntry), isFalse);
    });

    test('All present criteria combine with AND', () {
      const filter = DebugLogFilter(
        levels: {DebugLogLevel.error},
        query: 'failed',
        tag: 'Billing',
      );

      final matchesAll = DebugLogEntry(
        id: 1,
        timestamp: now,
        level: DebugLogLevel.error,
        message: 'Payment failed',
        tag: 'Billing',
      );
      final wrongLevel = DebugLogEntry(
        id: 2,
        timestamp: now,
        level: DebugLogLevel.warning,
        message: 'Payment failed',
        tag: 'Billing',
      );
      final wrongTag = DebugLogEntry(
        id: 3,
        timestamp: now,
        level: DebugLogLevel.error,
        message: 'Payment failed',
        tag: 'Auth',
      );
      final wrongQuery = DebugLogEntry(
        id: 4,
        timestamp: now,
        level: DebugLogLevel.error,
        message: 'Payment ok',
        tag: 'Billing',
      );

      expect(filter.matches(matchesAll), isTrue);
      expect(filter.matches(wrongLevel), isFalse);
      expect(filter.matches(wrongTag), isFalse);
      expect(filter.matches(wrongQuery), isFalse);
    });

    test('Value equality, hashCode, and copyWith', () {
      const f1 = DebugLogFilter(
        levels: {DebugLogLevel.error},
        query: 'q',
        tag: 't',
      );
      const f2 = DebugLogFilter(
        levels: {DebugLogLevel.error},
        query: 'q',
        tag: 't',
      );
      const f3 = DebugLogFilter(
        levels: {DebugLogLevel.info},
        query: 'q',
        tag: 't',
      );

      expect(f1, equals(f2));
      expect(f1.hashCode, equals(f2.hashCode));
      expect(f1, isNot(equals(f3)));

      final f4 = f1.copyWith(clearTag: true);
      expect(f4.tag, isNull);
      expect(f4.query, 'q');
      expect(f4.levels, {DebugLogLevel.error});
    });
  });
}
