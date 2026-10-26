import 'dart:async';

import 'package:flutter/material.dart';

import '../core/debug_bubble_controller.dart';
import '../core/debug_log_entry.dart';
import '../core/debug_log_filter.dart';
import '../core/debug_log_level.dart';
import 'actions.dart';
import 'entry_detail.dart';
import 'info_tab.dart';
import 'log_list.dart';
import 'theme.dart';

/// Full-screen dashboard overlay shell per UI_UX_SPEC.md §2.
class DashboardOverlay extends StatefulWidget {
  const DashboardOverlay({super.key, required this.controller});

  /// The active controller providing state and dashboard operations.
  final DebugBubbleController controller;

  @override
  State<DashboardOverlay> createState() => DashboardOverlayState();
}

class DashboardOverlayState extends State<DashboardOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final TabController _tabController;

  DebugLogEntry? _selectedEntry;
  Widget? _activeDialog;
  bool _showOverflowMenu = false;
  String? _feedbackMessage;
  Timer? _feedbackTimer;

  DebugLogFilter _logsFilter = const DebugLogFilter();
  DebugLogFilter _errorsFilter = const DebugLogFilter(
    levels: {DebugLogLevel.error, DebugLogLevel.critical},
  );

  /// Handles back button/gesture per UI_UX_SPEC.md §2.
  ///
  /// Order of precedence:
  /// 1. Dismiss overflow menu
  /// 2. Dismiss modal dialog
  /// 3. Exit detail view back to log list
  /// 4. Return false (allows dashboard to close)
  bool handleBack() {
    if (_showOverflowMenu) {
      setState(() {
        _showOverflowMenu = false;
      });
      return true;
    }
    if (_activeDialog != null) {
      setState(() {
        _activeDialog = null;
      });
      return true;
    }
    if (_selectedEntry != null) {
      setState(() {
        _selectedEntry = null;
      });
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  DebugLogFilter _getActiveFilter() {
    return switch (_tabController.index) {
      0 => _logsFilter,
      1 => _errorsFilter,
      _ => const DebugLogFilter(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = DebugDashboardTheme.isReducedMotion(context);
    final theme = DebugDashboardTheme.resolveTheme(
      context,
      widget.controller.config.theme,
    );

    Widget content = ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Theme(
          data: theme,
          child: Material(
            color: theme.scaffoldBackgroundColor,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (overlayContext) => SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildBody(theme),
                          if (_showOverflowMenu) _buildOverflowMenu(theme),
                          if (_activeDialog != null) _buildDialogLayer(theme),
                          if (_feedbackMessage != null)
                            _buildFeedbackBanner(theme),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (disableAnimations) {
      return Positioned.fill(child: content);
    }

    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: content,
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_selectedEntry != null) {
      return EntryDetailView(
        entry: _selectedEntry!,
        onBack: () => setState(() => _selectedEntry = null),
        theme: widget.controller.config.theme,
      );
    }

    return Column(
      children: [
        _buildTopBar(theme),
        _buildTabBar(theme),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              LogListView(
                controller: widget.controller,
                errorsOnly: false,
                onSelectEntry: (entry) {
                  setState(() {
                    _selectedEntry = entry;
                  });
                },
                onFilterChanged: (filter) {
                  _logsFilter = filter;
                },
              ),
              LogListView(
                controller: widget.controller,
                errorsOnly: true,
                onSelectEntry: (entry) {
                  setState(() {
                    _selectedEntry = entry;
                  });
                },
                onFilterChanged: (filter) {
                  _errorsFilter = filter;
                },
              ),
              InfoTabView(
                controller: widget.controller,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    final controller = widget.controller;
    final entries = controller.entryCount;
    final errors = controller.errorCount;
    final dropped = controller.droppedCount;

    final stats = '$entries ${entries == 1 ? "entry" : "entries"} · '
        '$errors ${errors == 1 ? "error" : "errors"}'
        '${dropped > 0 ? " · $dropped dropped" : ""}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withAlpha(40),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Debug Dashboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  stats,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More actions',
            onPressed: () {
              setState(() {
                _showOverflowMenu = !_showOverflowMenu;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close dashboard',
            onPressed: widget.controller.closeDashboard,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    final errorCount = widget.controller.errorCount;

    return Material(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: [
          const Tab(text: 'Logs'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Errors'),
                if (errorCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      errorCount > 99 ? '99+' : '$errorCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'Info'),
        ],
      ),
    );
  }

  Widget _buildOverflowMenu(ThemeData theme) {
    final screenSize = MediaQuery.sizeOf(context);
    final menuWidth = (screenSize.width - 32.0).clamp(160.0, 240.0);

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showOverflowMenu = false),
            ),
          ),
          Positioned(
            top: 56,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              color: theme.colorScheme.surface,
              child: SizedBox(
                width: menuWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _overflowMenuItem(
                      theme: theme,
                      icon: Icons.copy,
                      label: 'Copy all',
                      onTap: () {
                        setState(() => _showOverflowMenu = false);
                        DashboardActions.copyAll(
                          widget.controller,
                          filter: _getActiveFilter(),
                          onFeedback: _showFeedback,
                        );
                      },
                    ),
                    _overflowMenuItem(
                      theme: theme,
                      icon: Icons.download,
                      label: 'Export JSON',
                      onTap: () {
                        setState(() => _showOverflowMenu = false);
                        DashboardActions.exportJson(
                          widget.controller,
                          filter: _getActiveFilter(),
                          onFeedback: _showFeedback,
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _overflowMenuItem(
                      theme: theme,
                      icon: Icons.delete_outline,
                      label: 'Clear all',
                      isDestructive: true,
                      onTap: () {
                        setState(() {
                          _showOverflowMenu = false;
                          _activeDialog = ClearConfirmationDialog(
                            entryCount: widget.controller.entryCount,
                            onConfirm: () {
                              setState(() => _activeDialog = null);
                              widget.controller.clear();
                              _showFeedback('Logs cleared');
                            },
                            onCancel: () {
                              setState(() => _activeDialog = null);
                            },
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overflowMenuItem({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.textTheme.bodyMedium?.color;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: DebugDashboardTheme.minTouchTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogLayer(ThemeData theme) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ModalBarrier(
              color: Colors.black54,
              dismissible: true,
              onDismiss: () => setState(() => _activeDialog = null),
            ),
          ),
          Center(child: _activeDialog!),
        ],
      ),
    );
  }

  Widget _buildFeedbackBanner(ThemeData theme) {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Semantics(
        liveRegion: true,
        label: _feedbackMessage,
        child: Material(
          elevation: 6,
          color: theme.colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              _feedbackMessage!,
              style: TextStyle(
                color: theme.colorScheme.onInverseSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
