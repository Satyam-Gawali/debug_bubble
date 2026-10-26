# debug_bubble Example Application

A functional demonstration application for the `debug_bubble` package in Flutter.

This example showcases how to integrate the package, emit structured logs across all six severity levels, attach contextual metadata and errors, inspect real-time metrics, capture uncaught errors, and preview exported log sessions.

---

## What This Example Demonstrates

1. **Initialization & Setup**:
   - `DebugLog.init(const DebugBubbleConfig(captureUncaughtErrors: true))` initializes the default controller before `runApp`.
   - `DebugBubble` widget wraps application content in `MaterialApp.builder`.
2. **Real-Time Metrics & Reactivity**:
   - Live counters for **Total Logs** (`entryCount`), **Errors** (`errorCount`), **Dropped** (`droppedCount`), and **Engine Status** (`isActive`).
   - UI updates reactively via controller change notifications as logs are ingested or cleared.
3. **Six Severity Levels & Colored Console Output**:
   - Quick-action chips to emit `debug`, `info`, `success`, `warning`, `error`, and `critical` log entries.
   - Every log is piped through the core logging engine to both the in-app buffer and the IDE debug console in severity-specific ANSI colors:
     - **DEBUG**: Grey (`\x1B[90m`)
     - **INFO**: Cyan (`\x1B[36m`)
     - **SUCCESS**: Green (`\x1B[32m`)
     - **WARNING**: Yellow (`\x1B[33m`)
     - **ERROR**: Red (`\x1B[31m`)
     - **CRITICAL**: Magenta (`\x1B[35m`)
   - Emits exactly once per entry with an automatic ANSI reset (`\x1B[0m`) preventing color bleed.

> [!NOTE]
> **Console Color Compatibility**: Colored console output relies on standard ANSI escape sequences supported by most modern IDE debug consoles (VS Code, Android Studio, IntelliJ) and terminal emulators. If ANSI escape sequences are not supported or are stripped by your console environment, the output remains cleanly readable as structured plain text.
4. **Structured Context & Error Details**:
   - Emitting logs with `tag`, structured `metadata`, and nested `json` maps.
   - Emitting logs with caught `Exception` and `StackTrace`.
5. **Uncaught Error Capture**:
   - Demonstrates the global error collector hooked into `FlutterError.onError`.
6. **Log Export**:
   - In-app preview modal for exported formatted plain text (`exportText()`) and Schema v1 JSON (`exportJson()`).
7. **Buffer Management**:
   - Clearing all logs (`DebugLog.controller?.clear()`).
   - Toggling dashboard state (`openDashboard()` / `closeDashboard()`).

---

## How to Run

From this directory (`example/`):

```bash
flutter run
```

Or from the repository root:

```bash
flutter run -t example/lib/main.dart
```

---

## Current Status & Roadmap Note

- **Phase 1 & 2 (Current)**:
  The core logging engine, ring buffer storage, payload sanitization and redaction, global error collectors, exporters, and facade APIs are fully implemented and verified.
- **Phase 3 (Upcoming)**:
  The floating draggable bubble, badge overlays, gesture snapping, and full-screen searchable dashboard UI widgets are scheduled for Phase 3. In the meantime, this example provides an interactive host UI to exercise the underlying engine.
