# TESTING_STRATEGY.md — debug_bubble

Status: Draft v0.2 · Depends on: PROJECT_SPEC.md, ARCHITECTURE.md (L-xx, E-xx), DATA_MODELS.md, UI_UX_SPEC.md (UI-xx), SECURITY_PERFORMANCE.md, IMPLEMENTATION_ROADMAP.md

Rule: a test counts as passing only when it was actually run and its output is recorded in the task file or CI log. This document contains no results.

## 1. Layers

| Layer | Location | Purpose |
|---|---|---|
| Unit | `test/unit/` | Pure logic: models, store, sanitizer, redactor, filters, exporters, service, controller, registry, hook collector |
| Widget | `test/widget/` | Bubble, dashboard, lists, filters, details, actions, theme, accessibility |
| Integration | `test/integration/`, `example/integration_test/` | Hosting in `MaterialApp.builder`, end-to-end flows, error hooks, lifecycle |
| Performance | `test/performance/` | Benchmarks (T2.9 harness, T4.2 measurements); informational until baselines exist |
| Manual/device | task files | Hot restart, release/profile builds, platform clipboard, back button (results recorded with date/device) |

## 2. Unit tests

**Models/levels:** construction, `toJson`, ordering (`debug<info<success<warning<error<critical`), `isError`, `minLevel` gate including that `warning` drops `success`.

**Store (D-23):** never exceeds `maxEntries`; oldest-first eviction; `droppedCount` counts only evictions; gate rejections and truncation do not change it; `clear()` resets `droppedCount` but not the id counter; `errorCount` tracks evictions; snapshot immutability and caching.

**Sanitizer/payload budget (D-20, D-21, D-22):**
- Each cap at boundaries (limit−1, limit, limit+1): message, stack, tag/subTag, error type, payload, `maxEntryChars`.
- Retention priority: when the combined budget is exceeded, later fields (json before metadata before stack…) lose first; deterministic output for identical input.
- Metadata and json share `maxPayloadLength` (metadata first).
- Depth 9 → `[MaxDepth]`; self-referencing map/list → `[Circular]`; node cap; 200-item cap for map, list and an infinite generator; iterable that throws mid-way → partial + `[IterationError: …]`; throwing `toString()` → `[Unprintable: …]`; non-finite numbers; `DateTime`; surrogate pairs not split by truncation; `truncated` flag semantics; raw objects not retained (mutating the source after logging does not change the entry).

**Redaction (D-28):** case variations (`Password`, `API_KEY`, `accessToken`, `x-auth-token`, `Set-Cookie`); nested maps and maps inside lists; token-only terms (`pin` redacted, `shipping` not); documented false positives and false negatives asserted as such; value patterns on message, error text, stack, tag/subTag, string values; redact-before-truncate and the scan-window edge; pattern that throws → `[REDACTION_ERROR]`; custom sets and replacement; redaction cannot be disabled when the simulated build mode is release; sentinel secret never appears in the store, console output, `exportJson`, `exportText`, or `toString`.

**Service/controller/facade (L-1…L-12, D-24):** facade before init, after dispose, and with an inert controller → no-op without throwing; `init` replaces and disposes the previous default; double `init`/`dispose`; standalone controller does not receive facade calls; ownership (a `DebugBubble` never disposes a controller); disposed controller getters/`query`/exports are safe; listener notified once on dispose; coalesced notifications (many logs → one notification per frame/microtask); never throws when console sink or any conversion throws; inert in simulated release; `enabled: false`; `minLevel`.

**Error hooks (E-1…E-9):** previous `FlutterError.onError` called exactly once and after capture; previous handler that throws propagates; null previous `PlatformDispatcher.onError` handled; wrapper never returns `true` by itself; restoration after last dispose; replaced-handler detection (`inactive (handler replaced)`); wrapped-by-another-library keeps capturing; multiple controllers share one wrapper pair; repeated `init` does not stack wrappers; capture off by default installs nothing; entries flagged `isUncaught` with levels `error`/`critical`.

**Filters/exporters:** exact-level semantics; empty/whitespace query; case-insensitive query over message/tag/subTag/error only (not stack/payload); exact tag; AND combination; export schema v1 (all fields, `exportedEntries`, `totalEntries`, `droppedCount`, `redaction`, `limits`, `packageVersion`); `exportText` header and the 500,000-char cap behavior.

