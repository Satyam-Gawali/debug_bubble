# API_DESIGN.md — debug_bubble

Status: Draft v0.2 · Depends on: PROJECT_SPEC.md, ARCHITECTURE.md (lifecycle L-xx, hooks E-xx), DATA_MODELS.md · Signatures are a proposal until approved; afterwards any change needs a decision record (AI_WORKFLOW.md §1). Dart snippets are conceptual (not compiled yet; first compile check happens in T1.4).

## 1. Public surface — exactly ten symbols

`lib/debug_bubble.dart` exports: `DebugBubble`, `DebugBubbleConfig`, `DebugBubbleController`, `DebugBubbleTheme`, `DebugLog`, `DebugLogLevel`, `DebugLogEntry`, `DebugErrorInfo`, `DebugLogFilter`, `DebugRedactionConfig`.

Not exported: `DebugLogService`, store, pipeline, sanitizer, redactor, hook registry, build-mode resolver, exporters, UI internals, `debugBubbleVersion` (D-25, used by the Info tab and export only).

## 2. Integration (single recommended pattern)

```dart
void main() {
  // First statement: logs written before init are silently dropped (L-4, D-24).
  DebugLog.init(const DebugBubbleConfig(captureUncaughtErrors: true));
  // If you use Crashlytics/Sentry, initialize them BEFORE DebugLog.init (ARCHITECTURE.md E-6).
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        builder: (context, child) =>
            DebugBubble(child: child ?? const SizedBox.shrink()),
        home: const HomePage(),
      );
}
```

`DebugBubble` without a `controller` follows the default controller created by `DebugLog.init`. Advanced alternative: construct your own `DebugBubbleController`, pass it to `DebugBubble(controller: …)`, call `controller.log(...)`, and dispose it yourself; the `DebugLog` facade does not reach standalone controllers (L-2).

## 3. `DebugLog` — static facade

`DebugLog` is non-instantiable (private constructor).

```dart
class DebugLog {
  DebugLog._();

  /// Creates the default controller, disposing any previous default (L-3).
  /// Returns an inert controller when the build mode disallows activity (D-04).
  /// Never throws for valid config; invalid values assert in debug and are clamped otherwise.
  static DebugBubbleController init([DebugBubbleConfig config = const DebugBubbleConfig()]);

  /// The default controller, or null before init / after dispose.
  static DebugBubbleController? get controller;

  /// Disposes and clears the default controller. No-op if none. Idempotent.
  static void dispose();

  static void log(DebugLogLevel level, String message,
      {String? tag, String? subTag, Object? error, StackTrace? stackTrace,
       Map<String, Object?>? metadata, Object? json});

  static void debug(String message,
      {String? tag, String? subTag, Object? error, StackTrace? stackTrace,
       Map<String, Object?>? metadata, Object? json});
  static void info(String message,
      {String? tag, String? subTag, Object? error, StackTrace? stackTrace,
       Map<String, Object?>? metadata, Object? json});
  static void success(String message,
      {String? tag, String? subTag, Object? error, StackTrace? stackTrace,
       Map<String, Object?>? metadata, Object? json});
  static void warning(String message,
      {String? tag, String? subTag, Object? error, StackTrace? stackTrace,
       Map<String, Object?>? metadata, Object? json});
  static void error(String message,
      {String? tag, String? subTag, Object? error, StackTrace? stackTrace,
       Map<String, Object?>? metadata, Object? json});
  static void critical(String message,
      {String? tag, String? subTag, Object? error, StackTrace? stackTrace,
       Map<String, Object?>? metadata, Object? json});
}
```

Behavior (all methods): synchronous; return `void`; **never throw** (internal failures are swallowed, fail closed); no-op when there is no default controller, the controller is inert or disposed, or `level < config.minLevel`. The first facade call with no default controller prints one debug-only notice. `json` accepts any object; conversion rules are in DATA_MODELS.md §7. Only the isolate that called `init` is served (L-12).

## 4. `DebugLogLevel`

```dart
enum DebugLogLevel {
  debug, info, success, warning, error, critical;
  bool get isError;                         // error || critical
  bool operator >=(DebugLogLevel other);    // compares index (severity order, D-11)
}
```

## 5. `DebugBubbleConfig`

