# ARCHITECTURE.md — debug_bubble

Status: Draft v0.2 · Depends on: PROJECT_SPEC.md (D-xx) · Consistent with: API_DESIGN.md, DATA_MODELS.md, SECURITY_PERFORMANCE.md · Authoritative home of the **lifecycle contract (L-1…L-12)** and the **error-hook contract (E-1…E-9)**.

## 1. Principles

Flutter-SDK-only core (D-07) · separated concerns (logging, storage, UI, export) · bounded memory and CPU per entry (D-21) · sanitize once at ingestion (D-05, D-22) · small public API · optional integrations live in separate packages · logging never throws into host code.

## 2. Layers and data flow

```
Host code ─ DebugLog.info(...) / controller.log(...)
   ▼
Public API: DebugLog · DebugBubbleController · DebugBubble · config types
   ▼
DebugLogService (internal pipeline, runs synchronously, wrapped in try/catch)
   1. active gate (controller active, not disposed) and minLevel gate
   2. sanitize: guarded string conversion → redact (value patterns, scan window)
      → budgeted traversal of metadata/json (redact keys, caps, cycle/depth) → truncate
      → apply retention priority and combined entry budget      [raw values go out of scope here]
   3. create immutable DebugLogEntry                              [the only form that exists after this]
   4. fan out: Console Sink (guarded formatting) · Bounded Store (ring buffer)
                          │ coalesced notify (D-18)
                          ▼
                 Dashboard UI ── filters/search/details/actions
```

Errors inside the pipeline are swallowed (at most one debug-only `debugPrint` per failure category) so host code never sees them (NFR-03). Every consumer — console, store, dashboard, export — receives only the sanitized entry.

## 3. Modules (under `lib/src/`)

| Module | Responsibility | May depend on |
|---|---|---|
| `core/` | config, controller, facade registry, level, entry, store | Flutter foundation |
| `version.dart` (src root) | `debugBubbleVersion` constant (D-25) | none |
| `core/sanitize/` | redactor, budgeted traversal, truncation | `core` models |
| `collectors/` | console sink; error-hook registry and collector | `core` |
| `filters/` | `DebugLogFilter` matching | `core` models |
| `export/` | JSON and plain-text exporters | `core` models |
| `ui/` | bubble, dashboard, tabs, list, details, theme, back handling | `core`, `filters`, `export` |
| `utils/` | clock, id generator, build-mode resolver, clipboard seam (test seams) | none |

Rules: `core` never imports `ui`; `ui` reaches data only through `DebugBubbleController`; `collectors`, `filters`, `export` never import `ui`. Only `lib/debug_bubble.dart` exports public symbols (ten, see API_DESIGN.md §1). Test seams (clock, ids, build mode, console sink, clipboard) are internal, `@visibleForTesting`, and imported by tests from `package:debug_bubble/src/…`.

## 4. UI hosting (D-01, D-02, D-27)

`DebugBubble` is placed in `MaterialApp.builder`. It builds a `Stack`: the host `child`, then (when open) the dashboard layer, then the bubble. Because the builder context is above the `Navigator`:

- The layer provides its own `Material`, its own theme (not inherited, UI_UX_SPEC.md §7), and a nested `Overlay` so text selection handles and toolbars have an overlay to attach to.
- It relies on `MediaQuery`, `Directionality` and `Localizations` from ancestors above the builder. **This is assumed, not verified** (R-18) and is checked in T3.1.
- **Back handling is unresolved (D-27, R-16).** `PopScope` needs a route and therefore does not apply above the `Navigator`; a `WidgetsBindingObserver.didPopRoute` registered by `DebugBubble` is likely to run *after* the app's own observer and might never see the event. T3.1 is a time-boxed spike with go/no-go criteria in IMPLEMENTATION_ROADMAP.md. Hard requirement either way: when the dashboard is closed, `DebugBubble` must never consume or alter back events.
- Safe areas and keyboard insets come from `MediaQuery`.

## 5. Lifecycle contract (D-03, D-24)

