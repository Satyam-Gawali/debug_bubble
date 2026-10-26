import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter/material.dart';

void main() {
  // Initialize toolkit before running the application.
  // Logs emitted before init are silently dropped (L-4, D-24).
  DebugLog.init(const DebugBubbleConfig(captureUncaughtErrors: true));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'debug_bubble Example',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      builder: (context, child) =>
          DebugBubble(child: child ?? const SizedBox.shrink()),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DebugBubbleController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = DebugLog.controller;
    _controller?.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _showExportDialog(BuildContext context, bool isJson) {
    final controller = _controller;
    if (controller == null) return;

    final content = isJson ? controller.exportJson() : controller.exportText();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isJson ? 'Exported JSON' : 'Exported Text'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              content.isEmpty ? '(No logs stored)' : content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final totalEntries = controller?.entryCount ?? 0;
    final errorCount = controller?.errorCount ?? 0;
    final droppedCount = controller?.droppedCount ?? 0;
    final isActive = controller?.isActive ?? false;
    final isDashboardOpen = controller?.isDashboardOpen ?? false;
    final recentEntries = controller?.entries.reversed.take(5).toList() ??
        const <DebugLogEntry>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('debug_bubble Example'),
        actions: [
          IconButton(
            tooltip: 'Clear logs',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => DebugLog.controller?.clear(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In-App Debugging & Logging Demo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'This application demonstrates the debug_bubble package, '
                      'showcasing structured logging across 6 severity levels, '
                      'severity-colored console output in your IDE debug console, '
                      'payload redaction, ring buffer storage, and uncaught error capture.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Status & Metrics',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Total Logs',
                    value: '$totalEntries',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: 'Errors',
                    value: '$errorCount',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: 'Dropped',
                    value: '$droppedCount',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    title: 'Status',
                    value: isActive ? 'Active' : 'Inactive',
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Emit Log by Severity Level',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.bug_report, size: 16, color: Colors.grey),
                  label: const Text('Debug'),
                  onPressed: () {
                    DebugLog.debug('Verbose debug event emitted', tag: 'UI');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.info, size: 16, color: Colors.blue),
                  label: const Text('Info'),
                  onPressed: () {
                    DebugLog.info('Application state changed', tag: 'App');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  label: const Text('Success'),
                  onPressed: () {
                    DebugLog.success('Operation completed successfully', tag: 'Sync');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.warning, size: 16, color: Colors.amber),
                  label: const Text('Warning'),
                  onPressed: () {
                    DebugLog.warning('Cache limit reaching threshold', tag: 'Storage');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.error, size: 16, color: Colors.red),
                  label: const Text('Error'),
                  onPressed: () {
                    DebugLog.error(
                      'Failed to load user profile: 404',
                      tag: 'Network',
                      error: 'HttpException: 404 Not Found',
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.dangerous, size: 16, color: Color(0xFFAF52DE)),
                  label: const Text('Critical'),
                  onPressed: () {
                    DebugLog.critical('Critical unrecoverable failure encountered', tag: 'Core');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Advanced Logging Actions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.data_object, size: 18),
                  label: const Text('Log with Metadata & JSON'),
                  onPressed: () {
                    DebugLog.info(
                      'User performed search query',
                      tag: 'Search',
                      metadata: {'userId': 'usr_9812', 'query': 'flutter'},
                      json: {'page': 1, 'pageSize': 20, 'results': 3},
                    );
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.healing, size: 18),
                  label: const Text('Log Handled Exception'),
                  onPressed: () {
                    try {
                      throw const FormatException('Simulated parsing error in response body');
                    } catch (e, st) {
                      DebugLog.error(
                        'Handled parsing exception',
                        tag: 'Parser',
                        error: e,
                        stackTrace: st,
                      );
                    }
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.report_problem, size: 18),
                  label: const Text('Trigger Uncaught Error'),
                  onPressed: () {
                    FlutterError.reportError(
                      FlutterErrorDetails(
                        exception: Exception('Simulated uncaught Flutter error'),
                        library: 'debug_bubble_example',
                        context: ErrorDescription('testing uncaught error hook'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Toolkit Controls & Export',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: Icon(
                    isDashboardOpen
                        ? Icons.visibility_off_outlined
                        : Icons.dashboard_outlined,
                    size: 18,
                  ),
                  label: Text(
                    isDashboardOpen ? 'Close Dashboard' : 'Open Dashboard',
                  ),
                  onPressed: () {
                    final c = DebugLog.controller;
                    if (c == null) return;
                    if (c.isDashboardOpen) {
                      c.closeDashboard();
                    } else {
                      c.openDashboard();
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.text_snippet_outlined, size: 18),
                  label: const Text('Export Text'),
                  onPressed: () => _showExportDialog(context, false),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.code_outlined, size: 18),
                  label: const Text('Export JSON'),
                  onPressed: () => _showExportDialog(context, true),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: const Text('Clear All'),
                  onPressed: () => DebugLog.controller?.clear(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Recent Logs Preview (Latest 5)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (recentEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'No log entries yet. Tap a button above to generate logs.',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              )
            else
              ...recentEntries.map((entry) => _LogEntryTile(entry: entry)),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withAlpha(70)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final DebugLogEntry entry;

  Color _levelColor(DebugLogLevel level) {
    switch (level) {
      case DebugLogLevel.debug:
        return Colors.grey;
      case DebugLogLevel.info:
        return Colors.blue;
      case DebugLogLevel.success:
        return Colors.green;
      case DebugLogLevel.warning:
        return Colors.orange;
      case DebugLogLevel.error:
        return Colors.red;
      case DebugLogLevel.critical:
        return const Color(0xFFAF52DE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(entry.level);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: Colors.grey.withAlpha(50)),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(4),
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
        title: Text(
          entry.message,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: entry.tag != null
            ? Text(
                'Tag: ${entry.tag}${entry.error != null ? ' | Error: ${entry.error!.message}' : ''}',
                style: const TextStyle(fontSize: 11),
              )
            : (entry.error != null
                ? Text(
                    'Error: ${entry.error!.message}',
                    style: const TextStyle(fontSize: 11),
                  )
                : null),
        trailing: Text(
          '#${entry.id}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }
}
