import 'dart:convert';

import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    DebugLog.dispose();
  });

  group('DebugLog and Controller Lifecycle (L-1..L-12)', () {
    test('DebugLog.init initializes default controller (L-3)', () {
      expect(DebugLog.controller, isNull);
      final controller = DebugLog.init();
      expect(DebugLog.controller, equals(controller));
      expect(controller.isActive, isTrue);
      expect(controller.isDisposed, isFalse);
    });

    test(
      'Repeated DebugLog.init disposes old default controller (L-3, D-03)',
      () {
        final first = DebugLog.init();
        var firstDisposedNotified = false;
        first.addListener(() {
          if (first.isDisposed) firstDisposedNotified = true;
        });

        final second = DebugLog.init();
        expect(first.isDisposed, isTrue);
        expect(firstDisposedNotified, isTrue);
        expect(second.isDisposed, isFalse);
        expect(DebugLog.controller, equals(second));
      },
    );

    test('DebugLog.dispose is idempotent and safe when called multiple times (L-5, L-8)', () {
      final controller = DebugLog.init();
      expect(DebugLog.controller, isNotNull);

      DebugLog.dispose();
      expect(DebugLog.controller, isNull);
      expect(controller.isDisposed, isTrue);

      // Second dispose should be a silent no-op
      expect(() => DebugLog.dispose(), returnsNormally);
      expect(() => controller.dispose(), returnsNormally);
    });

    test(
      'controller.dispose notifies listeners once and clears store (L-8)',
      () {
        final controller = DebugBubbleController();
        var notificationCount = 0;
        controller.addListener(() {
          notificationCount++;
        });

        controller.dispose();
        expect(notificationCount, 1);
        expect(controller.isDisposed, isTrue);
        expect(controller.isActive, isFalse);
        expect(controller.entryCount, 0);

        // Calling dispose again must not notify again
        controller.dispose();
        expect(notificationCount, 1);
      },
    );

    test('Operations on disposed controller are safe no-ops (L-8)', () {
      final controller = DebugBubbleController();
      controller.dispose();

      expect(() => controller.log(DebugLogLevel.info, 'test'), returnsNormally);
      expect(() => controller.clear(), returnsNormally);
      expect(() => controller.openDashboard(), returnsNormally);
      expect(() => controller.closeDashboard(), returnsNormally);
      expect(controller.isDashboardOpen, isFalse);
      expect(controller.query(const DebugLogFilter()), isEmpty);
      final jsonExport =
          jsonDecode(controller.exportJson()) as Map<String, Object?>;
      expect(jsonExport['schemaVersion'], 1);
      expect(jsonExport['totalEntries'], 0);
      expect(jsonExport['exportedEntries'], 0);
      expect(jsonExport['entries'], isEmpty);
      expect(
        controller.exportText(),
        'debug_bubble log export — 0 entries (0 older entries dropped)',
      );
    });

    test(
      'Standalone controller is independent of DebugLog facade (L-1, L-2)',
      () {
        final standalone = DebugBubbleController();
        DebugLog.init();

        expect(DebugLog.controller, isNot(equals(standalone)));
        DebugLog.dispose();
        expect(standalone.isDisposed, isFalse);

        standalone.dispose();
        expect(standalone.isDisposed, isTrue);
      },
    );

    test(
      'addListener and removeListener after dispose are safe no-ops (L-8)',
      () {
        final controller = DebugBubbleController();
        controller.dispose();

        void dummyListener() {}

        expect(() => controller.addListener(dummyListener), returnsNormally);
        expect(() => controller.removeListener(dummyListener), returnsNormally);
      },
    );

    test('Logging through stale controller reference after re-init is a safe no-op (L-3, D-03)', () {
      final c1 = DebugLog.init();
      c1.log(DebugLogLevel.info, 'Initial log on c1');
      expect(c1.entryCount, 1);

      // Re-initialize replaces c1
      final c2 = DebugLog.init();
      expect(c1.isDisposed, isTrue);
      expect(c2.isDisposed, isFalse);

      // Log via stale c1
      expect(() => c1.log(DebugLogLevel.info, 'Stale log'), returnsNormally);
      expect(c1.entryCount, 0); // c1 store was cleared on dispose
      expect(c2.entryCount, 0); // c2 was not touched by c1.log()

      // Facade log goes to active c2
      DebugLog.info('Active log on c2');
      expect(c2.entryCount, 1);
      expect(c1.entryCount, 0);
    });

    test('Facade call before init is a silent no-op (L-4, D-24)', () {
      expect(DebugLog.controller, isNull);
      expect(() => DebugLog.info('Before init log'), returnsNormally);
      expect(DebugLog.controller, isNull);
    });

    test('Facade call after dispose is a silent no-op (L-4, L-5)', () {
      DebugLog.init();
      DebugLog.dispose();
      expect(DebugLog.controller, isNull);

      expect(() => DebugLog.info('After dispose log'), returnsNormally);
      expect(DebugLog.controller, isNull);
    });

    test('Monotonic sequence IDs across controller replacement (L-3)', () {
      final c1 = DebugLog.init();
      c1.log(DebugLogLevel.info, 'c1 entry 1');
      c1.log(DebugLogLevel.info, 'c1 entry 2');
      expect(c1.entries.map((e) => e.id).toList(), equals([1, 2]));

      // New controller created via init starts its own sequence at 1
      final c2 = DebugLog.init();
      c2.log(DebugLogLevel.info, 'c2 entry 1');
      c2.log(DebugLogLevel.info, 'c2 entry 2');
      expect(c2.entries.map((e) => e.id).toList(), equals([1, 2]));
    });
  });
}
