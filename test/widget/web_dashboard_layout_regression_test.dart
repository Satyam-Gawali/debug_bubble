import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/collectors/error_hook_registry.dart';
import 'package:debug_bubble/src/ui/bubble.dart';
import 'package:debug_bubble/src/ui/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web Dashboard Layout & Frame Safety Regression Tests', () {
    tearDown(() {
      ErrorHookRegistry.resetForTesting();
    });

    testWidgets(
        'Opening overflow menu under narrow viewport (320px) does not force infinite width',
        (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Sample entry');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DashboardOverlay(controller: controller),
              ],
            ),
          ),
        ),
      );

      // Open overflow menu
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      // Verify no BoxConstraints forces infinite width exception
      expect(tester.takeException(), isNull);
      expect(find.text('Copy all'), findsOneWidget);
      expect(find.text('Export JSON'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);

      // Tap outside to dismiss
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Copy all'), findsNothing);
      expect(tester.takeException(), isNull);

      controller.dispose();
    });

    testWidgets(
        'Controller notification during layout (persistentCallbacks) is deferred and does not throw',
        (tester) async {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );

      var didLayout = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DebugBubble(
              controller: controller,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Runs directly during RenderObject layout pass
                  if (!didLayout) {
                    didLayout = true;
                    controller.log(DebugLogLevel.error, 'Error during layout');
                  }
                  return const Text('Host Content');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify layout ran and no "Build scheduled during frame" occurred
      expect(didLayout, isTrue);
      expect(tester.takeException(), isNull);
      expect(controller.entryCount, equals(1));

      controller.dispose();
    });

    testWidgets(
        'Recursive error reporting does not cause an infinite cascade',
        (tester) async {
      var hostHandlerCallCount = 0;
      final originalFlutterOnError = FlutterError.onError;
      try {
        FlutterError.onError = (details) {
          hostHandlerCallCount++;
        };

        final controller = DebugBubbleController(
          config: const DebugBubbleConfig(captureUncaughtErrors: true),
        );

        FlutterError.reportError(
          FlutterErrorDetails(
            exception: Exception('Simulated root layout crash'),
            stack: StackTrace.current,
          ),
        );

        expect(hostHandlerCallCount, equals(1));
        expect(controller.entryCount, equals(1));
        expect(controller.entries.first.message, contains('Simulated root layout crash'));

        controller.dispose();
      } finally {
        FlutterError.onError = originalFlutterOnError;
      }
    });

    testWidgets(
        'Live dashboard updates correctly after deferred notifications',
        (tester) async {
      final controller = DebugBubbleController();
      controller.openDashboard();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DashboardOverlay(controller: controller),
              ],
            ),
          ),
        ),
      );

      expect(find.text('No logs yet'), findsOneWidget);

      // Log entry while dashboard is mounted
      controller.log(DebugLogLevel.info, 'Live incoming entry');
      await tester.pumpAndSettle();

      expect(find.text('Live incoming entry'), findsOneWidget);
      expect(find.text('1 entry · 0 errors'), findsOneWidget);

      controller.dispose();
    });

    testWidgets(
        'Dashboard closed and open states toggle cleanly without layout errors',
        (tester) async {
      final controller = DebugBubbleController();

      await tester.pumpWidget(
        MaterialApp(
          home: DebugBubble(
            controller: controller,
            child: const Scaffold(
              body: Center(child: Text('Host Child')),
            ),
          ),
        ),
      );

      // Closed state: FloatingBubble is visible, DashboardOverlay is not
      expect(find.byType(DashboardOverlay), findsNothing);
      expect(find.byType(FloatingBubble), findsOneWidget);

      // Open dashboard
      controller.openDashboard();
      await tester.pumpAndSettle();

      expect(find.byType(DashboardOverlay), findsOneWidget);
      expect(find.byType(FloatingBubble), findsNothing);

      // Close dashboard
      controller.closeDashboard();
      await tester.pumpAndSettle();

      expect(find.byType(DashboardOverlay), findsNothing);
      expect(find.byType(FloatingBubble), findsOneWidget);

      controller.dispose();
    });
  });
}
