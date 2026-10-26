import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/debug_bubble_controller.dart';
import '../core/debug_log_entry.dart';
import '../core/debug_log_filter.dart';
import '../export/text_exporter.dart';

/// Dashboard actions for copying, exporting, and clearing logs per UI_UX_SPEC.md §6.
class DashboardActions {
  const DashboardActions._();

  /// Maximum characters for clipboard operations (D-26).
  static const int clipboardCapChars = TextExporter.clipboardCapChars;

  /// Copies a single [entry] formatted as plain text to the clipboard.
  static Future<void> copyEntry(
    DebugLogEntry entry, {
    void Function(String message)? onFeedback,
  }) async {
    final text = TextExporter.formatEntry(entry);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      onFeedback?.call('Copied');
    } catch (_) {
      onFeedback?.call('Copy failed');
    }
  }

  /// Copies all entries matching [filter] as plain text to the clipboard.
  ///
  /// Enforces the 500,000 character budget. If older entries are omitted to fit
  /// the budget, reports "Copied N of M entries (oldest omitted)".
  static Future<void> copyAll(
    DebugBubbleController controller, {
    DebugLogFilter filter = const DebugLogFilter(),
    void Function(String message)? onFeedback,
  }) async {
    final totalFiltered = controller.query(filter).length;
    final text = controller.exportText(filter: filter);

    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      onFeedback?.call('Copy failed');
      return;
    }

    final match = RegExp(r'^debug_bubble log export — (\d+) entries')
        .firstMatch(text);
    final included = match != null
        ? (int.tryParse(match.group(1)!) ?? totalFiltered)
        : totalFiltered;

    if (included < totalFiltered) {
      onFeedback?.call(
        'Copied $included of $totalFiltered entries (oldest omitted)',
      );
    } else {
      onFeedback?.call('Copied $included entries');
    }
  }

  /// Exports schema v1 JSON for entries matching [filter].
  ///
  /// Handles clipboard copy (up to 500k chars) and `onExport` callback independently (UI_UX_SPEC.md §6).
  static Future<void> exportJson(
    DebugBubbleController controller, {
    DebugLogFilter filter = const DebugLogFilter(),
    void Function(String message)? onFeedback,
  }) async {
    final jsonText = controller.exportJson(filter: filter);

    var clipboardError = false;
    var clipboardTooLarge = false;

    if (jsonText.length > clipboardCapChars) {
      clipboardTooLarge = true;
    } else {
      try {
        await Clipboard.setData(ClipboardData(text: jsonText));
      } catch (_) {
        clipboardError = true;
      }
    }

    var callbackError = false;
    String? callbackErrorType;

    if (controller.config.onExport != null) {
      try {
        final result = controller.config.onExport!(jsonText);
        if (result is Future) {
          await result;
        }
      } catch (e) {
        callbackError = true;
        callbackErrorType = e.runtimeType.toString();
      }
    }

    if (callbackError) {
      onFeedback?.call('Export callback failed ($callbackErrorType)');
    } else if (clipboardError) {
      onFeedback?.call('Copy failed');
    } else if (clipboardTooLarge) {
      onFeedback?.call(
        'Too large to copy — narrow filters or use the export callback',
      );
    } else {
      onFeedback?.call('Exported JSON');
    }
  }
}

/// Confirmation dialog for destructive log clearing per UI_UX_SPEC.md §6.
///
/// Designed to render inside the dashboard layer without touching the host Navigator.
class ClearConfirmationDialog extends StatelessWidget {
  const ClearConfirmationDialog({
    super.key,
    required this.entryCount,
    required this.onConfirm,
    required this.onCancel,
  });

  /// Total number of stored entries that will be cleared.
  final int entryCount;

  /// Callback when user confirms clearing.
  final VoidCallback onConfirm;

  /// Callback when user cancels.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clear logs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Clear all $entryCount entries? This cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: onConfirm,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