| # | Rule |
|---|---|
| L-1 | There are two kinds of controller: the **default controller**, created and owned by `DebugLog.init` (at most one exists at a time), and **standalone controllers**, constructed directly by app code and owned by it. |
| L-2 | The static `DebugLog` facade routes only to the default controller. Standalone controllers never receive facade calls and are never registered globally. |
| L-3 | `DebugLog.init(config)` is synchronous and always returns a new default controller. If a default already exists it is disposed first (debug-only notice). If the build mode makes the package inert (D-04) the returned controller is inert (`isActive == false`) but is still the default. `init` may be called before `WidgetsFlutterBinding.ensureInitialized()` and before `runApp`; the recommended call is the first statement of `main()`. *(Replace semantics pending owner approval, D-03.)* |
| L-4 | Logging through the facade before `init`, after `DebugLog.dispose()`, or into an inert/disposed controller is a silent no-op (one debug-only notice for the facade case). Nothing is buffered before `init`: redaction and limits depend on the configuration, and buffering would retain unsanitized data (D-24). Logs emitted before `runApp` are captured only if `init` ran earlier. |
| L-5 | `DebugLog.dispose()` disposes the default controller and clears the slot; it is a no-op when there is none and is idempotent. |
| L-6 | `DebugBubble(controller: c)` binds to `c` for its life (rebinding if the parent passes a different instance). `DebugBubble()` without a controller **follows the default**: it resolves the default at build, listens to an internal registry notifier, and rebinds when the default is replaced, disposed or created later. While no controller exists it renders only its `child` and prints one debug-only notice. `DebugBubble` never creates, registers or disposes a controller. |
| L-7 | **Ownership:** whoever constructs a controller disposes it. `DebugLog` disposes only the default; app code disposes standalone controllers (e.g. in `State.dispose`); widgets never dispose. |
| L-8 | `controller.dispose()` is idempotent. It sets `isDisposed`, unregisters from the error-hook registry, clears the store, notifies listeners once, then disposes the notifier. Afterwards `log`/`clear`/`openDashboard`/`closeDashboard` are no-ops, `query` returns an empty list, exports return a valid zero-entry document, getters return empty/zero values and never throw. A mounted `DebugBubble` reacts by showing only its child. |
| L-9 | **Reinitialization:** repeated `init` follows L-3 (dispose old default, create new). **Hot reload** keeps statics and does not re-run `main`. **Hot restart** re-runs `main`; whether any state (notably `PlatformDispatcher.instance.onError`) survives it is **unverified** and is checked on a device in T4.3 (R-11). The hook registry is idempotent so repeated installs never stack wrappers. |
| L-10 | Config is immutable per controller. Changing config means creating a new controller (via `init` replace or a new standalone controller). |
| L-11 | Error hooks are managed by one process-wide registry shared by all controllers (§6); controllers only register and unregister as sinks. |
| L-12 | A controller and the facade serve only the isolate that created them. Calls from other isolates hit that isolate's uninitialized facade and are no-ops; cross-isolate collection is out of scope for 0.1.0. |

Multiple controllers are supported only as standalone instances; the "one global default" invariant is enforced by the facade slot.

## 6. Error-hook contract (D-08)

Applies only when `captureUncaughtErrors` is true **and** the controller is active. Default is `false`.

| # | Rule |
|---|---|
| E-1 | An active controller with capture enabled registers with the process-wide `ErrorHookRegistry`; others never touch handlers. |
| E-2 | The first registration installs one wrapper pair and remembers the previous `FlutterError.onError` and `PlatformDispatcher.instance.onError` (the latter may be null). Further registrations only add sinks. |
| E-3 | **FlutterError wrapper:** forwards sanitized details to sinks inside try/catch, then **always** calls the previous handler (outside our try/catch, so the host handler's behavior, including its own exceptions, is unchanged). Level `error`, `isUncaught = true`. |
| E-4 | **PlatformDispatcher wrapper:** forwards to sinks in try/catch, then returns `previous?.call(error, stack) ?? false`. It never returns `true` on its own, so it never marks an error as handled and default reporting continues. Level `critical`, `isUncaught = true`. *(Levels are proposed.)* |
| E-5 | When the last sink unregisters: if the current handler is still our wrapper, restore the previous one; otherwise (another library replaced or wrapped ours) leave it in place and switch the wrapper to inactive pass-through that only forwards to the previous handler. |
| E-6 | If another library **replaces** a handler after `init` without chaining, our capture stops; the registry detects this by identity comparison and the Info tab shows `inactive (handler replaced)`. If a library **wraps** ours, capture continues. Recommended order: initialize Crashlytics/Sentry and similar tools first, then `DebugLog.init`, so we chain to them; if you prefer the opposite order, keep capture off and forward errors manually with `DebugLog.error(...)`. |
| E-7 | Installation uses static members only; whether it is safe before the Flutter binding exists is verified in T2.8. |
| E-8 | Errors reported through `runZonedGuarded` are not captured automatically; the host forwards them via the facade. |
| E-9 | Never swallow: handler wrappers must not catch or alter host errors, return values or ordering beyond adding capture. |

Required tests: chaining order, previous handler called exactly once, previous handler throwing propagates, null previous `onError`, restoration after dispose, replaced-handler detection, wrapped-by-others behavior, repeated init, double dispose, multiple controllers sharing one wrapper (T2.8, T4.3).

## 7. Release behavior (D-04)

Effective activity = `config.enabled && !kReleaseMode`, evaluated once at controller creation through an internal build-mode resolver (so tests can simulate modes without changing compile-time constants). When inactive: no store allocation beyond a stub, no console output, no hooks, no UI; the facade and `DebugBubble` behave as no-ops/child-only. Profile and debug are active. No release override exists in 0.1.0. A build-mode check alone is not a guarantee against exposure (misconfigured flavors, custom build flags); see SECURITY_PERFORMANCE.md §2. Whether `kReleaseMode` checks lead to tree-shaking is not claimed.

## 8. State and notifications (D-16, D-18)

`DebugBubbleController extends ChangeNotifier`. The store marks itself dirty; one notification is scheduled per frame (post-frame callback when a binding exists, otherwise a microtask). UI uses `ListenableBuilder`/`AnimatedBuilder` on the controller. No state-management packages.

## 9. Extension points (reserved, not in 0.1.0)

| Version | Extension | Shape (non-binding) |
|---|---|---|
| 0.2.x | `debug_bubble_dio` (separate package) | Calls the public `controller.log(...)` with structured metadata; no new core API expected. |
| 0.3.x | Custom diagnostic sources | A source interface feeding the pipeline. |
| 0.3.x | Storage adapters | Adapter interface behind the store; the 0.1.0 store stays internal. |

## 10. Decision records

Approved or changed decisions are recorded in `doc/decisions/NNNN-title.md` (context, decision, consequences). The register in PROJECT_SPEC.md §5 is the baseline.
