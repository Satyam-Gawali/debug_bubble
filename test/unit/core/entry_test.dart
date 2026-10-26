import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebugLogEntry (DATA_MODELS §2, §8)', () {
    test('Constructs with all fields and converts timestamp to UTC', () {
      final localTime = DateTime(2026, 10, 26, 14, 30, 0); // local time
      final entry = DebugLogEntry(
        id: 42,
        timestamp: localTime,
        level: DebugLogLevel.warning,
        message: 'Disk space low',
        tag: 'Storage',
        subTag: 'Disk',
        error: const DebugErrorInfo(type: 'IOError', message: 'No space'),
        stackTrace: '#0 main()',
        metadata: {'freeMb': 12},
        json: {'path': '/data'},
        isUncaught: true,
        truncated: true,
      );

      expect(entry.id, 42);
      expect(entry.timestamp.isUtc, isTrue);
      expect(entry.timestamp, equals(localTime.toUtc()));
      expect(entry.level, DebugLogLevel.warning);
      expect(entry.message, 'Disk space low');
      expect(entry.tag, 'Storage');
      expect(entry.subTag, 'Disk');
      expect(entry.error?.type, 'IOError');
      expect(entry.stackTrace, '#0 main()');
      expect(entry.metadata?['freeMb'], 12);
      expect((entry.json as Map)['path'], '/data');
      expect(entry.isUncaught, isTrue);
      expect(entry.truncated, isTrue);
    });

    test('toJson matches export schema v1 entry structure', () {
      final utcTime = DateTime.utc(2026, 10, 26, 9, 0, 0, 123);
      final entry = DebugLogEntry(
        id: 1,
        timestamp: utcTime,
        level: DebugLogLevel.error,
        message: 'Login failed',
        tag: 'Auth',
        subTag: 'Login',
        error: const DebugErrorInfo(
          type: 'FormatException',
          message: 'Unexpected token',
        ),
        stackTrace: '#0 run()',
        metadata: {'userId': 100},
        json: {'status': 'fail'},
        isUncaught: false,
        truncated: false,
      );

      final json = entry.toJson();
      expect(json, {
        'id': 1,
        'timestamp': '2026-10-26T09:00:00.123Z',
        'level': 'error',
        'message': 'Login failed',
        'tag': 'Auth',
        'subTag': 'Login',
        'error': {'type': 'FormatException', 'message': 'Unexpected token'},
        'stackTrace': '#0 run()',
        'metadata': {'userId': 100},
        'json': {'status': 'fail'},
        'isUncaught': false,
        'truncated': false,
      });
    });

    test('Equality and hashCode are strictly by id (DATA_MODELS §2)', () {
      final now = DateTime.now().toUtc();
      final e1 = DebugLogEntry(
        id: 10,
        timestamp: now,
        level: DebugLogLevel.info,
        message: 'First',
      );
      final e2 = DebugLogEntry(
        id: 10,
        timestamp: now.add(const Duration(seconds: 1)),
        level: DebugLogLevel.error,
        message: 'Different message',
      );
      final e3 = DebugLogEntry(
        id: 11,
        timestamp: now,
        level: DebugLogLevel.info,
        message: 'First',
      );

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
      expect(e1, isNot(equals(e3)));
    });

    test('toString produces non-sensitive summary', () {
      final entry = DebugLogEntry(
        id: 5,
        timestamp: DateTime.now().toUtc(),
        level: DebugLogLevel.info,
        message: 'User logged in',
        tag: 'Auth',
        subTag: 'Session',
      );

      expect(
        entry.toString(),
        'DebugLogEntry(#5, info, tag: Auth/Session, message: User logged in)',
      );
    });
  });
}
