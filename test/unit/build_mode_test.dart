import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/utils/build_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    BuildMode.reset();
  });

  group('Build Mode and Activity Policy (D-04, ARCHITECTURE §7)', () {
    test('Active in debug mode when enabled is true', () {
      BuildMode.releaseOverride = false;
      final controller = DebugBubbleController();
      expect(controller.isActive, isTrue);
    });

    test('Inactive when config.enabled is false', () {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(enabled: false),
      );
      expect(controller.isActive, isFalse);
    });

    test('Inert in release mode even if config.enabled is true (D-04)', () {
      BuildMode.releaseOverride = true;
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(enabled: true),
      );
      expect(controller.isActive, isFalse);
    });

    test('Inactive controller safely ignores operations', () {
      BuildMode.releaseOverride = true;
      final controller = DebugBubbleController();

      expect(() => controller.log(DebugLogLevel.info, 'msg'), returnsNormally);
      expect(() => controller.clear(), returnsNormally);
      expect(() => controller.openDashboard(), returnsNormally);
      expect(controller.isDashboardOpen, isFalse);
      expect(controller.query(const DebugLogFilter()), isEmpty);
      expect(controller.exportJson(), isEmpty);
      expect(controller.exportText(), isEmpty);
    });
  });
}
