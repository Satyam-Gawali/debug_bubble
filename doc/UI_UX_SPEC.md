# UI_UX_SPEC.md — debug_bubble

Status: Draft v0.2 · Depends on: ARCHITECTURE.md (§4 hosting, L-6, L-8), DATA_MODELS.md, API_DESIGN.md, PROJECT_SPEC.md (D-01, D-17, D-26, D-27) · Dimensions are proposals to validate in the example app. Every requirement below is written to be testable (widget or integration test, or a named manual check).

## 1. Floating bubble

| Aspect | Spec |
|---|---|
| Size | 56 logical px circle; touch target ≥ 48 px |
| Initial position | `config.initialBubbleAlignment` (default center-right) |
| Drag | Free drag within the safe area; on release it snaps to the nearest horizontal edge |
| Tap | Opens the dashboard |
| Badge | `controller.errorCount` (error/critical entries **currently stored**); "99+" above 99; hidden at 0. Decreases when entries are evicted or cleared |
| Visibility | Hidden while the dashboard is open; not built when the controller is inert, disposed or absent (child only, L-6, L-8) |
| Keyboard | Stays within the visible area: position is constrained by `MediaQuery` view insets/padding |
| Rotation/resize | Position stored as a fractional alignment so it survives rotation and window changes |
| Semantics | Label "Open debug dashboard"; error count included in the label |
| Gestures | Must not block taps on host content outside the bubble's own bounds |

Position lives only as long as the controller (D-13).

## 2. Dashboard container and navigation

- Full-screen layer inside `DebugBubble` (D-01), respecting safe areas; draws its own `Material`, theme and a nested `Overlay` (ARCHITECTURE.md §4).
- Top bar: title, search toggle, overflow menu (Copy all, Export JSON, Clear all), close button. Tabs: **Logs · Errors · Info** (D-10), Errors tab shows the error badge.
- **Close:** the on-screen close button always works.
- **Back (D-27, unresolved):** intended behavior is that system back closes the detail view first, then the dashboard, and never exits or navigates the host app while the dashboard is open; with the dashboard closed `DebugBubble` never consumes or alters back events. The mechanism is decided by the T3.1 spike (go/no-go in IMPLEMENTATION_ROADMAP.md). If no safe mechanism is found, 0.1.0 ships with close-button-only dismissal and documents that back affects the host app.
- Animation: short fade/slide; disabled or instant when `MediaQuery.disableAnimationsOf(context)` is true.
- Keyboard: when a text field is focused the layer resizes above the keyboard (uses view insets); lists remain scrollable; the detail view's selectable text keeps its selection toolbar working inside the nested `Overlay` (verified in T3.1/T3.5).

## 3. Logs and Errors tabs

- **List:** `ListView.builder`; oldest at top, newest at bottom; auto-scrolls to the latest entry while the user is at the bottom; scrolling up pauses auto-scroll and shows "Jump to latest".
- **Row:** level indicator (color **and** text/icon), local time `HH:mm:ss.SSS`, tag/subTag chip, message limited to two lines, error icon when `error != null`, "truncated" marker when `truncated`.
- **Search:** field with 250 ms debounce; semantics exactly `DebugLogFilter.query` (message, tag, subTag, error type/message; not stack trace or payload — DATA_MODELS.md §4). Clear (×) button.
- **Severity filters:** one chip per level, multi-select, exact-level semantics (not minimum); none selected = all. "Reset filters" appears when any filter is active.
- **Errors tab:** same list pre-filtered to `error` and `critical` (including uncaught entries); the level chips offer only those two.
- **Counts line:** "Showing X of Y" (Y = `entryCount`); if `droppedCount > 0` it adds "· D older entries dropped".
- **Empty states:** "No logs yet" (store empty); "No matches for current filters" with a reset action.

## 4. Entry details

Opened by tapping a row, shown inside the dashboard layer (not via the host Navigator).

