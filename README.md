# debug_bubble

A high-performance in-app diagnostic toolkit and floating log viewer for Flutter applications.

[![pub package](https://img.shields.io/pub/v/debug_bubble.svg)](https://pub.dev/packages/debug_bubble)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B.svg?logo=flutter)](https://flutter.dev)

`debug_bubble` provides a non-intrusive floating diagnostic bubble that expands into a full-featured in-app dashboard. Designed for mobile, tablet, desktop, and web, it enables real-time log streaming, full-text searching, JSON payload inspection, stack trace visualization, and automatic unhandled error capture with zero third-party runtime dependencies.

---

## Features

- **Floating Diagnostic Bubble:** Free-floating overlay that automatically snaps to display edges and reflects live error counters.
- **Real-Time Log Stream:** Low-latency log viewer with debounced filtering, severity filtering chips, and smooth auto-scrolling.
- **Inline Entry Details:** Inspect messages, error types, collapsible monospace stack traces, metadata tables, and pretty-printed JSON payloads.
- **Dedicated Errors Tab:** Instant isolated view for investigating high-severity (`error` and `critical`) issues.
- **Toolkit Diagnostics (Info Tab):** Real-time monitoring of session state, build mode, ring buffer capacity, and error-hook health.
- **Automatic Crash Capture:** Integrates with `FlutterError.onError` and `PlatformDispatcher.onError` with re-entrancy protection.
- **Data Privacy & Redaction:** Configurable key and token normalization to redact sensitive credentials (passwords, tokens, API keys) alongside regex pattern scanning.
- **Memory & Resource Bounded:** Implements a fixed-capacity ring buffer (default 1,000 entries) and payload depth caps to prevent memory leaks.
- **Zero Overhead in Release:** The toolkit is inert in release mode (`kReleaseMode`), ensuring zero CPU or memory footprint in production.

---

## Screenshots

| Floating Bubble Overlay | Real-Time Dashboard | Error & Crash Stream | Detailed Stack Trace |
|:---:|:---:|:---:|:---:|
| <img src="https://raw.githubusercontent.com/Satyam-Gawali/debug_bubble/main/example/screenshots/floating_bubble.jpg" width="220" alt="Floating Bubble Overlay" /> | <img src="https://raw.githubusercontent.com/Satyam-Gawali/debug_bubble/main/example/screenshots/dashboard_logs.jpg" width="220" alt="Dashboard Logs" /> | <img src="https://raw.githubusercontent.com/Satyam-Gawali/debug_bubble/main/example/screenshots/error_stream.jpg" width="220" alt="Error Stream" /> | <img src="https://raw.githubusercontent.com/Satyam-Gawali/debug_bubble/main/example/screenshots/entry_detail.jpg" width="220" alt="Entry Detail" /> |

### IDE Terminal Console Logging

<img src="https://raw.githubusercontent.com/Satyam-Gawali/debug_bubble/main/example/screenshots/console_output.png" height="340" alt="IDE Console Output" />

---

## Getting Started

### Installation

Add `debug_bubble` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  debug_bubble: ^0.1.1
```

Alternatively, run:

```bash
flutter pub add debug_bubble
```

### Basic Initialization

Initialize the toolkit in your `main()` before executing `runApp`:

```dart
import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  DebugLog.init(
    const DebugBubbleConfig(
      captureUncaughtErrors: true,
      consoleOutput: true,
    ),
  );

  runApp(const MyApp());
}
```

### Full Configuration Setup

For production applications requiring custom data redaction, theme branding, custom export destinations, or adjusted buffer capacities:

```dart
import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  DebugLog.init(
    DebugBubbleConfig(
      // Master switch and ring buffer capacity
      enabled: true,
      maxEntries: 1000,
      minLevel: DebugLogLevel.debug,

      // Console logging with ANSI severity colors
      consoleOutput: true,

      // Automatic uncaught framework and platform crash interception
      captureUncaughtErrors: true,

      // Viewport docking alignment for the floating bubble
      initialBubbleAlignment: Alignment.centerRight,

      // Sensitive data masking rules
      redaction: DebugRedactionConfig(
        enabled: true,
        sensitiveKeys: {
          ...DebugRedactionConfig.defaultSensitiveKeys,
          'token',
          'secret',
          'apiKey',
        },
        sensitiveKeyTokens: {
          ...DebugRedactionConfig.defaultSensitiveKeyTokens,
          'pin',
          'cvv',
        },
        valuePatterns: [
          RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), // Emails
          RegExp(r'\b(?:\d{4}[ -]?){3}\d{4}\b'), // Payment card numbers
        ],
        replacement: '[REDACTED]',
      ),

      // Custom theme and severity badge palette
      theme: const DebugBubbleTheme(
        mode: ThemeMode.system,
        bubbleColor: Color(0xFF1E1E24),
        bubbleIconColor: Colors.white,
        levelColors: {
          DebugLogLevel.critical: Color(0xFFBF5AF2),
          DebugLogLevel.error: Color(0xFFFF453A),
        },
      ),

      // Optional export callback (e.g., upload to backend or save to disk)
      onExport: (String jsonPayload) async {
        // await RemoteCrashReporter.upload(jsonPayload);
      },
    ),
  );

  runApp(const MyApp());
}
```

### Dashboard Setup

Attach `DebugBubble` to your root application widget via `MaterialApp.builder`:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Application',
      builder: (context, child) => DebugBubble(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}
```

