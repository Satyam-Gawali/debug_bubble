import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/ui/dashboard.dart';
import 'package:debug_bubble/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Theme, Accessibility & Responsive Behavior (T3.7, UI_UX_SPEC §7, §8)', () {
    testWidgets('Resolves theme mode correctly (light, dark, system)', (tester) async {
      final darkConfig = const DebugBubbleConfig(
        theme: DebugBubbleTheme(mode: ThemeMode.dark),
      );
      final darkController = DebugBubbleController(config: darkConfig);

      final lightConfig = const DebugBubbleConfig(
        theme: DebugBubbleTheme(mode: ThemeMode.light),
      );
      final lightController = DebugBubbleController(config: lightConfig);

      // Dark theme test
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DashboardOverlay(controller: darkController),
              ],
            ),
          ),
        ),
      );

      expect(
        Theme.of(tester.element(find.text('Debug Dashboard'))).brightness,
        equals(Brightness.dark),
      );

      // Light theme test
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DashboardOverlay(controller: lightController),
              ],
            ),
          ),
        ),
      );

      expect(
        Theme.of(tester.element(find.text('Debug Dashboard'))).brightness,
        equals(Brightness.light),
      );

      darkController.dispose();
      lightController.dispose();
    });

    test('levelColor respects custom levelColor overrides and high contrast defaults', () {
      final customTheme = const DebugBubbleTheme(
        levelColors: {
          DebugLogLevel.critical: Colors.cyan,
        },
      );

      final darkColor = DebugDashboardTheme.levelColor(
        DebugLogLevel.critical,
        brightness: Brightness.dark,
        theme: customTheme,
      );
      expect(darkColor, equals(Colors.cyan));

      final defaultDarkError = DebugDashboardTheme.levelColor(
        DebugLogLevel.error,
        brightness: Brightness.dark,
      );
      expect(defaultDarkError, equals(const Color(0xFFFF453A)));

      final defaultLightError = DebugDashboardTheme.levelColor(
        DebugLogLevel.error,
        brightness: Brightness.light,
      );
      expect(defaultLightError, equals(const Color(0xFFFF3B30)));

      final defaultDarkCritical = DebugDashboardTheme.levelColor(
        DebugLogLevel.critical,
        brightness: Brightness.dark,
      );
      expect(defaultDarkCritical, equals(const Color(0xFFBF5AF2)));

      final defaultLightCritical = DebugDashboardTheme.levelColor(
        DebugLogLevel.critical,
        brightness: Brightness.light,
      );
      expect(defaultLightCritical, equals(const Color(0xFFAF52DE)));
    });

    testWidgets('Reduced motion disables slide and fade animation transitions', (tester) async {
      final controller = DebugBubbleController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Stack(
                children: [
                  DashboardOverlay(controller: controller),
                ],
              ),
            ),
          ),
        ),
      );

      // When animations are disabled, SlideTransition is omitted for dashboard entrance
      expect(
        find.descendant(
          of: find.byType(DashboardOverlay),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );

      controller.dispose();
    });

    testWidgets('Renders properly without overflow under large text scale (2.0x)', (tester) async {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'A long message that should wrap comfortably without overflow under extreme text scale', tag: 'Network', subTag: 'Http');
      controller.log(DebugLogLevel.error, 'Short error');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(400, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Stack(
                children: [
                  DashboardOverlay(controller: controller),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure no flutter overflow errors were generated
      expect(tester.takeException(), isNull);
      expect(find.text('Debug Dashboard'), findsOneWidget);

      // Navigate to Info tab under 2.0x scale
      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Session Info'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Adjusts layout with keyboard insets', (tester) async {
      final controller = DebugBubbleController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                viewInsets: EdgeInsets.only(bottom: 300),
              ),
              child: Stack(
                children: [
                  DashboardOverlay(controller: controller),
                ],
              ),
            ),
          ),
        ),
      );

      final paddingFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.only(bottom: 300),
      );
      expect(paddingFinder, findsOneWidget);

      controller.dispose();
    });
  });
}
