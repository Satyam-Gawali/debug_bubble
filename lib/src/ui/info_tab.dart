import 'package:flutter/material.dart';

import '../collectors/error_hook_registry.dart';
import '../core/debug_bubble_controller.dart';
import '../core/debug_log_level.dart';
import '../utils/build_mode.dart';
import '../version.dart';

/// Read-only session snapshot per DATA_MODELS.md §10 and UI_UX_SPEC.md §5.
///
/// Contains no log content and no pattern text.
class InfoTabView extends StatelessWidget {
  const InfoTabView({super.key, required this.controller});

  /// The active controller whose session configuration and counts are displayed.
  final DebugBubbleController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final config = controller.config;
        final entries = controller.entries;

        // Compute per-level counts from current store
        final levelCounts = <DebugLogLevel, int>{
          for (final level in DebugLogLevel.values) level: 0,
        };
        for (final entry in entries) {
          levelCounts[entry.level] = (levelCounts[entry.level] ?? 0) + 1;
        }

        final buildModeStr = BuildMode.isRelease
            ? 'release'
            : (BuildMode.isProfile ? 'profile' : 'debug');

        final hookStatus =
            ErrorHookRegistry.instance.statusFor(controller).label;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildCard(
              theme,
              title: 'Session Info',
              rows: [
                _RowData('Package Version', debugBubbleVersion),
                _RowData('Build Mode', buildModeStr),
                _RowData(
                  'Active Status',
                  controller.isActive ? 'Active' : 'Inactive',
                ),
              ],
            ),
            _buildCard(
              theme,
              title: 'Store & Counts',
              rows: [
                _RowData('Total Stored', '${controller.entryCount}'),
                _RowData('Older Dropped', '${controller.droppedCount}'),
                for (final level in DebugLogLevel.values)
                  _RowData(
                    '${level.name.toUpperCase()} Count',
                    '${levelCounts[level]}',
                  ),
              ],
            ),
            _buildCard(
              theme,
              title: 'Configured Limits',
              rows: [
                _RowData('Max Entries', '${config.maxEntries}'),
                _RowData('Max Entry Characters', '${config.maxEntryChars}'),
                _RowData('Max Message Length', '${config.maxMessageLength}'),
                _RowData(
                  'Max Stack Trace Length',
                  '${config.maxStackTraceLength}',
                ),
                _RowData('Max Payload Length', '${config.maxPayloadLength}'),
              ],
            ),
            _buildCard(
              theme,
              title: 'Features & Error Hooks',
              rows: [
                _RowData(
                  'Console Output',
                  config.consoleOutput ? 'Enabled' : 'Disabled',
                ),
                _RowData('Uncaught Error Hook', hookStatus),
                _RowData(
                  'Redaction',
                  config.redaction.enabled ? 'Enabled' : 'Disabled',
                ),
                _RowData(
                  'Redaction Value Patterns',
                  '${config.redaction.valuePatterns.length}',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(
    ThemeData theme, {
    required String title,
    required List<_RowData> rows,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        row.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RowData {
  const _RowData(this.label, this.value);
  final String label;
  final String value;
}
