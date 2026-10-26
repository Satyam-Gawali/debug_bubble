import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/ui/log_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogListView Widget Tests (T3.4, UI_UX_SPEC §3)', () {
    testWidgets('Renders empty state when controller has no entries', (tester) async {
      final controller = DebugBubbleController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogListView(
              controller: controller,
              errorsOnly: false,
              onSelectEntry: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('No logs yet'), findsOneWidget);
      expect(find.text('Showing 0 of 0'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Renders log entries with badges, tags, and timestamps', (tester) async {
      final controller = DebugBubbleController();
      controller.log(
        DebugLogLevel.info,
        'Application started',
        tag: 'App',
        subTag: 'Init',
      );
      controller.log(
        DebugLogLevel.warning,
        'Cache low memory',
        tag: 'Storage',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogListView(
              controller: controller,
              errorsOnly: false,
              onSelectEntry: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Application started'), findsOneWidget);
      expect(find.text('Cache low memory'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('INFO'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('WARNING'),
        ),
        findsOneWidget,
      );
      expect(find.text('App/Init'), findsOneWidget);
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('Showing 2 of 2'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Errors tab filters exclusively to error and critical levels', (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Normal info');
      controller.log(DebugLogLevel.warning, 'Normal warning');
      controller.log(DebugLogLevel.error, 'Network error', tag: 'Net');
      controller.log(DebugLogLevel.critical, 'Fatal crash', tag: 'Core');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogListView(
              controller: controller,
              errorsOnly: true,
              onSelectEntry: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Normal info'), findsNothing);
      expect(find.text('Normal warning'), findsNothing);
      expect(find.text('Network error'), findsOneWidget);
      expect(find.text('Fatal crash'), findsOneWidget);
      expect(find.text('Showing 2 of 4'), findsOneWidget);

      // Errors view offers only ERROR and CRITICAL chips
      expect(find.text('ERROR'), findsWidgets);
      expect(find.text('CRITICAL'), findsWidgets);
      expect(find.text('DEBUG'), findsNothing);
      expect(find.text('INFO'), findsNothing);

      controller.dispose();
    });

    testWidgets('Search query filters with 250 ms debounce', (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'User signed in', tag: 'Auth');
      controller.log(DebugLogLevel.info, 'Profile data loaded', tag: 'Profile');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogListView(
              controller: controller,
              errorsOnly: false,
              onSelectEntry: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('User signed in'), findsOneWidget);
      expect(find.text('Profile data loaded'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'signed');
      // Before debounce time expires, old list remains
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Profile data loaded'), findsOneWidget);

      // After 250 ms debounce completes
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('User signed in'), findsOneWidget);
      expect(find.text('Profile data loaded'), findsNothing);
      expect(find.text('Showing 1 of 2'), findsOneWidget);

      // Clear search button appears and restores list
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Profile data loaded'), findsOneWidget);
      expect(find.text('Showing 2 of 2'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Search clear icon appears immediately on typing without waiting for debounce', (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Sample text');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogListView(
              controller: controller,
              errorsOnly: false,
              onSelectEntry: (_) {},
            ),
          ),
        ),
      );

      // Initially empty: clear icon is not present
      expect(find.byTooltip('Clear search'), findsNothing);

      // Type 1 character
      await tester.enterText(find.byType(TextField), 's');
      await tester.pump(); // Immediate frame, no duration

      // Clear icon must appear immediately without waiting 250ms
      expect(find.byTooltip('Clear search'), findsOneWidget);

      // Clear text
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsNothing);

      controller.dispose();
    });

    testWidgets('Filter and search changes reset scroll position to top', (tester) async {
      final controller = DebugBubbleController();
      for (var i = 0; i < 40; i++) {
        controller.log(
          i % 2 == 0 ? DebugLogLevel.info : DebugLogLevel.warning,
          'Log item $i',
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogListView(
              controller: controller,
              errorsOnly: false,
              onSelectEntry: (_) {},
            ),
          ),
        ),
      );

      // Scroll down
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final scrollable = tester.state(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      ) as ScrollableState;
      expect(scrollable.position.pixels > 0, isTrue);

      // Tap WARNING chip to change filter
      await tester.tap(find.widgetWithText(FilterChip, 'WARNING'));
      await tester.pumpAndSettle();

      // Scroll position must be reset to 0.0
      expect(scrollable.position.pixels, equals(0.0));

      controller.dispose();
    });

    testWidgets('Exact severity chip filtering and reset filters action', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.debug, 'Debug trace');
      controller.log(DebugLogLevel.info, 'Info event');
      controller.log(DebugLogLevel.warning, 'Warning event');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogListView(
              controller: controller,
              errorsOnly: false,
              onSelectEntry: (_) {},
            ),
          ),
        ),
      );

      // Tap WARNING chip
      await tester.tap(find.widgetWithText(FilterChip, 'WARNING'));
      await tester.pumpAndSettle();

      expect(find.text('Warning event'), findsOneWidget);
      expect(find.text('Debug trace'), findsNothing);
      expect(find.text('Info event'), findsNothing);
      expect(find.text('Showing 1 of 3'), findsOneWidget);

      // Reset filters button appears
      expect(find.text('Reset filters'), findsOneWidget);
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();

      expect(find.text('Debug trace'), findsOneWidget);
      expect(find.text('Info event'), findsOneWidget);
      expect(find.text('Warning event'), findsOneWidget);
      expect(find.text('Showing 3 of 3'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Shows empty state with reset button when filter matches nothing', (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'Sample item');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogListView(
              controller: controller,
              errorsOnly: false,
              onSelectEntry: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'nonexistent_query');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No matches for current filters'), findsOneWidget);
      expect(find.text('Showing 0 of 1'), findsOneWidget);

      // Tap Reset filters button in empty state
      await tester.tap(find.widgetWithText(FilledButton, 'Reset filters'));
      await tester.pumpAndSettle();

      expect(find.text('Sample item'), findsOneWidget);
      expect(find.text('Showing 1 of 1'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Tapping entry row invokes onSelectEntry callback', (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.error, 'Clickable error', tag: 'Test');
      DebugLogEntry? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogListView(
              controller: controller,
              errorsOnly: false,
              onSelectEntry: (entry) => selected = entry,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Clickable error'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected?.message, equals('Clickable error'));
      expect(selected?.tag, equals('Test'));

      controller.dispose();
    });
  });
}
