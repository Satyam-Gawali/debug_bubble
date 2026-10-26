# Changelog

All notable changes to `debug_bubble` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-26

Initial public release of `debug_bubble` — a reusable, zero-dependency Flutter debugging toolkit with an in-app floating bubble and diagnostic dashboard.

### Added
- **Floating Debug Bubble (`DebugBubble`):**
  - Draggable floating overlay that snaps smoothly to horizontal screen edges on release.
  - Dynamic error count badge tracking stored error/critical entries.
  - Tap to toggle full-screen debug dashboard overlay without modifying host navigation routes.
- **In-App Debug Dashboard:**
  - **Logs Tab:** Live log stream with debounced search, severity filter chips (TRACE, DEBUG, INFO, SUCCESS, WARNING, ERROR, CRITICAL), and smooth auto-scroll.
  - **Inline Expansion:** Tap any log entry to expand inline details, showing selectable message, formatted error type, collapsible monospace stack trace, metadata table, and JSON payload viewer with quick-copy actions.
  - **Errors Tab:** Pre-filtered view dedicated to error and critical severity entries.
  - **Info Tab:** Toolkit health diagnostics, active build mode (`debug`, `profile`, `release`), store capacity progress bar, severity counters, and error hook status.
  - **Dashboard Actions:** Three-dot overflow menu (⋮) supporting plain-text export ("Copy all"), schema v1 JSON export ("Export JSON"), and destructive log clearing ("Clear logs") with confirmation dialog.
- **Logging Facade (`DebugLog`):**
  - Static logging API with methods for `log()`, `debug()`, `info()`, `success()`, `warning()`, `error()`, and `critical()`.
  - Support for `tag`, `subTag`, `error`, `stackTrace`, `metadata` maps, and `json` structures.
  - ANSI colored terminal output (`ConsoleSink`) with configurable level colors.
- **Automatic Uncaught Error Interception:**
  - Captures uncaught Flutter framework errors (`FlutterError.onError`) and asynchronous platform dispatch errors (`PlatformDispatcher.onError`).
  - Recursion guard flags to prevent infinite error cascade loops.
  - Preserves host error handlers and restores original handlers on disposal.
- **Security & Data Sanitization:**
  - Automated sensitive key redaction (normalizing and tokenizing keys like `password`, `token`, `secret`, `apiKey`).
  - Regex value pattern masking with bounded scan windows to prevent ReDoS.
  - Enforced redaction in release mode as defense-in-depth.
  - Bounded payload traversal: limits max depth (8), max node count (2,000), collection items (200), string lengths (2,000), and breaks circular object references cleanly.
- **Memory & Resource Bounding:**
  - Fixed-capacity ring buffer (default 1,000 entries) with $O(1)$ eviction and dropped entry tracking.
  - 500,000 character clipboard safety cap to prevent mobile OS memory exhaustion.
- **Build Mode Awareness:**
  - Fully inert in release mode (`kReleaseMode`): logging calls are dropped, background hooks are skipped, and the root widget renders only the child subtree.
- **Zero Third-Party Dependencies:**
  - Built strictly with Flutter and Dart standard libraries.
