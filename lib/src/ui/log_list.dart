import 'dart:async';

import 'package:flutter/material.dart';

import '../core/debug_bubble_controller.dart';
import '../core/debug_log_entry.dart';
import '../core/debug_log_filter.dart';
import '../core/debug_log_level.dart';
import 'theme.dart';

/// Live log list with debounced search, level chips, and auto-scroll per UI_UX_SPEC.md §3.
class LogListView extends StatefulWidget {
  const LogListView({
    super.key,
    required this.controller,
    required this.errorsOnly,
    required this.onSelectEntry,
    this.onFilterChanged,
  });

  /// The active controller providing log entries and filters.
  final DebugBubbleController controller;

  /// Whether to pre-filter exclusively to error and critical levels.
  final bool errorsOnly;

  /// Callback when an entry is tapped to view details.
  final void Function(DebugLogEntry entry) onSelectEntry;

  /// Optional callback invoked when the effective filter changes.
  final ValueChanged<DebugLogFilter>? onFilterChanged;

  @override
  State<LogListView> createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounceTimer;
  String _searchQuery = '';
  final Set<DebugLogLevel> _selectedLevels = <DebugLogLevel>{};
  bool _hasSearchText = false;
  bool _autoScroll = true;
  bool _showJumpToLatest = false;
  int _lastTotalEntryCount = 0;

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
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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

  void _resetScrollToTop() {
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
          _resetScrollToTop();
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
      _resetScrollToTop();
    });
    widget.onFilterChanged?.call(_buildCurrentFilter());
  }

  void _resetFilters() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedLevels.clear();
      _resetScrollToTop();
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
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final totalCount = widget.controller.entryCount;
        final droppedCount = widget.controller.droppedCount;
        final isNewEntry = totalCount > _lastTotalEntryCount;
        _lastTotalEntryCount = totalCount;

        final entries = _getFilteredEntries();
        final hasActiveFilters =
            _searchQuery.trim().isNotEmpty || _selectedLevels.isNotEmpty;

        // Auto-scroll if enabled and genuinely new entries arrive
        if (_autoScroll && isNewEntry && _scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_autoScroll && _scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
            }
          });
        }

        return Stack(
          children: [
            Column(
              children: [
                _buildSearchBar(),
                _buildLevelChips(hasActiveFilters),
                _buildCountsLine(entries.length, totalCount, droppedCount),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildLevelChips(bool hasActiveFilters) {
    final availableLevels = widget.errorsOnly
        ? const <DebugLogLevel>[DebugLogLevel.error, DebugLogLevel.critical]
        : DebugLogLevel.values;

    return SingleChildScrollView(
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
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedLevels.add(level);
                    } else {
                      _selectedLevels.remove(level);
                    }
                    _resetScrollToTop();
                  });
                  widget.onFilterChanged?.call(_buildCurrentFilter());
                },
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
          if (hasActiveFilters)
            ActionChip(
              avatar: const Icon(Icons.filter_alt_off, size: 14),
              label: const Text('Reset filters', style: TextStyle(fontSize: 11)),
              onPressed: _resetFilters,
              visualDensity: VisualDensity.compact,
            ),
        ],
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

    if (totalCount == 0 || (widget.errorsOnly && widget.controller.errorCount == 0)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.errorsOnly ? Icons.check_circle_outline : Icons.inbox_outlined,
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

    return InkWell(
      onTap: () => widget.onSelectEntry(entry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
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
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
