import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/ui/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard Actions (T3.6, UI_UX_SPEC §6)', () {
    String? clipboardContent;

    setUp(() {
      clipboardContent = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = call.arguments as Map<dynamic, dynamic>?;
          clipboardContent = data?['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardContent};
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('Overflow menu displays Copy all, Export JSON, and Clear all',
        (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Message 1');

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

      // Tap overflow menu button
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('Copy all'), findsOneWidget);
      expect(find.text('Export JSON'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Copy all copies filtered plain text to clipboard and shows feedback',
        (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Info entry');
      controller.log(DebugLogLevel.error, 'Error entry');

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

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy all'));
      await tester.pumpAndSettle();

      expect(clipboardContent, contains('Info entry'));
      expect(clipboardContent, contains('Error entry'));
      expect(find.text('Copied 2 entries'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Export JSON invokes onExport callback and copies to clipboard',
        (tester) async {
      String? exportedPayload;
      final config = DebugBubbleConfig(
        onExport: (jsonStr) {
          exportedPayload = jsonStr;
        },
      );
      final controller = DebugBubbleController(config: config);
      controller.log(DebugLogLevel.info, 'Entry for JSON export');

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

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export JSON'));
      await tester.pumpAndSettle();

      expect(exportedPayload, isNotNull);
      expect(exportedPayload, contains('Entry for JSON export'));
      expect(clipboardContent, isNotNull);
      expect(clipboardContent, contains('schemaVersion'));
      expect(find.text('Exported JSON'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Export JSON catches onExport callback failure and shows specific feedback',
        (tester) async {
      final config = DebugBubbleConfig(
        onExport: (jsonStr) async {
          throw FormatException('Simulated export network failure');
        },
      );
      final controller = DebugBubbleController(config: config);
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

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export JSON'));
      await tester.pumpAndSettle();

      // UI_UX_SPEC §6: UI shows "Export callback failed (ExceptionType)"
      expect(find.text('Export callback failed (FormatException)'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Clear all requires confirmation before clearing entries',
        (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Info msg');
      controller.log(DebugLogLevel.error, 'Error msg');
      expect(controller.entryCount, equals(2));

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

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears inside overlay
      expect(
        find.text('Clear all 2 entries? This cannot be undone.'),
        findsOneWidget,
      );

      // Tapping Cancel keeps entries intact
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.entryCount, equals(2));
      expect(find.text('Clear all 2 entries? This cannot be undone.'), findsNothing);

      // Tap Clear all again and confirm
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(controller.entryCount, equals(0));
      expect(find.text('Logs cleared'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Back button precedence: menu -> dialog -> detail -> close',
        (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Info msg');

      final key = GlobalKey<DashboardOverlayState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DashboardOverlay(key: key, controller: controller),
              ],
            ),
          ),
        ),
      );

      // Open menu
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(find.text('Copy all'), findsOneWidget);

      // Back handles menu first
      final handledMenu = key.currentState!.handleBack();
      expect(handledMenu, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Copy all'), findsNothing);

      // Open dialog
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('Clear logs'), findsOneWidget);

      // Back handles dialog second
      final handledDialog = key.currentState!.handleBack();
      expect(handledDialog, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Clear logs'), findsNothing);

      // Tap on row to open detail view
      await tester.tap(find.text('Info msg'));
      await tester.pumpAndSettle();
      expect(find.text('Entry #1'), findsOneWidget);

      // Back handles detail view third
      final handledDetail = key.currentState!.handleBack();
      expect(handledDetail, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Entry #1'), findsNothing);

      // Now nothing left to handle; returns false so dashboard can close
      final handledRoot = key.currentState!.handleBack();
      expect(handledRoot, isFalse);

      controller.dispose();
    });
  });
}