**Version (D-25):** `debugBubbleVersion` equals the version in `pubspec.yaml` (test reads the file; path resolution under `flutter test` verified in T1.1).

## 3. Widget tests (mapped to UI-xx)

UI-01 drag/snap · UI-02 badge = `errorCount` (incl. after eviction/clear) · UI-03 hidden when inactive, disposed or no controller (child only) · UI-04 tabs, Errors pre-filter · UI-05 search · UI-06 level chips · UI-07 counts line and dropped notice · UI-08 details sections, truncated notice · UI-09 copy entry (clipboard mocked) · UI-10 copy all with filters and cap · UI-11 export: clipboard and callback independent; throwing sync/async callback shows "Export callback failed (Type)" and does not throw; clipboard failure message · UI-12 clear confirmation, cancel keeps data, confirm clears and resets badge · UI-13 close button · UI-16 keyboard insets · UI-17 text selection with nested Overlay · UI-18 reduced motion · UI-19 large text scale · theme light/dark/system · Info tab shows no log content and shows status `off|active|inactive (handler replaced)`.

## 4. Integration tests

1. **UI-20 hosting:** dashboard opens from `MaterialApp.builder` without a host `Navigator` dependency; also with `CupertinoApp`/`WidgetsApp` builder (T3.1).
2. **UI-14/UI-15 back behavior** per the T3.1 outcome: with a host `Navigator` that has pushed routes — dashboard closed: back pops the host route exactly as without the package; dashboard open: behavior per decision (close dashboard without popping the host route, or documented fallback).
3. End to end: log → store → dashboard → filter → export.
4. Uncaught error captured with capture enabled, host handler still invoked.
5. Lifecycle: `init`→`dispose`→`init`, handler restoration, no duplicate entries.
6. Release/profile (T4.4): built example apps checked for inert behavior (no bubble, no console output from the package) — automated where tooling allows, otherwise a dated manual checklist.

## 5. Manual/device checks (recorded, not assumed)

Hot restart with hooks enabled (R-11); Android and iOS clipboard behavior with large text (R-15); back button on Android incl. gesture navigation (D-27); text selection handles inside the dashboard; keyboard behavior; reduced-motion setting.

## 6. Performance tests (T2.9 harness, T4.2 results)

Scenarios in SECURITY_PERFORMANCE.md §6. Record device, OS, Flutter/Dart version, build mode (profile), date, iteration counts. Thresholds only after a baseline exists.

## 7. Verification command sets (named; roadmap tasks reference these)

```
VERIFY-STATIC   : dart format --output=none --set-exit-if-changed .
                  flutter analyze
VERIFY-UNIT <p> : flutter test <p>                      # e.g. test/unit/sanitize
VERIFY-WIDGET   : flutter test test/widget
VERIFY-ALL      : VERIFY-STATIC && flutter test
VERIFY-COVERAGE : flutter test --coverage
VERIFY-INTEG    : (cd example && flutter test integration_test -d <device>)
VERIFY-BUILD    : (cd example && flutter build apk --profile && flutter build apk --release)   # + iOS equivalent when available
VERIFY-PUBLISH  : flutter pub publish --dry-run
```

Command output (or a link to the CI log), date and environment are pasted into the task file. If a command could not be run, the task is marked **Unverified**, never Done.

## 8. Quality gates

| Gate | Requirement |
|---|---|
| G1 | Documents consistent; owner approvals recorded; `VERIFY-STATIC` on scaffold |
| G2 | Unit tests for T2.x executed and passing; lifecycle, hooks, redaction, budget tests present; `VERIFY-ALL` recorded |
| G3 | Widget and integration tests executed; T3.1 outcome recorded; manual device notes recorded |
| G4 | Redaction fuzz/sentinel tests, lifecycle/hot-restart, release-mode builds, performance measurements, compatibility matrix — all recorded |
| G5 | `VERIFY-ALL`, `VERIFY-INTEG`, `VERIFY-BUILD`, `VERIFY-PUBLISH` recorded; consistency check passed |

Coverage: `VERIFY-COVERAGE` is run at G2/G4; a numeric target for `core/`, `collectors/`, `filters/`, `export/` is proposed at G2 (e.g. 90%) and treated as an indicator, not a goal.

## 9. CI

CI runs `VERIFY-STATIC` and the unit/widget suites on every change; example builds are added in T4.6. Flaky tests are fixed or quarantined with a tracked issue, never ignored.
