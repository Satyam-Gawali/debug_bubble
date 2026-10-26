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
      expect(controller.exportJson(), isEmpty);
      expect(controller.exportText(), isEmpty);
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
  });
}