#### Declarative Routing (`go_router`)
When using declarative routers like `go_router` or `auto_route`, wrap the root builder inside `MaterialApp.router`. Route redirects and navigator state changes will operate independently without dismissing the dashboard layer:

```dart
MaterialApp.router(
  routerConfig: appRouter,
  builder: (context, child) => DebugBubble(
    child: child ?? const SizedBox.shrink(),
  ),
);
```

---

## API Reference

### Logging Methods (`DebugLog`)

The static `DebugLog` facade emits structured entries into the bounded memory store and terminal console:

| Method | Console ANSI Color | UI Badge Color | Supported Parameters | Intended Use |
|---|---|---|---|---|
| `DebugLog.trace()` | Gray (`\x1B[90m`) | ⚪ `#8E8E93` | `message`, `tag`, `subTag`, `metadata`, `json` | Fine-grained verbose diagnostics, iterations, or low-level values. |
| `DebugLog.debug()` | Cyan (`\x1B[36m`) | 🩵 `#64D2FF` | `message`, `tag`, `subTag`, `metadata`, `json` | Development-phase state transitions and component lifecycles. |
| `DebugLog.info()` | Blue (`\x1B[34m`) | 🔵 `#0A84FF` | `message`, `tag`, `subTag`, `metadata`, `json` | Standard operational milestones (e.g., page navigation, user actions). |
| `DebugLog.success()` | Green (`\x1B[32m`) | 🟢 `#30D158` | `message`, `tag`, `subTag`, `metadata`, `json` | Successful operational outcomes (e.g., API 200 OK, sync completion). |
| `DebugLog.warning()` | Yellow (`\x1B[33m`) | 🟠 `#FF9F0A` | `message`, `tag`, `subTag`, `metadata`, `json` | Non-fatal warnings (e.g., degraded connectivity, cache evictions). |
| `DebugLog.error()` | Red (`\x1B[31m`) | 🔴 `#FF453A` | `message`, `tag`, `subTag`, `error`, `stackTrace`, `metadata`, `json` | Caught exceptions, failed network calls, or validation failures. |
| `DebugLog.critical()` | Magenta (`\x1B[35m`) | 🟣 `#BF5AF2` | `message`, `tag`, `subTag`, `error`, `stackTrace`, `metadata`, `json` | Critical subsystem failures, corrupt state, or unhandled errors. |

#### Parameter Descriptions:
- `message` (`String`, required): The log description.
- `tag` (`String?`, optional): Top-level architectural domain (e.g., `'Network'`, `'Auth'`).
- `subTag` (`String?`, optional): Secondary sub-domain or endpoint (e.g., `'Login'`, `'UserSync'`).
- `error` (`Object?`, optional): Captured error or exception instance.
- `stackTrace` (`StackTrace?`, optional): Associated execution stack trace.
- `metadata` (`Map<String, Object?>?`, optional): Arbitrary structured key-value pairs.
- `json` (`Object?`, optional): JSON-serializable map, list, or primitive payload.

---

### Toolkit Configuration (`DebugBubbleConfig`)

Passed to `DebugLog.init()` to configure engine limits and behavior:

| Property | Type | Default Value | Description |
|---|---|---|---|
| `enabled` | `bool` | `true` | Master activation switch. Package is completely inert when `false` or in release mode. |
| `minLevel` | `DebugLogLevel` | `DebugLogLevel.debug` | Minimum severity level accepted by the ingestion pipeline. |
| `maxEntries` | `int` | `1000` | Capacity of the memory ring buffer. Oldest entries are discarded when exceeded. |
| `consoleOutput` | `bool` | `true` | Whether to write color-formatted entries to standard output. |
| `captureUncaughtErrors` | `bool` | `false` | Enables automatic hooking of unhandled framework and platform exceptions (opt-in). |
| `initialBubbleAlignment` | `Alignment` | `Alignment.centerRight` | Initial viewport anchor position for the floating bubble. |
| `redaction` | `DebugRedactionConfig` | `const DebugRedactionConfig()` | Rules for tokenized sensitive key masking and regex pattern scanning. |
| `theme` | `DebugBubbleTheme` | `const DebugBubbleTheme()` | Visual appearance configuration for bubble and dashboard components. |
| `onExport` | `FutureOr<void> Function(String)?` | `null` | Callback invoked during export operations (e.g., uploading to a remote service). |