```dart
class DebugBubbleConfig {
  const DebugBubbleConfig({
    this.enabled = true,
    this.minLevel = DebugLogLevel.debug,
    this.maxEntries = 1000,
    this.maxEntryChars = 40000,
    this.maxMessageLength = 8000,
    this.maxStackTraceLength = 16000,
    this.maxPayloadLength = 32000,
    this.consoleOutput = true,
    this.captureUncaughtErrors = false,
    this.redaction = const DebugRedactionConfig(),
    this.theme = const DebugBubbleTheme(),
    this.initialBubbleAlignment = Alignment.centerRight,
    this.onExport,
  });

  final bool enabled;
  final DebugLogLevel minLevel;
  final int maxEntries;
  final int maxEntryChars;
  final int maxMessageLength;
  final int maxStackTraceLength;
  final int maxPayloadLength;
  final bool consoleOutput;
  final bool captureUncaughtErrors;
  final DebugRedactionConfig redaction;
  final DebugBubbleTheme theme;
  final Alignment initialBubbleAlignment;
  final FutureOr<void> Function(String json)? onExport;

  DebugBubbleConfig copyWith({
    bool? enabled, DebugLogLevel? minLevel, int? maxEntries, int? maxEntryChars,
    int? maxMessageLength, int? maxStackTraceLength, int? maxPayloadLength,
    bool? consoleOutput, bool? captureUncaughtErrors, DebugRedactionConfig? redaction,
    DebugBubbleTheme? theme, Alignment? initialBubbleAlignment,
    FutureOr<void> Function(String json)? onExport,
    bool clearOnExport = false,
  });
}
```

| Field | Default | Valid range | Notes |
|---|---|---|---|
| `enabled` | `true` | — | Can only switch the package **off**. Effective activity = `enabled && !kReleaseMode` (D-04). There is no release override in 0.1.0. |
| `minLevel` | `debug` | — | Gate before any processing. |
| `maxEntries` | 1000 | ≥ 1 | No upper cap is enforced; larger values raise memory use (README warns). |
| `maxEntryChars` | 40000 | ≥ 1024 | Combined per-entry budget (DATA_MODELS.md §6). |
| `maxMessageLength` | 8000 | ≥ 256 | |
| `maxStackTraceLength` | 16000 | ≥ 256 | |
| `maxPayloadLength` | 32000 | ≥ 256 | Shared by metadata then json. |
| `consoleOutput` | `true` | — | `debugPrint` + `dart:developer`. |
| `captureUncaughtErrors` | `false` | — | Opt-in (D-08); needs an active controller. |
| `onExport` | `null` | — | Receives the exported JSON string; may be async; failures are reported in the UI, never thrown (D-26). |

Error behavior: out-of-range values trigger an `assert` in debug; outside debug they are clamped to the nearest valid value. Config is immutable; to change it, create a new controller (L-10). `const` construction requires a `const`/null `onExport` and `const` nested configs.

## 6. `DebugRedactionConfig`

```dart
class DebugRedactionConfig {
  const DebugRedactionConfig({
    this.enabled = true,
    this.sensitiveKeys = defaultSensitiveKeys,
    this.sensitiveKeyTokens = defaultSensitiveKeyTokens,
    this.valuePatterns = const <RegExp>[],
    this.replacement = '[REDACTED]',
  });

  static const Set<String> defaultSensitiveKeys = {
    'password', 'passwd', 'passphrase', 'secret', 'token', 'authorization',
    'cookie', 'apikey', 'privatekey', 'accesskey', 'credential',
  };
  static const Set<String> defaultSensitiveKeyTokens = {
    'pin', 'otp', 'cvv', 'cvc', 'ssn', 'card', 'session', 'auth',
  };

  final bool enabled;
  final Set<String> sensitiveKeys;        // substring match on the normalized key
  final Set<String> sensitiveKeyTokens;   // whole-token match
  final List<RegExp> valuePatterns;       // applied to message, error text, stack, tag/subTag, string values
  final String replacement;

  DebugRedactionConfig copyWith({
    bool? enabled, Set<String>? sensitiveKeys, Set<String>? sensitiveKeyTokens,
    List<RegExp>? valuePatterns, String? replacement,
  });
}
```

Matching rules (D-28): see SECURITY_PERFORMANCE.md §3. `enabled: false` is honored only outside release builds; because 0.1.0 is inert in release, this is defense in depth. Redaction is best-effort and is never documented as guaranteed.

## 7. `DebugBubbleTheme`

