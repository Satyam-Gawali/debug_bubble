# Decision Record: 0008 — Uncaught-Error Capture Default (D-08)

- **Status:** Confirmed (Approved by project owner on 2026-10-26)
- **Deciders:** Project Owner
- **Related Requirements:** FR-05, D-08, E-1..E-9

## Context
Capturing uncaught Flutter and platform errors requires hooking into `FlutterError.onError` and `PlatformDispatcher.instance.onError`. Global hooks can interact or conflict with crash reporting tools such as Firebase Crashlytics and Sentry.

## Decision
Opt-in default approved:
- `DebugBubbleConfig.captureUncaughtErrors` defaults to `false`.
- When enabled by the host app, errors are intercepted inside a process-wide `ErrorHookRegistry`.
- Existing error handlers are chained and never swallowed. Previous handlers are always invoked.
- When all active controllers are disposed, previous handlers are safely restored.

## Consequences
- Zero invasive behavior by default; host error reporting tools remain undisturbed unless the developer explicitly opts in.
- Chaining contract (E-1..E-9) guarantees that enabling error capture does not suppress host error reporting or alter crash reporting pipelines.
