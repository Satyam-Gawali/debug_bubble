import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/ui/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardOverlay Widget Tests (T3.3, UI_UX_SPEC §2)', () {
    testWidgets('Renders top bar with title, stats, and close button', (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Info msg 1');
      controller.log(DebugLogLevel.error, 'Error msg 1');

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

      expect(find.text('Debug Dashboard'), findsOneWidget);
      expect(find.text('2 entries · 1 error'), findsOneWidget);
      expect(find.byTooltip('Close dashboard'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Tapping close button closes dashboard', (tester) async {
      final controller = DebugBubbleController();
      controller.openDashboard();
      expect(controller.isDashboardOpen, isTrue);

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

      await tester.tap(find.byTooltip('Close dashboard'));
      await tester.pump();

      expect(controller.isDashboardOpen, isFalse);
      controller.dispose();
    });

    testWidgets('Renders TabBar with Logs, Errors, and Info tabs', (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.error, 'Err 1');

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

      expect(find.text('Logs'), findsOneWidget);
      expect(find.text('Errors'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);

      // Errors tab shows badge
      expect(find.descendant(of: find.byType(TabBar), matching: find.text('1')), findsOneWidget);

      // Tap on Info tab
      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();

      expect(find.text('Session Info'), findsOneWidget);
      expect(find.text('Package Version'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Transition respects disableAnimations', (tester) async {
      final controller = DebugBubbleController();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  DashboardOverlay(controller: controller),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Debug Dashboard'), findsOneWidget);
      controller.dispose();
    });
  });
}
