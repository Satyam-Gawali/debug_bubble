import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/ui/bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FloatingBubble Widget Tests (T3.2, UI_UX_SPEC §1)', () {
    testWidgets('Renders 56x56 circular bubble with bug icon', (tester) async {
      final controller = DebugBubbleController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [FloatingBubble(controller: controller)]),
          ),
        ),
      );

      final bubbleFinder = find.byType(FloatingBubble);
      expect(bubbleFinder, findsOneWidget);

      final iconFinder = find.byIcon(Icons.bug_report);
      expect(iconFinder, findsOneWidget);

      final containerFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.minWidth == 56.0 &&
            w.constraints?.minHeight == 56.0,
      );
      expect(containerFinder, findsOneWidget);

      controller.dispose();
    });

    testWidgets('Tapping bubble opens dashboard', (tester) async {
      final controller = DebugBubbleController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [FloatingBubble(controller: controller)]),
          ),
        ),
      );

      expect(controller.isDashboardOpen, isFalse);

      await tester.tap(find.byType(FloatingBubble));
      await tester.pump();

      expect(controller.isDashboardOpen, isTrue);
      controller.dispose();
    });

    testWidgets('Error badge is hidden when errorCount is 0', (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Regular info message');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [FloatingBubble(controller: controller)]),
          ),
        ),
      );

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsNothing);

      controller.dispose();
    });

    testWidgets('Error badge displays formatted count when errors exist', (
      tester,
    ) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.error, 'Error 1');
      controller.log(DebugLogLevel.critical, 'Critical 1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [FloatingBubble(controller: controller)]),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);

      // Decreases reactively on clear
      controller.clear();
      await tester.pump();
      expect(find.text('2'), findsNothing);

      controller.dispose();
    });

    testWidgets('Error badge caps at 99+ when errorCount exceeds 99', (
      tester,
    ) async {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(maxEntries: 200),
      );
      for (var i = 0; i < 105; i++) {
        controller.log(DebugLogLevel.error, 'Error $i');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [FloatingBubble(controller: controller)]),
          ),
        ),
      );

      expect(find.text('99+'), findsOneWidget);
      controller.dispose();
    });

    testWidgets(
      'Dragging bubble updates position and snaps to nearest edge on release',
      (tester) async {
        final controller = DebugBubbleController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [FloatingBubble(controller: controller)]),
            ),
          ),
        );

        final initialTopLeft = tester.getTopLeft(find.byType(FloatingBubble));

        // Drag bubble toward the left side of the screen
        await tester.drag(find.byType(FloatingBubble), const Offset(-500, 50));
        await tester.pumpAndSettle();

        final newTopLeft = tester.getTopLeft(find.byType(FloatingBubble));
        // Should have snapped toward the left edge
        expect(newTopLeft.dx < initialTopLeft.dx, isTrue);

        controller.dispose();
      },
    );

    testWidgets('Semantic label includes error count when errors exist', (
      tester,
    ) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.error, 'Error item');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [FloatingBubble(controller: controller)]),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Open debug dashboard, 1 errors',
        ),
        findsOneWidget,
      );

      controller.dispose();
    });
  });
}
