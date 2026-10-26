import 'package:flutter/material.dart';

import '../collectors/error_hook_registry.dart';
import '../core/debug_bubble_controller.dart';
import '../core/debug_log_level.dart';
import '../utils/build_mode.dart';
import '../version.dart';
import 'theme.dart';

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

        final hookStatus = ErrorHookRegistry.instance
            .statusFor(controller)
            .label;

        final bufferRatio = config.maxEntries > 0
            ? (controller.entryCount / config.maxEntries).clamp(0.0, 1.0)
            : 0.0;
        final bufferPct = (bufferRatio * 100).toStringAsFixed(0);

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // Top KPI Banner
            _buildTopBanner(theme, buildModeStr, bufferPct),
            const SizedBox(height: 8),

            // Card 1: Session Info
            _buildCard(
              theme,
              title: 'Session Info',
              icon: Icons.devices_outlined,
              rows: [
                _RowData('Package Version', debugBubbleVersion),
                _RowData('Build Mode', buildModeStr),
                _RowData(
                  'Active Status',
                  controller.isActive ? 'Active' : 'Inactive',
                  statusKind: controller.isActive
                      ? _StatusKind.active
                      : _StatusKind.inactive,
                ),
              ],
            ),

            // Card 2: Store & Counts
            _buildCard(
              theme,
              title: 'Store & Counts',
              icon: Icons.analytics_outlined,
              extraWidget: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Store Capacity',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        Text(
                          '$bufferPct% used',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: bufferRatio > 0.85
                                ? Colors.orange
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: bufferRatio,
                        minHeight: 5,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          bufferRatio > 0.85
                              ? Colors.orange
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              rows: [
                _RowData('Total Stored', '${controller.entryCount}'),
                _RowData('Older Dropped', '${controller.droppedCount}'),
                for (final level in DebugLogLevel.values)
                  _RowData(
                    '${level.name.toUpperCase()} Count',
                    '${levelCounts[level]}',
                    levelColor: DebugDashboardTheme.levelColor(
                      level,
                      brightness: theme.brightness,
                      theme: config.theme,
                    ),
                  ),
              ],
            ),

            // Card 3: Configured Limits
            _buildCard(
              theme,
              title: 'Configured Limits',
              icon: Icons.tune_rounded,
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

            // Card 4: Features & Error Hooks
            _buildCard(
              theme,
              title: 'Features & Error Hooks',
              icon: Icons.shield_outlined,
              rows: [
                _RowData(
                  'Console Output',
                  config.consoleOutput ? 'Enabled' : 'Disabled',
                  statusKind: config.consoleOutput
                      ? _StatusKind.enabled
                      : _StatusKind.disabled,
                ),
                _RowData(
                  'Uncaught Error Hook',
                  hookStatus,
                  statusKind: hookStatus == 'active'
                      ? _StatusKind.active
                      : (hookStatus == 'off'
                            ? _StatusKind.disabled
                            : _StatusKind.warning),
                ),
                _RowData(
                  'Redaction',
                  config.redaction.enabled ? 'Enabled' : 'Disabled',
                  statusKind: config.redaction.enabled
                      ? _StatusKind.enabled
                      : _StatusKind.disabled,
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

  Widget _buildTopBanner(
    ThemeData theme,
    String buildModeStr,
    String bufferPct,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final bannerBg = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.primaryContainer.withAlpha(70);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.dashboard_customize_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toolkit Diagnostics',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Runtime session metrics & active engine configurations',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required List<_RowData> rows,
    Widget? extraWidget,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withAlpha(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ?extraWidget,
            const SizedBox(height: 4),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (row.levelColor != null)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: row.levelColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              row.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildRowValue(theme, row),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowValue(ThemeData theme, _RowData row) {
    if (row.statusKind != null) {
      Color bg;
      Color fg;

      switch (row.statusKind!) {
        case _StatusKind.active:
        case _StatusKind.enabled:
          bg = Colors.green.withAlpha(25);
          fg = Colors.green.shade700;
          break;
        case _StatusKind.inactive:
        case _StatusKind.disabled:
          bg = theme.colorScheme.surfaceContainerHighest;
          fg = theme.textTheme.bodySmall?.color ?? Colors.grey;
          break;
        case _StatusKind.warning:
          bg = Colors.orange.withAlpha(30);
          fg = Colors.orange.shade800;
          break;
      }

      if (theme.brightness == Brightness.dark) {
        if (row.statusKind == _StatusKind.active ||
            row.statusKind == _StatusKind.enabled) {
          fg = Colors.greenAccent.shade400;
        } else if (row.statusKind == _StatusKind.warning) {
          fg = Colors.amber.shade300;
        }
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          row.value,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
      );
    }

    if (row.levelColor != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: row.levelColor!.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          row.value,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: row.levelColor,
          ),
        ),
      );
    }

    return Text(
      row.value,
      textAlign: TextAlign.end,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    );
  }
}

enum _StatusKind { active, inactive, enabled, disabled, warning }

class _RowData {
  const _RowData(this.label, this.value, {this.levelColor, this.statusKind});

  final String label;
  final String value;
  final Color? levelColor;
  final _StatusKind? statusKind;
}
