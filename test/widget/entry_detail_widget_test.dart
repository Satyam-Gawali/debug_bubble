import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/ui/dashboard.dart';
import 'package:debug_bubble/src/ui/entry_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntryDetailView Widget Tests (T3.5, UI_UX_SPEC §4)', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') return null;
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    testWidgets('Renders all entry fields, headers, and truncation warning', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final entry = DebugLogEntry(
        id: 42,
        timestamp: DateTime.utc(2026, 10, 26, 12, 0, 0),
        level: DebugLogLevel.error,
        message: 'Database sync failure',
        tag: 'Database',
        subTag: 'Sync',
        error: const DebugErrorInfo(
          type: 'SocketException',
          message: 'Connection timed out',
        ),
        stackTrace: '#0 init()\n#1 main()',
        metadata: {'userId': 1234, 'attempt': 3},
        json: {'status': 'failed', 'code': 500},
        truncated: true,
      );

      var backed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: EntryDetailView(entry: entry, onBack: () => backed = true),
        ),
      );

      // Header details
      expect(find.text('Entry #42'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);
      expect(find.text('#42'), findsOneWidget);
      expect(find.text('Tag: '), findsOneWidget);
      expect(find.text('Database/Sync'), findsOneWidget);
      expect(find.text('UTC: 2026-10-26T12:00:00.000Z'), findsOneWidget);
      expect(
        find.text('Some content was truncated due to entry size limits.'),
        findsOneWidget,
      );

      // Message
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Database sync failure'), findsOneWidget);

      // Error
      expect(find.text('Error Details'), findsOneWidget);
      expect(find.text('Type: SocketException'), findsOneWidget);
      expect(find.text('Connection timed out'), findsOneWidget);

      // Stack trace
      expect(find.text('Stack Trace'), findsOneWidget);
      expect(find.text('#0 init()\n#1 main()'), findsOneWidget);

      // Metadata
      expect(find.text('Metadata'), findsOneWidget);
      expect(find.textContaining('"userId": 1234'), findsOneWidget);

      // JSON payload
      expect(find.text('JSON Payload'), findsOneWidget);
      expect(find.textContaining('"status": "failed"'), findsOneWidget);

      // Back button
      await tester.tap(find.byTooltip('Back to list'));
      expect(backed, isTrue);
    });

    testWidgets(
      'Omits absent fields cleanly and hides truncation warning when false',
      (tester) async {
        final entry = DebugLogEntry(
          id: 1,
          timestamp: DateTime.utc(2026, 10, 26, 12, 0, 0),
          level: DebugLogLevel.info,
          message: 'Minimal log message',
          truncated: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: EntryDetailView(entry: entry, onBack: () {}),
          ),
        );

        expect(find.text('Minimal log message'), findsOneWidget);
        expect(find.text('Error Details'), findsNothing);
        expect(find.text('Stack Trace'), findsNothing);
        expect(find.text('Metadata'), findsNothing);
        expect(find.text('JSON Payload'), findsNothing);
        expect(
          find.text('Some content was truncated due to entry size limits.'),
          findsNothing,
        );
      },
    );

    testWidgets('Copy buttons display feedback banner', (tester) async {
      final entry = DebugLogEntry(
        id: 7,
        timestamp: DateTime.utc(2026, 10, 26, 12, 0, 0),
        level: DebugLogLevel.warning,
        message: 'Warning text to copy',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EntryDetailView(entry: entry, onBack: () {}),
        ),
      );

      // Copy plain text
      await tester.tap(find.byTooltip('Copy entry text'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Copied entry to clipboard'), findsOneWidget);

      // Advance past feedback dismissal before second tap
      await tester.pump(const Duration(seconds: 2));

      // Copy JSON
      await tester.tap(find.byTooltip('Copy JSON'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Copied JSON to clipboard'), findsOneWidget);
    });

    testWidgets(
      'Clipboard failure displays "Copy failed" feedback without throwing',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall call,
            ) async {
              if (call.method == 'Clipboard.setData') {
                throw Exception('Simulated clipboard permission denied');
              }
              return null;
            });

        final entry = DebugLogEntry(
          id: 8,
          timestamp: DateTime.utc(2026, 10, 26, 12, 0, 0),
          level: DebugLogLevel.error,
          message: 'Error to copy with failing clipboard',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: EntryDetailView(entry: entry, onBack: () {}),
          ),
        );

        await tester.tap(find.byTooltip('Copy entry text'));
        await tester.pump();
        expect(find.text('Copy failed'), findsOneWidget);

        await tester.tap(find.byTooltip('Copy JSON'));
        await tester.pump();
        expect(find.text('Copy failed'), findsOneWidget);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      },
    );

    testWidgets(
      'DashboardOverlay navigation: tapping row opens details and back returns to list',
      (tester) async {
        final controller = DebugBubbleController();
        controller.log(
          DebugLogLevel.info,
          'Selectable message',
          tag: 'NavTest',
        );
        controller.openDashboard();

        final dashboardKey = GlobalKey<DashboardOverlayState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  DashboardOverlay(key: dashboardKey, controller: controller),
                ],
              ),
            ),
          ),
        );

        // Verify log row is visible
        expect(find.text('Selectable message'), findsOneWidget);
        expect(find.byType(EntryDetailView), findsNothing);

        // Tap on row to expand inline, then tap Open full page
        await tester.tap(find.text('Selectable message'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Open full page'));
        await tester.pumpAndSettle();

        // Detail view is now displayed
        expect(find.byType(EntryDetailView), findsOneWidget);
        expect(find.text('Entry #1'), findsOneWidget);

        // System back handler closes detail view first
        final handled = dashboardKey.currentState?.handleBack();
        expect(handled, isTrue);
        await tester.pumpAndSettle();

        // Back to log list
        expect(find.byType(EntryDetailView), findsNothing);
        expect(find.text('Selectable message'), findsOneWidget);

        controller.dispose();
      },
    );
  });
}
