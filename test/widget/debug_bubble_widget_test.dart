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
          const MaterialApp(home: DebugBubble(child: Text('App Content'))),
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
          const MaterialApp(home: DebugBubble(child: Text('Host'))),
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

  group(
    'DebugBubble UI Hosting & Overlay Structure (T3.1, ARCHITECTURE §4)',
    () {
      testWidgets(
        'Renders FloatingBubble above child when active and dashboard closed',
        (tester) async {
          final controller = DebugBubbleController();
          await tester.pumpWidget(
            MaterialApp(
              home: DebugBubble(
                controller: controller,
                child: const Scaffold(
                  body: Center(child: Text('Main Content')),
                ),
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
                child: const Scaffold(
                  body: Center(child: Text('Main Content')),
                ),
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
          final state =
              tester.state(find.byType(DebugBubble)) as WidgetsBindingObserver;
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
    },
  );

  group(
    'Regression Tests: Build-Phase Safe Logging & Notification Coalescing',
    () {
      testWidgets(
        'Logging in child initState() does not throw setState() or markNeedsBuild() during build',
        (tester) async {
          DebugLog.init();

          await tester.pumpWidget(
            const MaterialApp(
              home: DebugBubble(child: _LoggingInInitStateWidget()),
            ),
          );

          expect(find.text('InitState Rendered'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.pump();
          expect(DebugLog.controller?.entryCount, 1);
          expect(
            DebugLog.controller?.entries.first.message,
            'Logging from child initState()',
          );
        },
      );

      testWidgets(
        'Logging in child build() method does not throw or trigger recursive build loops',
        (tester) async {
          DebugLog.init();

          await tester.pumpWidget(
            const MaterialApp(
              home: DebugBubble(child: _LoggingInBuildWidget()),
            ),
          );

          expect(find.text('Build Rendered'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.pump();
          expect(DebugLog.controller?.entryCount, 1);
          expect(
            DebugLog.controller?.entries.first.message,
            'Logging from child build()',
          );
        },
      );

      testWidgets(
        'Burst of 50 logs during mount coalesces notifications and updates without frame errors',
        (tester) async {
          DebugLog.init();

          await tester.pumpWidget(
            const MaterialApp(home: DebugBubble(child: _BurstLoggingWidget())),
          );

          expect(find.text('Burst Done'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.pump();
          expect(DebugLog.controller?.entryCount, 50);
          expect(find.byType(FloatingBubble), findsOneWidget);
        },
      );

      testWidgets(
        'Ingesting logs does NOT rebuild the host application subtree',
        (tester) async {
          final controller = DebugLog.init();
          int childBuildCount = 0;

          await tester.pumpWidget(
            MaterialApp(
              home: DebugBubble(
                child: _SubtreeRebuildCounter(onBuild: () => childBuildCount++),
              ),
            ),
          );

          expect(childBuildCount, 1);

          // Ingest multiple logs
          controller.log(DebugLogLevel.info, 'Message 1');
          controller.log(DebugLogLevel.warning, 'Message 2');
          controller.log(DebugLogLevel.error, 'Message 3');

          // Allow post frame callbacks and any frame rebuilds
          await tester.pump();

          // The host app subtree should NOT have rebuilt
          expect(childBuildCount, 1);
          expect(controller.entryCount, 3);
        },
      );

      testWidgets(
        'Uncaught build error is captured cleanly without recursive notification loops',
        (tester) async {
          final controller = DebugBubbleController(
            config: const DebugBubbleConfig(captureUncaughtErrors: true),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: DebugBubble(
                controller: controller,
                child: const _ThrowingBuildWidget(),
              ),
            ),
          );

          // Exception during build is caught by FlutterError
          final error = tester.takeException();
          expect(error, isNotNull);

          await tester.pump();

          // Error was ingested into the controller
          expect(controller.errorCount, greaterThanOrEqualTo(1));
          expect(
            controller.entries.any(
              (e) => e.message.contains('Simulated crash during build'),
            ),
            isTrue,
          );

          controller.dispose();
        },
      );
    },
  );
}

class _LoggingInInitStateWidget extends StatefulWidget {
  const _LoggingInInitStateWidget();

  @override
  State<_LoggingInInitStateWidget> createState() =>
      _LoggingInInitStateWidgetState();
}

class _LoggingInInitStateWidgetState extends State<_LoggingInInitStateWidget> {
  @override
  void initState() {
    super.initState();
    DebugLog.info('Logging from child initState()');
  }

  @override
  Widget build(BuildContext context) => const Text('InitState Rendered');
}

class _LoggingInBuildWidget extends StatelessWidget {
  const _LoggingInBuildWidget();

  @override
  Widget build(BuildContext context) {
    DebugLog.info('Logging from child build()');
    return const Text('Build Rendered');
  }
}

class _BurstLoggingWidget extends StatefulWidget {
  const _BurstLoggingWidget();

  @override
  State<_BurstLoggingWidget> createState() => _BurstLoggingWidgetState();
}

class _BurstLoggingWidgetState extends State<_BurstLoggingWidget> {
  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 50; i++) {
      DebugLog.info('Burst message $i');
    }
  }

  @override
  Widget build(BuildContext context) => const Text('Burst Done');
}

class _SubtreeRebuildCounter extends StatelessWidget {
  const _SubtreeRebuildCounter({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const Text('Subtree');
  }
}

class _ThrowingBuildWidget extends StatelessWidget {
  const _ThrowingBuildWidget();

  @override
  Widget build(BuildContext context) {
    throw StateError('Simulated crash during build');
  }
}