```dart
class DebugBubbleTheme {
  const DebugBubbleTheme({
    this.mode = ThemeMode.system,
    this.bubbleColor,
    this.bubbleIconColor,
    this.levelColors,
  });

  final ThemeMode mode;                               // system | light | dark
  final Color? bubbleColor;                           // null → built-in per-brightness default
  final Color? bubbleIconColor;
  final Map<DebugLogLevel, Color>? levelColors;       // missing levels use built-in defaults

  DebugBubbleTheme copyWith({
    ThemeMode? mode, Color? bubbleColor, Color? bubbleIconColor,
    Map<DebugLogLevel, Color>? levelColors,
    bool clearBubbleColor = false, bool clearBubbleIconColor = false,
    bool clearLevelColors = false,
  });
}
```

The dashboard does not inherit the host theme (UI_UX_SPEC.md §7).

## 8. `DebugBubbleController`

```dart
class DebugBubbleController extends ChangeNotifier {
  /// Standalone controller; NOT registered globally (L-1, L-2). The creator must dispose it (L-7).
  DebugBubbleController({DebugBubbleConfig config = const DebugBubbleConfig()});

  DebugBubbleConfig get config;
  bool get isActive;            // enabled && build mode allows && !isDisposed
  bool get isDisposed;
  List<DebugLogEntry> get entries;   // unmodifiable snapshot, oldest → newest, cached until next change
  int get entryCount;
  int get droppedCount;              // capacity evictions (D-23)
  int get errorCount;                // stored entries with level.isError
  bool get isDashboardOpen;

  void log(DebugLogLevel level, String message,
      {String? tag, String? subTag, Object? error, StackTrace? stackTrace,
       Map<String, Object?>? metadata, Object? json});

  List<DebugLogEntry> query(DebugLogFilter filter);
  void clear();                                                // no confirmation; the UI asks first
  String exportJson({DebugLogFilter filter = const DebugLogFilter()});  // schema v1
  String exportText({DebugLogFilter filter = const DebugLogFilter()});  // plain text, DATA_MODELS.md §9
  void openDashboard();
  void closeDashboard();

  @override
  void dispose();               // idempotent (L-8)
}
```

Behavior: `log`, `clear`, `openDashboard`, `closeDashboard` never throw and are no-ops when inactive or disposed. `query` returns an empty list and the export methods return a valid zero-entry document when inactive or disposed. Listeners are notified at most once per frame (D-18). On `dispose()` listeners are notified once before the notifier is disposed so mounted UI can drop itself. Whether `removeListener` may be called after `dispose` is verified in T2.7; UI code must not rely on it.

## 9. `DebugBubble`

```dart
class DebugBubble extends StatefulWidget {
  const DebugBubble({super.key, required this.child, this.controller});
  final Widget child;
  final DebugBubbleController? controller;
}
```

- With `controller`: bound to it (rebinds if the parent supplies another instance).
- Without: follows the default controller; renders only `child` while none exists (debug-only notice once) and rebinds when one appears, is replaced or is disposed (L-6).
- Never creates, registers or disposes a controller.
- Intended placement: `MaterialApp.builder` (also `CupertinoApp`/`WidgetsApp`; verified in T3.1).

## 10. `DebugLogEntry`, `DebugErrorInfo`, `DebugLogFilter`

```dart
class DebugLogEntry {
  final int id; final DateTime timestamp; final DebugLogLevel level; final String message;
  final String? tag; final String? subTag; final DebugErrorInfo? error; final String? stackTrace;
  final Map<String, Object?>? metadata; final Object? json;
  final bool isUncaught; final bool truncated;
  Map<String, Object?> toJson();
}   // constructed only internally; no public constructor

class DebugErrorInfo { final String type; final String message; Map<String, Object?> toJson(); }

class DebugLogFilter {
  const DebugLogFilter({this.levels = const <DebugLogLevel>{}, this.query = '', this.tag});
  final Set<DebugLogLevel> levels; final String query; final String? tag;
  bool get isEmpty;
  bool matches(DebugLogEntry entry);
  DebugLogFilter copyWith({Set<DebugLogLevel>? levels, String? query, String? tag, bool clearTag = false});
}
```

Filter semantics: DATA_MODELS.md §4.

## 11. Stability rules

- Pre-1.0 versions may change the API; every change is listed in CHANGELOG.md.
- New public symbols require a decision record and an update to this file and PROJECT_SPEC.md §5.
- No public signature exposes `src/` types.
- Documented build-mode behavior (D-04) and lifecycle rules (L-1…L-12) are part of the API contract.