Sections (only when data exists): header (level, UTC timestamp, tag/subTag, id) · message · error (type, message) · stack trace (monospace, horizontal scroll) · metadata (key/value) · JSON (pretty-printed on demand from the sanitized value, collapsible when long) · "Some content was truncated" notice when `truncated`. All text selectable.

Actions: **Copy entry** (plain text, DATA_MODELS.md §9), **Copy JSON** (this entry as JSON). Back/close returns to the list. Previous/next navigation is post-0.1.0.

## 5. Info tab

Read-only session snapshot (DATA_MODELS.md §10): package version, build mode, active flag, limits, entry count, `droppedCount`, per-level counts, console on/off, uncaught capture `off | active | inactive (handler replaced)`, redaction on/off and pattern count. Contains no log content and no pattern text.

## 6. Actions: copy, export, clear (D-26)

| Action | Scope | Output | Behavior |
|---|---|---|---|
| Copy entry | Open entry | Plain text | Clipboard; message "Copied". |
| Copy all | Entries matching the **current filters** (all if none) | Plain text (`exportText`) | Clipboard; message "Copied N entries". If text would exceed 500,000 chars the oldest selected entries are omitted and the header says how many; the message says "Copied N of M entries (oldest omitted)". |
| Export JSON | Entries matching the current filters | Versioned JSON (`exportJson`, schema v1) | 1) Build JSON. 2) Copy to clipboard unless it exceeds 500,000 chars (then message "Too large to copy — narrow filters or use the export callback"). 3) If `onExport` is set, call it (awaited if it returns a `Future`). Steps 2 and 3 are independent. |
| Clear all | **Entire store** (filters do not limit it) | — | Confirmation dialog "Clear all N entries? This cannot be undone."; then `controller.clear()` (resets badge and `droppedCount`). |

Callback and clipboard failures:
- If `onExport` throws or its future fails, the exception is caught; the UI shows "Export callback failed (ExceptionType)" — type name only, no message text — and the dashboard stays usable. The exception is not rethrown.
- A clipboard failure is reported as "Copy failed"; export callback still runs.
- Outcome messages are short, drawn by the dashboard layer itself (no `ScaffoldMessenger` or host `Navigator` required), and exposed via semantics for screen readers.
- Programmatic `controller.clear()` has no confirmation; only the UI asks.

## 7. Theming (D-17)

`DebugBubbleTheme(mode, bubbleColor, bubbleIconColor, levelColors)`; `ThemeMode.system` follows platform brightness. The dashboard does not inherit the host theme, so it stays readable regardless of host styling. Built-in palettes are checked for contrast manually in T3.7; no accessibility claim is made before that.

## 8. Accessibility and i18n

- Touch targets ≥ 48 px; semantic labels on bubble, tabs, chips, actions and outcome messages.
- Level conveyed by text/icon, not color alone.
- Large text scales do not cause overflow (widget tests with scaled `MediaQuery`).
- Reduced motion honored (§2).
- English-only strings in 0.1.0, centralized for later localization.

## 9. UI performance expectations

Virtualized list; cheap row widgets (const where possible); filtered results cached until snapshot or filter changes; updates coalesced to one per frame (D-18); pretty JSON generated only for the open detail view. Numeric budgets are set after T4.2 measurements, not assumed.

## 10. Testable requirements index

UI-01 bubble drag/snap · UI-02 badge equals `errorCount` · UI-03 hidden when inactive/disposed/absent · UI-04 tabs and Errors pre-filter · UI-05 search semantics · UI-06 level chips exact match · UI-07 counts line incl. dropped · UI-08 details sections and truncated notice · UI-09 copy entry · UI-10 copy all (filtered, cap behavior) · UI-11 export (clipboard + callback, independent failure handling) · UI-12 clear confirm and reset · UI-13 close button · UI-14 back behavior per T3.1 outcome · UI-15 host back unaffected when closed · UI-16 keyboard inset handling · UI-17 text selection in nested Overlay · UI-18 reduced motion · UI-19 large text scale · UI-20 hosting inside `MaterialApp.builder`. Mapped to tests in TESTING_STRATEGY.md §3.
