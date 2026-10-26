import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Filter Matching Semantics (DATA_MODELS §4, D-22)', () {
    final now = DateTime.utc(2026, 10, 26, 12, 0, 0);

    final entry1 = DebugLogEntry(
      id: 1,
      timestamp: now,
      level: DebugLogLevel.info,
      message: 'App initialized successfully',
      tag: 'Lifecycle',
      subTag: 'Startup',
      error: null,
      stackTrace: 'trace_token_123',
      metadata: {'userId': 100, 'secretMeta': 'meta_query_target'},
      json: {'payload': 'json_query_target'},
    );

    final entry2 = DebugLogEntry(
      id: 2,
      timestamp: now.add(const Duration(seconds: 1)),
      level: DebugLogLevel.error,
      message: 'Network request failed',
      tag: 'Network',
      subTag: 'Http',
      error: const DebugErrorInfo(
        type: 'SocketTimeoutException',
        message: 'Connection timed out',
      ),
      stackTrace: '#0 Socket.connect()',
      metadata: {'endpoint': '/api/v1/users'},
    );

    final entry3 = DebugLogEntry(
      id: 3,
      timestamp: now.add(const Duration(seconds: 2)),
      level: DebugLogLevel.critical,
      message: 'Database corrupted during migration',
      tag: 'Database',
      subTag: 'Sqlite',
      error: const DebugErrorInfo(
        type: 'CorruptedFileError',
        message: 'Header mismatch',
      ),
    );

    test('Empty filter matches all entries', () {
      const filter = DebugLogFilter();
      expect(filter.isEmpty, isTrue);
      expect(filter.matches(entry1), isTrue);
      expect(filter.matches(entry2), isTrue);
      expect(filter.matches(entry3), isTrue);
    });

    test('Exact level matching (not a minimum threshold)', () {
      const infoOnly = DebugLogFilter(levels: {DebugLogLevel.info});
      expect(infoOnly.matches(entry1), isTrue);
      expect(infoOnly.matches(entry2), isFalse);
      expect(infoOnly.matches(entry3), isFalse);

      const errorAndCritical = DebugLogFilter(
        levels: {DebugLogLevel.error, DebugLogLevel.critical},
      );
      expect(errorAndCritical.matches(entry1), isFalse);
      expect(errorAndCritical.matches(entry2), isTrue);
      expect(errorAndCritical.matches(entry3), isTrue);

      const warningOnly = DebugLogFilter(levels: {DebugLogLevel.warning});
      expect(warningOnly.matches(entry1), isFalse);
      expect(warningOnly.matches(entry2), isFalse);
      expect(warningOnly.matches(entry3), isFalse);
    });

    test('Tag matching is exact and case-sensitive', () {
      const networkFilter = DebugLogFilter(tag: 'Network');
      expect(networkFilter.matches(entry1), isFalse);
      expect(networkFilter.matches(entry2), isTrue);
      expect(networkFilter.matches(entry3), isFalse);

      const lowerNetworkFilter = DebugLogFilter(tag: 'network');
      expect(lowerNetworkFilter.matches(entry2), isFalse);

      const nullTagFilter = DebugLogFilter(tag: null);
      expect(nullTagFilter.matches(entry1), isTrue);
      expect(nullTagFilter.matches(entry2), isTrue);
    });

    test('Query substring search matches message, tag, subTag, error type, error message (case-insensitive)', () {
      // In message
      expect(
        const DebugLogFilter(query: 'initialized').matches(entry1),
        isTrue,
      );
      expect(
        const DebugLogFilter(query: 'INITIALIZED').matches(entry1),
        isTrue,
      );

      // In tag
      expect(const DebugLogFilter(query: 'lifecycle').matches(entry1), isTrue);

      // In subTag
      expect(const DebugLogFilter(query: 'startup').matches(entry1), isTrue);
      expect(const DebugLogFilter(query: 'http').matches(entry2), isTrue);

      // In error.type
      expect(
        const DebugLogFilter(query: 'sockettimeout').matches(entry2),
        isTrue,
      );
      expect(const DebugLogFilter(query: 'corrupted').matches(entry3), isTrue);

      // In error.message
      expect(const DebugLogFilter(query: 'timed out').matches(entry2), isTrue);
      expect(
        const DebugLogFilter(query: 'header mismatch').matches(entry3),
        isTrue,
      );

      // Trimmed query
      expect(
        const DebugLogFilter(query: '  migration  ').matches(entry3),
        isTrue,
      );
      expect(const DebugLogFilter(query: '   ').matches(entry1), isTrue);
    });

    test(
      'Query search explicitly excludes stackTrace, metadata, and json (D-22)',
      () {
        // In stackTrace
        expect(
          const DebugLogFilter(query: 'trace_token_123').matches(entry1),
          isFalse,
        );
        expect(
          const DebugLogFilter(query: 'Socket.connect').matches(entry2),
          isFalse,
        );

        // In metadata
        expect(
          const DebugLogFilter(query: 'meta_query_target').matches(entry1),
          isFalse,
        );
        expect(
          const DebugLogFilter(query: '/api/v1/users').matches(entry2),
          isFalse,
        );

        // In json
        expect(
          const DebugLogFilter(query: 'json_query_target').matches(entry1),
          isFalse,
        );
      },
    );

    test('All present criteria combine with AND', () {
      final filter = const DebugLogFilter(
        levels: {DebugLogLevel.error},
        tag: 'Network',
        query: 'timed out',
      );
      expect(filter.matches(entry2), isTrue);

      // Mismatch on level
      final wrongLevel = filter.copyWith(levels: {DebugLogLevel.critical});
      expect(wrongLevel.matches(entry2), isFalse);

      // Mismatch on tag
      final wrongTag = filter.copyWith(tag: 'Database');
      expect(wrongTag.matches(entry2), isFalse);

      // Mismatch on query
      final wrongQuery = filter.copyWith(query: 'corrupted');
      expect(wrongQuery.matches(entry2), isFalse);
    });

    test(
      'Controller query() returns filtered snapshot in oldest to newest order',
      () {
        final controller = DebugBubbleController();
        controller.log(DebugLogLevel.info, 'Message 1', tag: 'A');
        controller.log(DebugLogLevel.error, 'Message 2', tag: 'B');
        controller.log(DebugLogLevel.error, 'Message 3', tag: 'A');
        controller.log(DebugLogLevel.critical, 'Message 4', tag: 'A');

        final results = controller.query(
          const DebugLogFilter(
            levels: {DebugLogLevel.error, DebugLogLevel.critical},
            tag: 'A',
          ),
        );

        expect(results.length, 2);
        expect(results[0].message, 'Message 3');
        expect(results[1].message, 'Message 4');
        expect(results[0].id < results[1].id, isTrue);

        controller.dispose();
        expect(controller.query(const DebugLogFilter()), isEmpty);
      },
    );
  });
}
