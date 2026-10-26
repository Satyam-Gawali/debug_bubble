import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/debug_bubble_controller.dart';
import '../core/debug_log_entry.dart';
import '../core/debug_log_filter.dart';
import '../core/debug_log_level.dart';
import '../export/text_exporter.dart';
import 'theme.dart';

/// Live log list with debounced search, level chips, bottom console stream,
/// and inline expandable log entries per UI_UX_SPEC.md §3.
class LogListView extends StatefulWidget {
  const LogListView({
    super.key,
    required this.controller,
    required this.errorsOnly,
    this.onSelectEntry,
    this.onOpenFullDetail,
    this.onFilterChanged,
  });

  /// The active controller providing log entries and filters.
  final DebugBubbleController controller;

  /// Whether to pre-filter exclusively to error and critical levels.
  final bool errorsOnly;

  /// Optional callback when an entry is tapped.
  final void Function(DebugLogEntry entry)? onSelectEntry;

  /// Optional callback to open dedicated full-page entry details view.
  final void Function(DebugLogEntry entry)? onOpenFullDetail;

  /// Optional callback invoked when the effective filter changes.
  final ValueChanged<DebugLogFilter>? onFilterChanged;

  @override
  State<LogListView> createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chipScrollController = ScrollController();

  Timer? _debounceTimer;
  Timer? _feedbackTimer;
  String? _feedbackMessage;
  String _searchQuery = '';
  final Set<DebugLogLevel> _selectedLevels = <DebugLogLevel>{};
  bool _hasSearchText = false;
  bool _autoScroll = true;
  bool _showJumpToLatest = false;
  int _lastTotalEntryCount = 0;
  int? _expandedEntryId;

  @override
  void initState() {
    super.initState();
    _lastTotalEntryCount = widget.controller.entryCount;
    _searchController.addListener(_onSearchTextChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onFilterChanged?.call(_buildCurrentFilter());
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _feedbackTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  void _onSearchTextChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (hasText != _hasSearchText) {
      setState(() {
        _hasSearchText = hasText;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Within 60px of the bottom means user is following live logs
    final isAtBottom = (maxScroll - currentScroll) <= 60;
    if (isAtBottom != _autoScroll) {
      setState(() {
        _autoScroll = isAtBottom;
        _showJumpToLatest = !isAtBottom;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      setState(() {
        _autoScroll = true;
        _showJumpToLatest = false;
      });
    }
  }

  void _resetScrollPosition() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
    _autoScroll = false;
    _showJumpToLatest = false;
  }

  DebugLogFilter _buildCurrentFilter() {
    final effectiveLevels = widget.errorsOnly
        ? (_selectedLevels.isEmpty
        ? const <DebugLogLevel>{DebugLogLevel.error, DebugLogLevel.critical}
        : _selectedLevels.where((l) => l.isError).toSet())
        : _selectedLevels;

    return DebugLogFilter(
      levels: effectiveLevels,
      query: _searchQuery,
    );
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = text;
          _resetScrollPosition();
        });
        widget.onFilterChanged?.call(_buildCurrentFilter());
      }
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _resetScrollPosition();
    });
    widget.onFilterChanged?.call(_buildCurrentFilter());
  }

