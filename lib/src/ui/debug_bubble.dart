import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/debug_bubble_controller.dart';
import '../core/debug_log.dart';
import 'bubble.dart';
import 'dashboard.dart';

/// Floating debug bubble widget providing in-app access to the debug dashboard.
///
/// Places the debugging bubble above the application content in a [Stack].
///
/// When [controller] is omitted, [DebugBubble] automatically binds to the default
/// controller initialized by [DebugLog.init], rebinding whenever the default
/// is replaced, created, or disposed (L-6).
class DebugBubble extends StatefulWidget {
  const DebugBubble({super.key, required this.child, this.controller});

  /// Host app widget subtree.
  final Widget child;

  /// Explicit controller to bind with; if null, follows the default controller.
  final DebugBubbleController? controller;

  @override
  State<DebugBubble> createState() => _DebugBubbleState();
}

class _DebugBubbleState extends State<DebugBubble> with WidgetsBindingObserver {
  final GlobalKey<DashboardOverlayState> _dashboardKey =
      GlobalKey<DashboardOverlayState>();

  DebugBubbleController? get _effectiveController =>
      widget.controller ?? DebugLog.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller == null) {
      DebugLog.defaultControllerNotifier.addListener(
        _onDefaultControllerChanged,
      );
    }
  }

  @override
  void didUpdateWidget(DebugBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        DebugLog.defaultControllerNotifier.removeListener(
          _onDefaultControllerChanged,
        );
      }
      if (widget.controller == null) {
        DebugLog.defaultControllerNotifier.addListener(
          _onDefaultControllerChanged,
        );
      }
      _safeRebuild();
    }
  }

  void _onDefaultControllerChanged() {
    _safeRebuild();
  }

  void _safeRebuild() {
    if (!mounted) return;
    try {
      final binding = WidgetsBinding.instance;
      final phase = binding.schedulerPhase;
      final inFrame =
          phase == SchedulerPhase.persistentCallbacks ||
          phase == SchedulerPhase.midFrameMicrotasks;
      if (inFrame) {
        binding.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        return;
      }
    } catch (_) {}
    setState(() {});
  }

  @override
  Future<bool> didPopRoute() async {
    final controller = _effectiveController;
    if (controller != null &&
        controller.isActive &&
        controller.isDashboardOpen) {
      if (_dashboardKey.currentState?.handleBack() == true) {
        return true; // Closed detail view
      }
      controller.closeDashboard();
      return true; // Intercept back to close dashboard without popping host route (D-27)
    }
    return false; // Allow host app to handle back route normally
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) {
      DebugLog.defaultControllerNotifier.removeListener(
        _onDefaultControllerChanged,
      );
    }
    // Widgets never dispose controllers (L-7)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _effectiveController;

    // If controller is absent, disposed, or inactive (e.g. release mode), render only child (L-6, L-8, D-04)
    if (controller == null || !controller.isActive) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        _DebugBubbleOverlayHost(
          controller: controller,
          dashboardKey: _dashboardKey,
        ),
      ],
    );
  }
}

/// Isolated host for the floating bubble and dashboard overlay.
///
/// Reacts to controller changes (opening/closing dashboard and active state)
/// without rebuilding the host application subtree in [DebugBubble].
class _DebugBubbleOverlayHost extends StatelessWidget {
  const _DebugBubbleOverlayHost({
    required this.controller,
    required this.dashboardKey,
  });

  final DebugBubbleController controller;
  final GlobalKey<DashboardOverlayState> dashboardKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isActive) {
          return const SizedBox.shrink();
        }
        if (controller.isDashboardOpen) {
          return DashboardOverlay(key: dashboardKey, controller: controller);
        }
        return FloatingBubble(controller: controller);
      },
    );
  }
}
