import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/ui/bubble.dart';
import 'package:debug_bubble/src/ui/dashboard.dart';
import 'package:flutter/material.dart';
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
          const MaterialApp(
            home: DebugBubble(child: Text('App Content')),
          ),
        );

        expect(find.text('App Content'), findsOneWidget);
        expect(find.byType(FloatingBubble), findsNothing);
        expect(find.byType(DashboardOverlay), findsNothing);
      },
    );

    testWidgets(
      'Automatically rebinds when default controller is initialized or replaced',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: DebugBubble(child: Text('Host')),
          ),
        );

        // Initialize default controller
        final controller1 = DebugLog.init();
        await tester.pump();
        expect(find.text('Host'), findsOneWidget);
        expect(find.byType(FloatingBubble), findsOneWidget);

        // Replace default controller with a new one (L-3, D-03)
        final controller2 = DebugLog.init();
        await tester.pump();

        expect(controller1.isDisposed, isTrue);
        expect(controller2.isDisposed, isFalse);
        expect(find.text('Host'), findsOneWidget);
        expect(find.byType(FloatingBubble), findsOneWidget);

        // Dispose default controller
        DebugLog.dispose();
        await tester.pump();
        expect(controller2.isDisposed, isTrue);
        expect(find.text('Host'), findsOneWidget);
        expect(find.byType(FloatingBubble), findsNothing);
      },
    );

    testWidgets(
      'Widget with explicit controller does not follow default controller',
      (tester) async {
        final standalone = DebugBubbleController();
        await tester.pumpWidget(
          MaterialApp(
            home: DebugBubble(
              controller: standalone,
              child: const Text('Standalone Host'),
            ),
          ),
        );

        expect(find.byType(FloatingBubble), findsOneWidget);

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
        expect(find.byType(FloatingBubble), findsNothing);
      },
    );

    testWidgets(
      'Widget unbinds cleanly on unmount without disposing controller (L-7)',
      (tester) async {
        final controller = DebugBubbleController();
        await tester.pumpWidget(
          MaterialApp(
            home: DebugBubble(
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

  group('DebugBubble UI Hosting & Overlay Structure (T3.1, ARCHITECTURE §4)', () {
    testWidgets(
      'Renders FloatingBubble above child when active and dashboard closed',
      (tester) async {
        final controller = DebugBubbleController();
        await tester.pumpWidget(
          MaterialApp(
            home: DebugBubble(
              controller: controller,
              child: const Scaffold(body: Center(child: Text('Main Content'))),
            ),
          ),
        );

        expect(find.text('Main Content'), findsOneWidget);
        expect(find.byType(FloatingBubble), findsOneWidget);
        expect(find.byType(DashboardOverlay), findsNothing);
        controller.dispose();
      },
    );

    testWidgets(
      'Renders DashboardOverlay and hides FloatingBubble when dashboard open',
      (tester) async {
        final controller = DebugBubbleController();
        await tester.pumpWidget(
          MaterialApp(
            home: DebugBubble(
              controller: controller,
              child: const Scaffold(body: Center(child: Text('Main Content'))),
            ),
          ),
        );

        expect(find.byType(FloatingBubble), findsOneWidget);
        expect(find.byType(DashboardOverlay), findsNothing);

        controller.openDashboard();
        await tester.pump();

        expect(find.byType(FloatingBubble), findsNothing);
        expect(find.byType(DashboardOverlay), findsOneWidget);
        controller.dispose();
      },
    );

    testWidgets(
      'Renders only child when controller is inactive (enabled = false)',
      (tester) async {
        final controller = DebugBubbleController(
          config: const DebugBubbleConfig(enabled: false),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: DebugBubble(
              controller: controller,
              child: const Text('Inert Child'),
            ),
          ),
        );

        expect(find.text('Inert Child'), findsOneWidget);
        expect(find.byType(FloatingBubble), findsNothing);
        expect(find.byType(DashboardOverlay), findsNothing);
        controller.dispose();
      },
    );

    testWidgets(
      'System back button closes dashboard when open without popping route (D-27)',
      (tester) async {
        final controller = DebugBubbleController();
        await tester.pumpWidget(
          MaterialApp(
            home: DebugBubble(
              controller: controller,
              child: const Scaffold(body: Text('Route 1')),
            ),
          ),
        );

        // With dashboard closed, back handler returns false
        final state = tester.state(find.byType(DebugBubble)) as WidgetsBindingObserver;
        final popResultWhenClosed = await state.didPopRoute();
        expect(popResultWhenClosed, isFalse);

        // Open dashboard
        controller.openDashboard();
        await tester.pump();
        expect(controller.isDashboardOpen, isTrue);

        // With dashboard open, back handler closes dashboard and returns true
        final popResultWhenOpen = await state.didPopRoute();
        expect(popResultWhenOpen, isTrue);
        expect(controller.isDashboardOpen, isFalse);

        controller.dispose();
      },
    );
  });
}
