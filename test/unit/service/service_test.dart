import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/collectors/console_sink.dart';
import 'package:debug_bubble/src/core/debug_log_service.dart';
import 'package:debug_bubble/src/core/debug_log_store.dart';
import 'package:debug_bubble/src/utils/build_mode.dart';
import 'package:flutter_test/flutter_test.dart';

class _HostileThrowingObject {
  @override
  String toString() {
    throw StateError('Hostile toString failure');
  }
}

void main() {
  tearDown(() {
    BuildMode.reset();
    ConsoleSink.testListener = null;
    DebugLog.dispose();
  });

  group('DebugLogService Pipeline & Gates (ARCHITECTURE §2, D-11)', () {
    test('Silent no-op when enabled is false', () {
      final store = DebugLogStore(maxEntries: 10);
      final service = DebugLogService(
        config: const DebugBubbleConfig(enabled: false),
        store: store,
      );

      final entry = service.log(DebugLogLevel.info, 'Disabled log');
      expect(entry, isNull);
      expect(store.length, 0);
    });

    test('Silent no-op when build mode is release (D-04)', () {
      BuildMode.releaseOverride = true;
      final store = DebugLogStore(maxEntries: 10);
      final service = DebugLogService(
        config: const DebugBubbleConfig(enabled: true),
        store: store,
      );

      final entry = service.log(DebugLogLevel.error, 'Release log');
      expect(entry, isNull);
      expect(store.length, 0);
    });

    test('Silent no-op when owning controller is inactive or disposed', () {
      final store = DebugLogStore(maxEntries: 10);
      var active = false;
      final service = DebugLogService(
        config: const DebugBubbleConfig(),
        store: store,
        isActiveGetter: () => active,
      );

      expect(service.log(DebugLogLevel.info, 'Inactive'), isNull);
      expect(store.length, 0);

      active = true;
      expect(service.log(DebugLogLevel.info, 'Active'), isNotNull);
      expect(store.length, 1);
    });

    test('minLevel gate: warning drops debug, info, and success (D-11)', () {
      final store = DebugLogStore(maxEntries: 10);
      final service = DebugLogService(
        config: const DebugBubbleConfig(minLevel: DebugLogLevel.warning),
        store: store,
      );

      // Dropped levels
      expect(service.log(DebugLogLevel.debug, 'Debug'), isNull);
      expect(service.log(DebugLogLevel.info, 'Info'), isNull);
      expect(service.log(DebugLogLevel.success, 'Success'), isNull);
      expect(store.length, 0);
      expect(
        store.droppedCount,
        0,
      ); // Gate rejections do NOT increment droppedCount (D-23)

      // Accepted levels
      expect(service.log(DebugLogLevel.warning, 'Warning'), isNotNull);
      expect(service.log(DebugLogLevel.error, 'Error'), isNotNull);
      expect(service.log(DebugLogLevel.critical, 'Critical'), isNotNull);
      expect(store.length, 3);
    });
  });

  group('Entry Creation & Monotonic Sequence IDs (DATA_MODELS §2, §5)', () {
    test('Sequence IDs increment monotonically starting at 1', () {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Entry 1');
      controller.log(DebugLogLevel.info, 'Entry 2');
      controller.log(DebugLogLevel.info, 'Entry 3');

      expect(controller.entries.map((e) => e.id).toList(), equals([1, 2, 3]));
    });

    test('Sequence IDs are NOT reset when clearing store (DATA_MODELS §5)', () {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Entry 1');
      controller.log(DebugLogLevel.info, 'Entry 2');
      expect(controller.entries.length, 2);

      controller.clear();
      expect(controller.entries.length, 0);
      expect(controller.droppedCount, 0);

      controller.log(DebugLogLevel.info, 'Entry 3');
      expect(controller.entries.single.id, 3); // Continues monotonic sequence!
    });

    test('Timestamps are normalized to UTC', () {
      final store = DebugLogStore(maxEntries: 5);
      final service = DebugLogService(
        config: const DebugBubbleConfig(),
        store: store,
      );

      final localTime = DateTime(2026, 10, 26, 15, 30, 0);
      final entry = service.log(
        DebugLogLevel.info,
        'UTC test',
        timestamp: localTime,
      );

      expect(entry!.timestamp.isUtc, isTrue);
      expect(entry.timestamp, equals(localTime.toUtc()));
    });
  });

  group('Store Integration & Controller Notification', () {
    test('Controller notifies listeners on entry ingestion', () {
      final controller = DebugBubbleController();
      var notificationCount = 0;
      controller.addListener(() {
        notificationCount++;
      });

      controller.log(DebugLogLevel.info, 'Message 1');
      expect(notificationCount, 1);
      expect(controller.entryCount, 1);

      controller.log(DebugLogLevel.error, 'Error 1');
      expect(notificationCount, 2);
      expect(controller.entryCount, 2);
      expect(controller.errorCount, 1);
    });

    test('Ring buffer eviction increments droppedCount', () {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(maxEntries: 2),
      );

      controller.log(DebugLogLevel.info, 'E1');
      controller.log(DebugLogLevel.info, 'E2');
      expect(controller.entryCount, 2);
      expect(controller.droppedCount, 0);

      controller.log(DebugLogLevel.info, 'E3'); // Evicts E1
      expect(controller.entryCount, 2);
      expect(controller.droppedCount, 1);
      expect(
        controller.entries.map((e) => e.message).toList(),
        equals(['E2', 'E3']),
      );
    });
  });

  group('Sentinel Secret Non-Retention (SECURITY_PERFORMANCE §3)', () {
    const sentinelSecret = 'SENTINEL_SECRET_XYZ_99999';

    test(
      'Sentinel secret is redacted across all fields and console output',
      () {
        String? consoleOutput;
        ConsoleSink.testListener = (formatted, entry) {
          consoleOutput = formatted;
        };

        final config = DebugRedactionConfig(
          valuePatterns: [RegExp(r'SENTINEL_SECRET_\w+')],
        );
        final controller = DebugBubbleController(
          config: DebugBubbleConfig(redaction: config),
        );

        controller.log(
          DebugLogLevel.error,
          'Log with $sentinelSecret in message',
          tag: 'Tag_$sentinelSecret',
          subTag: 'Sub_$sentinelSecret',
          error: Exception('Error with $sentinelSecret'),
          metadata: {
            'password': sentinelSecret,
            'user_pin': 1234,
            'info': 'Has $sentinelSecret',
          },
          json: {'token': sentinelSecret, 'data': 'Payload $sentinelSecret'},
        );

        final entry = controller.entries.single;

        // 1. Stored entry fields must never contain sentinel secret
        expect(entry.message.contains(sentinelSecret), isFalse);
        expect(entry.tag?.contains(sentinelSecret), isFalse);
        expect(entry.subTag?.contains(sentinelSecret), isFalse);
        expect(entry.error?.message.contains(sentinelSecret), isFalse);
        expect(entry.metadata.toString().contains(sentinelSecret), isFalse);
        expect(entry.json.toString().contains(sentinelSecret), isFalse);

        // 2. entry.toString() must never contain sentinel secret
        expect(entry.toString().contains(sentinelSecret), isFalse);

        // 3. Console output must never contain sentinel secret
        expect(consoleOutput, isNotNull);
        expect(consoleOutput!.contains(sentinelSecret), isFalse);
      },
    );
  });

  group('Failure Isolation & Host Safety (NFR-03)', () {
    test(
      'Hostile object with throwing toString does not throw into caller',
      () {
        final controller = DebugBubbleController();
        final hostile = _HostileThrowingObject();

        expect(
          () => controller.log(
            DebugLogLevel.error,
            'Hostile log',
            error: hostile,
            json: {'hostile': hostile},
          ),
          returnsNormally,
        );

        expect(controller.entryCount, 1);
        final entry = controller.entries.single;
        expect(entry.error?.message, contains('[Unprintable'));
      },
    );
  });
}
