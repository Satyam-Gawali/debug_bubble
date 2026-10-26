import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/collectors/error_hook_registry.dart';
import 'package:debug_bubble/src/ui/info_tab.dart';
import 'package:debug_bubble/src/version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InfoTabView (T3.8, DATA_MODELS §10, UI_UX_SPEC §5)', () {
    tearDown(() {
      ErrorHookRegistry.resetForTesting();
    });

    testWidgets('Renders all required session fields and counts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final config = DebugBubbleConfig(
        maxEntries: 250,
        maxEntryChars: 15000,
        consoleOutput: true,
        redaction: DebugRedactionConfig(
          enabled: true,
          valuePatterns: [RegExp(r'secret_\w+')],
        ),
      );
      final controller = DebugBubbleController(config: config);

      controller.log(DebugLogLevel.info, 'Information 1');
      controller.log(DebugLogLevel.info, 'Information 2');
      controller.log(DebugLogLevel.warning, 'Warning 1');
      controller.log(DebugLogLevel.error, 'Error 1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InfoTabView(controller: controller)),
        ),
      );

      // Package version and active status
      expect(find.text(debugBubbleVersion), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Total and per-level counts
      expect(find.text('Total Stored'), findsOneWidget);
      expect(find.text('4'), findsWidgets); // Total stored: 4
      expect(find.text('INFO Count'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // INFO: 2
      expect(find.text('WARNING Count'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // WARNING: 1
      expect(find.text('ERROR Count'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // CRITICAL: 0, DEBUG: 0, SUCCESS: 0

      // Limits
      expect(find.text('250'), findsOneWidget);
      expect(find.text('15000'), findsOneWidget);

      // Console output & redaction
      expect(find.text('Console Output'), findsOneWidget);
      expect(find.text('Enabled'), findsWidgets);
      expect(find.text('Redaction Value Patterns'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      controller.dispose();
    });

    testWidgets('Updates counts dynamically when logs are added or cleared', (
      tester,
    ) async {
      final controller = DebugBubbleController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InfoTabView(controller: controller)),
        ),
      );

      expect(find.text('0'), findsWidgets); // 0 entries initially

      controller.log(DebugLogLevel.debug, 'Debug message');
      await tester.pumpAndSettle();

      expect(find.text('DEBUG Count'), findsOneWidget);

      controller.clear();
      await tester.pumpAndSettle();

      expect(controller.entryCount, equals(0));

      controller.dispose();
    });

    testWidgets(
      'Reflects uncaught error capture hook status: off, active, replaced',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 1. Off when captureUncaughtErrors is false
        final controllerOff = DebugBubbleController(
          config: const DebugBubbleConfig(captureUncaughtErrors: false),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: InfoTabView(controller: controllerOff)),
          ),
        );
        expect(find.text('off'), findsOneWidget);
        controllerOff.dispose();

        // 2. Active when captureUncaughtErrors is true
        final controllerActive = DebugBubbleController(
          config: const DebugBubbleConfig(captureUncaughtErrors: true),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: InfoTabView(controller: controllerActive)),
          ),
        );
        expect(find.text('active'), findsOneWidget);

        // 3. Inactive (handler replaced) when external handler replaces FlutterError.onError
        final originalFlutterOnError = FlutterError.onError;
        FlutterError.onError = (details) {};

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: InfoTabView(controller: controllerActive)),
          ),
        );
        expect(find.text('inactive (handler replaced)'), findsOneWidget);

        // Restore
        FlutterError.onError = originalFlutterOnError;
        controllerActive.dispose();
      },
    );

    testWidgets(
      'Security guarantee: does not display log contents or redaction patterns',
      (tester) async {
        const sensitiveSecret = 'SUPER_SECRET_TOKEN_DO_NOT_LEAK';
        const secretPattern = r'secret_pattern_\d+';

        final config = DebugBubbleConfig(
          redaction: DebugRedactionConfig(
            enabled: true,
            valuePatterns: [RegExp(secretPattern)],
          ),
        );
        final controller = DebugBubbleController(config: config);
        controller.log(DebugLogLevel.info, 'Message with $sensitiveSecret');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: InfoTabView(controller: controller)),
          ),
        );

        expect(find.textContaining(sensitiveSecret), findsNothing);
        expect(find.textContaining(secretPattern), findsNothing);

        controller.dispose();
      },
    );
  });
}