---

### Sensitive Data Redaction (`DebugRedactionConfig`)

Configures data sanitization across messages, metadata, and JSON payloads:

| Property | Type | Default Value | Description |
|---|---|---|---|
| `enabled` | `bool` | `true` | Controls active redaction. Enforced active in release mode as defense-in-depth. |
| `sensitiveKeys` | `Set<String>` | `{'password', 'token', 'auth', 'secret', ...}` | Key substrings that trigger value replacement with `[REDACTED]`. |
| `sensitiveKeyTokens` | `Set<String>` | `{'pwd', 'apikey', 'bearer', ...}` | Exact tokens checked against compound camelCase and snake_case keys. |
| `valuePatterns` | `List<RegExp>` | `[]` | Regex patterns executed against string values (e.g., credit card or tax identifiers). |
| `replacement` | `String` | `'[REDACTED]'` | Replacement mask injected for sanitized data. |

---

### Theming Configuration (`DebugBubbleTheme`)

| Property | Type | Default Value | Description |
|---|---|---|---|
| `mode` | `ThemeMode` | `ThemeMode.system` | Brightness mode: `ThemeMode.system`, `ThemeMode.dark`, or `ThemeMode.light`. |
| `bubbleColor` | `Color?` | `null` | Background color override for the floating bubble. |
| `bubbleIconColor` | `Color?` | `null` | Icon tint override for the floating bubble. |
| `levelColors` | `Map<DebugLogLevel, Color>?` | `null` | Custom color palette overrides mapped by severity level. |

---

## Examples

### API & Network Logging
```dart
try {
  final response = await httpClient.get(Uri.parse('https://api.example.com/profile'));

  if (response.statusCode == 200) {
    DebugLog.success(
      'User profile loaded',
      tag: 'Profile',
      json: jsonDecode(response.body),
    );
  } else {
    DebugLog.warning(
      'Profile request returned non-200 status',
      tag: 'Profile',
      metadata: {'statusCode': response.statusCode},
      json: jsonDecode(response.body),
    );
  }
} catch (error, stackTrace) {
  DebugLog.error(
    'Failed to load user profile',
    tag: 'Profile',
    error: error,
    stackTrace: stackTrace,
  );
}
```

### Unhandled Error Capture
When `captureUncaughtErrors: true` is configured, errors thrown during widget build or layout phases are routed directly to the dashboard:

```dart
// Captured automatically via FlutterError.onError
throw FlutterError('RenderBox constraints violated');
```

### Programmatic Controller Access
The active default controller can be accessed via `DebugLog.controller` to inspect buffer state, manage the overlay, or export logs:

```dart
// Open or close the dashboard overlay programmatically
DebugLog.controller?.openDashboard();
DebugLog.controller?.closeDashboard();

// Query in-memory buffer statistics
final totalEntries = DebugLog.controller?.entryCount ?? 0;
final errorCount = DebugLog.controller?.errorCount ?? 0;
final evictedCount = DebugLog.controller?.droppedCount ?? 0;

// Export filtered logs on demand
final jsonReport = DebugLog.controller?.exportJson();
final textReport = DebugLog.controller?.exportText();

// Clear buffer manually
DebugLog.controller?.clear();
```

---

## Production & Release Mode

When compiled in release mode (`kReleaseMode`):
- `DebugBubbleController` is completely inert.
- `DebugLog` calls are dropped immediately with zero memory allocation.
- No global error hooks are installed.
- `DebugBubble` returns only `widget.child` without allocating overlay or gesture hierarchies.

---

## Author

Developed and maintained by **Satyam Gawali**.

[![GitHub](https://img.shields.io/badge/GitHub-Satyam--Gawali-181717?style=for-the-badge&logo=github)](https://github.com/Satyam-Gawali)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Satyam_Gawali-0A66C2?style=for-the-badge&logo=linkedin)](https://www.linkedin.com/in/satyam-gawali-b4623b268/)

Contributions, feedback, and issue reports are always welcome!

---

## License

This package is distributed under the MIT License. See [LICENSE](LICENSE) for details.
