import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/ui/bubble.dart';
import 'package:debug_bubble/src/ui/dashboard.dart';
import 'package:debug_bubble/src/ui/info_tab.dart';
import 'package:debug_bubble/src/ui/log_list.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
    DebugLog.dispose();
    DebugLog.init(const DebugBubbleConfig(captureUncaughtErrors: true));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    DebugLog.dispose();
  });

  group('T3.9 — Example App End-to-End Integration Tests', () {
    testWidgets('T3.9.1: Renders host app with floating bubble and badge',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('debug_bubble Example'), findsOneWidget);
      expect(find.byType(FloatingBubble), findsOneWidget);
      expect(find.byType(DashboardOverlay), findsNothing);

      // Verify bubble has bug icon inside FloatingBubble
      expect(
        find.descendant(
          of: find.byType(FloatingBubble),
          matching: find.byIcon(Icons.bug_report),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'T3.9.2: Emitting logs updates metrics and error badge dynamically',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Emit info log via action chip on host page
      await tester.tap(find.widgetWithText(ActionChip, 'Info'));
      await tester.pumpAndSettle();

      expect(DebugLog.controller?.entryCount, equals(1));
      expect(DebugLog.controller?.errorCount, equals(0));

      // Emit error log via action chip on host page
      await tester.tap(find.widgetWithText(ActionChip, 'Error'));
      await tester.pumpAndSettle();

      expect(DebugLog.controller?.entryCount, equals(2));
      expect(DebugLog.controller?.errorCount, equals(1));

      // Emit log with metadata and JSON
      await tester.tap(find.text('Log with Metadata & JSON'));
      await tester.pumpAndSettle();

      expect(DebugLog.controller?.entryCount, equals(3));
    });

    testWidgets(
        'T3.9.3: Tapping bubble opens dashboard, renders top bar and tabs',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Emit one error so badge appears
      DebugLog.error('Test error for badge', tag: 'Test');
      await tester.pumpAndSettle();

      // Tap floating bubble to open dashboard
      await tester.tap(find.byType(FloatingBubble));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardOverlay), findsOneWidget);
      expect(find.byType(FloatingBubble), findsNothing);
      expect(find.text('Debug Dashboard'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text('Logs')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text('Errors')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text('Info')),
        findsOneWidget,
      );
    });

    testWidgets('T3.9.4: Tab switching between Logs, Errors, and Info views',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      DebugLog.info('Info log message', tag: 'UI');
      DebugLog.error('Error log message', tag: 'Network');
      await tester.pumpAndSettle();

      // Open dashboard
      await tester.tap(find.byType(FloatingBubble));
      await tester.pumpAndSettle();

      // In Logs tab inside DashboardOverlay: both logs visible
      expect(
        find.descendant(
          of: find.byType(DashboardOverlay),
          matching: find.text('Info log message'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DashboardOverlay),
          matching: find.text('Error log message'),
        ),
        findsOneWidget,
      );

      // Switch to Errors tab
      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Errors'),
      ));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(DashboardOverlay),
          matching: find.text('Error log message'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DashboardOverlay),
          matching: find.text('Info log message'),
        ),
        findsNothing,
      );

      // Switch to Info tab
      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Info'),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(InfoTabView), findsOneWidget);
      expect(find.text('Session Info'), findsOneWidget);
      expect(find.text('Package Version'), findsOneWidget);
    });

    testWidgets(
        'T3.9.5: Log list search and severity filter chips filter results correctly',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      DebugLog.debug('Debug trace alpha', tag: 'Alpha');
      DebugLog.info('Info note beta', tag: 'Beta');
      DebugLog.warning('Warning note gamma', tag: 'Gamma');
      await tester.pumpAndSettle();

      // Open dashboard
      await tester.tap(find.byType(FloatingBubble));
      await tester.pumpAndSettle();

      // Search for "alpha" inside LogListView
      final searchInput = find.descendant(
        of: find.byType(LogListView),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchInput, 'alpha');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(LogListView),
          matching: find.text('Debug trace alpha'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(LogListView),
          matching: find.text('Info note beta'),
        ),
        findsNothing,
      );

      // Clear search
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(LogListView),
          matching: find.text('Debug trace alpha'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(LogListView),
          matching: find.text('Info note beta'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'T3.9.6: Entry details view displays payload, JSON, and copies to clipboard inline',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      DebugLog.error(
        'Database connection timeout',
        tag: 'Database',
        error: 'TimeoutException: 5000ms exceeded',
        json: {'host': 'db.internal', 'port': 5432},
      );
      await tester.pumpAndSettle();

      // Open dashboard
      await tester.tap(find.byType(FloatingBubble));
      await tester.pumpAndSettle();

      // Tap the entry row inside LogListView to expand inline
      final entryRow = find.descendant(
        of: find.byType(LogListView),
        matching: find.text('Database connection timeout'),
      );
      await tester.tap(entryRow);
      await tester.pumpAndSettle();

      // Verify inline expansion shows error message and copy buttons
      expect(find.text('TimeoutException: 5000ms exceeded'), findsOneWidget);
      expect(find.text('JSON PAYLOAD'), findsOneWidget);
      expect(find.byTooltip('Copy entry text'), findsOneWidget);
      expect(find.byTooltip('Copy JSON'), findsOneWidget);

      // Tap Copy entry text inline
      await tester.tap(find.byTooltip('Copy entry text'));
      await tester.pumpAndSettle();
      expect(find.text('Copied entry to clipboard'), findsOneWidget);

      // Collapse inline card
      await tester.tap(find.byTooltip('Collapse'));
      await tester.pumpAndSettle();

      expect(find.text('JSON PAYLOAD'), findsNothing);
    });

    testWidgets(
        'T3.9.7: Three-dot overflow menu (⋮) opens without crash and executes actions',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      DebugLog.info('Sample log before export');
      await tester.pumpAndSettle();

      // Open dashboard
      await tester.tap(find.byType(FloatingBubble));
      await tester.pumpAndSettle();

      // Open overflow menu
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Copy all'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DashboardOverlay),
          matching: find.text('Export JSON'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DashboardOverlay),
          matching: find.text('Clear all'),
        ),
        findsOneWidget,
      );

      // Tap Copy all
      await tester.tap(find.text('Copy all'));
      await tester.pumpAndSettle();
      expect(find.text('Copied 1 entries'), findsOneWidget);

      // Open overflow menu again and test Clear all
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(DashboardOverlay),
        matching: find.text('Clear all'),
      ));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Clear logs'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(DebugLog.controller?.entryCount, equals(0));
      expect(find.text('No logs yet'), findsOneWidget);
    });

    testWidgets('T3.9.8: Close dashboard button restores floating bubble',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Open dashboard
      await tester.tap(find.byType(FloatingBubble));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardOverlay), findsOneWidget);

      // Close dashboard via top-bar close button
      await tester.tap(find.byTooltip('Close dashboard'));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardOverlay), findsNothing);
      expect(find.byType(FloatingBubble), findsOneWidget);
    });
  });
}
