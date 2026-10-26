# Decision Record: 0003 — Re-initialization Semantics (D-03)

- **Status:** Confirmed (Approved by project owner on 2026-10-26)
- **Deciders:** Project Owner
- **Related Requirements:** L-3, L-6, L-9, D-03

## Context
When `DebugLog.init()` is invoked while a default controller already exists, the package needs clear, deterministic behavior regarding the previous controller instance and any widgets/listeners that were observing it.

## Decision
Option A (Replace) is approved:
- `DebugLog.init()` disposes the previous default controller and creates a new one.
- `DebugLog` maintains an internal notifier (`defaultControllerNotifier`) that signals controller changes.
- Widgets following the default controller (e.g. `DebugBubble()`) automatically rebind to the new default controller without throwing or leaking references to the disposed controller.

## Consequences
- Clean support for hot restarts and configuration changes.
- Widgets never crash when listening to a replaced controller.
- Idempotent and deterministic lifecycle contract (L-1..L-12).