  void _resetFilters() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedLevels.clear();
      _resetScrollPosition();
    });
    widget.onFilterChanged?.call(_buildCurrentFilter());
  }

  void _toggleLevel(DebugLogLevel level) {
    setState(() {
      if (_selectedLevels.contains(level)) {
        _selectedLevels.remove(level);
      } else {
        _selectedLevels.add(level);
      }
      _resetScrollPosition();
    });
    widget.onFilterChanged?.call(_buildCurrentFilter());
  }

  List<DebugLogEntry> _getFilteredEntries() {
    return widget.controller.query(_buildCurrentFilter());
  }

  Color _levelColor(DebugLogLevel level) {
    final theme = widget.controller.config.theme;
    final brightness = Theme.of(context).brightness;
    return DebugDashboardTheme.levelColor(
      level,
      brightness: brightness,
      theme: theme,
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _prettyJson(Object? data) {
    if (data == null) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  Future<void> _copyEntryText(DebugLogEntry entry) async {
    try {
      final text = TextExporter.formatEntry(entry);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      _showFeedback('Copied entry to clipboard');
    } catch (_) {
      if (!mounted) return;
      _showFeedback('Copy failed');
    }
  }

  Future<void> _copyEntryJson(DebugLogEntry entry) async {
    try {
      final jsonStr =
      const JsonEncoder.withIndent('  ').convert(entry.toJson());
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (!mounted) return;
      _showFeedback('Copied JSON to clipboard');
    } catch (_) {
      if (!mounted) return;
      _showFeedback('Copy failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final entries = _getFilteredEntries();
        final totalCount = widget.controller.entryCount;
        final droppedCount = widget.controller.droppedCount;
        final hasActiveFilters = _searchQuery.isNotEmpty || _selectedLevels.isNotEmpty;

        final isNewEntry = totalCount > _lastTotalEntryCount;
        if (isNewEntry) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _lastTotalEntryCount = totalCount;

            // Stick to latest logs at the bottom if auto-scroll is active
            if (_autoScroll && _scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchBar(),
                _buildLevelChips(hasActiveFilters),
                _buildCountsLine(entries.length, totalCount, droppedCount),
                if (_feedbackMessage != null) _buildFeedbackBanner(),
                const Divider(height: 1),
                Expanded(
                  child: entries.isEmpty
                      ? _buildEmptyState(totalCount, hasActiveFilters)
                      : ListView.builder(
                    controller: _scrollController,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _buildEntryRow(entry);
                    },
                  ),
                ),
              ],
            ),
            if (_showJumpToLatest)
              Positioned(
                bottom: 16,
                right: 16,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  label: const Text('Jump to latest'),
                  onPressed: _scrollToBottom,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFeedbackBanner() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.primaryContainer,
      child: Text(
        _feedbackMessage!,
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.errorsOnly ? 'Search errors…' : 'Search logs…',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _hasSearchText
              ? IconButton(
            icon: const Icon(Icons.clear, size: 18),
            tooltip: 'Clear search',
            onPressed: _clearSearch,
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withAlpha(50),
            ),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildLevelChips(bool hasActiveFilters) {
    final availableLevels = widget.errorsOnly
        ? const <DebugLogLevel>[DebugLogLevel.error, DebugLogLevel.critical]
        : DebugLogLevel.values;

    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent &&
            _chipScrollController.hasClients) {
          final delta = pointerSignal.scrollDelta.dy != 0
              ? pointerSignal.scrollDelta.dy
              : pointerSignal.scrollDelta.dx;
          final target = (_chipScrollController.offset + delta).clamp(
            0.0,
            _chipScrollController.position.maxScrollExtent,
          );
          _chipScrollController.jumpTo(target);
        }
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: SingleChildScrollView(
          controller: _chipScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
        children: [
          ...availableLevels.map((level) {
            final isSelected = _selectedLevels.contains(level);
            final color = _levelColor(level);

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                selected: isSelected,
                avatar: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(
                  level.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onSelected: (_) => _toggleLevel(level),
              ),
            );
          }),
          if (hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: TextButton.icon(
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Reset filters', style: TextStyle(fontSize: 11)),
                onPressed: _resetFilters,
              ),
            ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildCountsLine(int filteredCount, int totalCount, int droppedCount) {
    final theme = Theme.of(context);
    final countText = 'Showing $filteredCount of $totalCount'
        '${droppedCount > 0 ? " · $droppedCount older entries dropped" : ""}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Text(
        countText,
        style: TextStyle(
          fontSize: 11,
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
  }

  Widget _buildEmptyState(int totalCount, bool hasActiveFilters) {
    final theme = Theme.of(context);

    if (totalCount == 0 ||
        (widget.errorsOnly && widget.controller.errorCount == 0)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.errorsOnly
                  ? Icons.check_circle_outline
                  : Icons.inbox_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withAlpha(80),
            ),
            const SizedBox(height: 8),
            Text(
              widget.errorsOnly ? 'No errors recorded' : 'No logs yet',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 40,
            color: theme.colorScheme.onSurface.withAlpha(80),
          ),
          const SizedBox(height: 8),
          const Text(
            'No matches for current filters',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _resetFilters,
            child: const Text('Reset filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(DebugLogEntry entry) {
    final theme = Theme.of(context);
    final color = _levelColor(entry.level);
    final formattedTime = _formatTime(entry.timestamp.toLocal());
    final isExpanded = _expandedEntryId == entry.id;

    return Builder(
      builder: (rowContext) {
        return InkWell(
          onTap: () {
            final willExpand = !isExpanded;
            setState(() {
              _expandedEntryId = willExpand ? entry.id : null;
              // User actively inspected an entry: prevent background live logs
              // from auto-scrolling away from the inspected entry.
              if (willExpand) {
                _autoScroll = false;
                _showJumpToLatest = true;
              }
            });
            widget.onSelectEntry?.call(entry);

            if (willExpand) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !rowContext.mounted || _expandedEntryId != entry.id) return;
                Scrollable.ensureVisible(
                  rowContext,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                );
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isExpanded ? color.withAlpha(12) : null,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withAlpha(30),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Level badge
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withAlpha(80)),
                      ),
                      child: Text(
                        entry.level.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Timestamp
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    // Tag / subTag chip
                    if (entry.tag != null || entry.subTag != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          entry.subTag != null
                              ? '${entry.tag ?? ""}/${entry.subTag}'
                              : entry.tag!,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (entry.error != null) ...[
                      const Icon(Icons.error, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                    ],
                    if (entry.truncated) ...[
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(30),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'TRUNCATED',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '#${entry.id}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: theme.textTheme.bodySmall?.color?.withAlpha(150),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.message,
                  maxLines: isExpanded ? null : 2,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: isExpanded
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildExpandedDetails(entry, theme, color),
                    ],
                  )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandedDetails(
      DebugLogEntry entry,
      ThemeData theme,
      Color levelColor,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error details section
        if (entry.error != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4, bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withAlpha(50)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      entry.error!.type,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SelectableText(
                  entry.error!.message,
                  style: const TextStyle(fontSize: 12),
                ),
                if (entry.stackTrace != null) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'STACK TRACE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.black26
                          : Colors.black.withAlpha(10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          entry.stackTrace!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Metadata section
        if (entry.metadata != null && entry.metadata!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'METADATA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                ...entry.metadata!.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.key}: ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          '${e.value}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],

        // JSON section
        if (entry.json != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JSON PAYLOAD',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.black26
                        : Colors.black.withAlpha(10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        _prettyJson(entry.json),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Quick action buttons bar
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 16),
              tooltip: 'Copy entry text',
              visualDensity: VisualDensity.compact,
              onPressed: () => _copyEntryText(entry),
            ),
            if (entry.json != null) ...[
              IconButton(
                icon: const Icon(Icons.code_outlined, size: 16),
                tooltip: 'Copy JSON',
                visualDensity: VisualDensity.compact,
                onPressed: () => _copyEntryJson(entry),
              ),
            ],
            if (widget.onOpenFullDetail != null) ...[
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 16),
                tooltip: 'Open full page',
                visualDensity: VisualDensity.compact,
                onPressed: () => widget.onOpenFullDetail!(entry),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.expand_less, size: 18),
              tooltip: 'Collapse',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _expandedEntryId = null;
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}