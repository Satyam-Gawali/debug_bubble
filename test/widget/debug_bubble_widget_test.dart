import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    DebugLog.dispose();
  });

  group('DebugBubble Widget Lifecycle and Rebinding (L-6, L-7, L-8)', () {
    testWidgets(
      'Renders child directly when no controller exists (Phase 1 scaffold)',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: DebugBubble(child: Text('App Content')),
          ),
        );

        expect(find.text('App Content'), findsOneWidget);
      },
    );

    testWidgets(
      'Automatically rebinds when default controller is initialized or replaced',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: DebugBubble(child: Text('Host')),
          ),
        );

        // Initialize default controller
        final controller1 = DebugLog.init();
        await tester.pump();
        expect(find.text('Host'), findsOneWidget);

        // Replace default controller with a new one (L-3, D-03)
        final controller2 = DebugLog.init();
        await tester.pump();

        expect(controller1.isDisposed, isTrue);
        expect(controller2.isDisposed, isFalse);
        expect(find.text('Host'), findsOneWidget);

        // Dispose default controller
        DebugLog.dispose();
        await tester.pump();
        expect(controller2.isDisposed, isTrue);
        expect(find.text('Host'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget with explicit controller does not follow default controller',
      (tester) async {
        final standalone = DebugBubbleController();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DebugBubble(
              controller: standalone,
              child: const Text('Standalone Host'),
            ),
          ),
        );

        // Initializing or disposing default controller should not affect standalone
        DebugLog.init();
        await tester.pump();
        expect(standalone.isDisposed, isFalse);

        DebugLog.dispose();
        await tester.pump();
        expect(standalone.isDisposed, isFalse);

        // Explicitly dispose standalone
        standalone.dispose();
        await tester.pump();
        expect(standalone.isDisposed, isTrue);
      },
    );

    testWidgets(
      'Widget unbinds cleanly on unmount without disposing controller (L-7)',
      (tester) async {
        final controller = DebugBubbleController();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: DebugBubble(
              controller: controller,
              child: const Text('Mount Test'),
            ),
          ),
        );

        // Unmount DebugBubble
        await tester.pumpWidget(const SizedBox.shrink());

        // Controller must NOT be disposed by widget unmount (L-7)
        expect(controller.isDisposed, isFalse);
        controller.dispose();
      },
    );
  });
}
