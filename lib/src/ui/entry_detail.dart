import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/debug_bubble_theme.dart';
import '../core/debug_log_entry.dart';
import '../core/debug_log_level.dart';
import 'theme.dart';
import '../export/text_exporter.dart';

/// Detail view for inspecting a single [DebugLogEntry] per UI_UX_SPEC.md §4.
class EntryDetailView extends StatefulWidget {
  const EntryDetailView({
    super.key,
    required this.entry,
    required this.onBack,
    this.theme,
  });

  /// The entry to inspect.
  final DebugLogEntry entry;

  /// Callback to return to the list view.
  final VoidCallback onBack;

  /// Optional theme configuration.
  final DebugBubbleTheme? theme;

  @override
  State<EntryDetailView> createState() => _EntryDetailViewState();
}

class _EntryDetailViewState extends State<EntryDetailView> {
  String? _feedbackMessage;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _showFeedback(String message) {
    _feedbackTimer?.cancel();
    setState(() => _feedbackMessage = message);
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _feedbackMessage = null);
    });
  }

  Future<void> _copyPlainText() async {
    try {
      final text = TextExporter.formatEntry(widget.entry);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      _showFeedback('Copied entry to clipboard');
    } catch (_) {
      if (!mounted) return;
      _showFeedback('Copy failed');
    }
  }

  Future<void> _copyJson() async {
    try {
      final jsonStr = const JsonEncoder.withIndent('  ')
          .convert(widget.entry.toJson());
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (!mounted) return;
      _showFeedback('Copied JSON to clipboard');
    } catch (_) {
      if (!mounted) return;
      _showFeedback('Copy failed');
    }
  }

  Color _levelColor(DebugLogLevel level, Brightness brightness) {
    return DebugDashboardTheme.levelColor(
      level,
      brightness: brightness,
      theme: widget.theme,
    );
  }

  String _prettyJson(Object? data) {
    if (data == null) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final levelColor = _levelColor(entry.level, theme.brightness);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to list',
          onPressed: widget.onBack,
        ),
        title: Text('Entry #${entry.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy entry text',
            onPressed: _copyPlainText,
          ),
          IconButton(
            icon: const Icon(Icons.code_outlined),
            tooltip: 'Copy JSON',
            onPressed: _copyJson,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_feedbackMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: theme.colorScheme.primaryContainer,
              child: Text(
                _feedbackMessage!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header badge card
                Card(
                  elevation: 0,
                  color: levelColor.withAlpha(25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: levelColor.withAlpha(80)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: levelColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.level.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (entry.isUncaught)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade900,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'UNCAUGHT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              '#${entry.id}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (entry.tag != null || entry.subTag != null) ...[
                          Row(
                            children: [
                              const Text(
                                'Tag: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                entry.subTag != null
                                    ? '${entry.tag ?? ""}/${entry.subTag}'
                                    : entry.tag!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          'UTC: ${entry.timestamp.toIso8601String()}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'Local: ${entry.timestamp.toLocal()}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        if (entry.truncated) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: const [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Some content was truncated due to entry size limits.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Message section
                _buildSection(
                  title: 'Message',
                  child: SelectableText(
                    entry.message,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),

                // Error section
                if (entry.error != null) ...[
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Error Details',
                    color: Colors.red.withAlpha(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.error!.type.isNotEmpty) ...[
                          SelectableText(
                            'Type: ${entry.error!.type}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        SelectableText(
                          entry.error!.message,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],

                // Stack trace section
                if (entry.stackTrace != null &&
                    entry.stackTrace!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Stack Trace',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          entry.stackTrace!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Metadata section
                if (entry.metadata != null && entry.metadata!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Metadata',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          _prettyJson(entry.metadata),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // JSON payload section
                if (entry.json != null) ...[
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'JSON Payload',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          _prettyJson(entry.json),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
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
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: color ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
