# IMPLEMENTATION_ROADMAP.md — debug_bubble

Status: Draft v0.2 · Depends on: PROJECT_SPEC.md (D-xx), ARCHITECTURE.md (L-xx, E-xx), API_DESIGN.md, TESTING_STRATEGY.md (VERIFY-* sets, UI-xx), AI_WORKFLOW.md

**Estimate:** 17–26 working days for one developer with AI assistance — **unvalidated**, carried over from the original plan. Tasks added in this revision (lifecycle, bounded payloads, hooks, spike, consistency reviews) may push it up; re-estimate at the end of every phase and record the new figure here.

Rules: every task has its own task file (AI_WORKFLOW.md §2); a task is **Done** only when its acceptance criteria are met and its VERIFY-* commands were actually run with output recorded; otherwise it is **Unverified**. "Files" lists expected changes and is refined in the task file.

## Phase overview

| Phase | Name | Est. days (unvalidated) | Depends on | Gate |
|---|---|---|---|---|
| 1 | Foundation | 2–3 | none | G1 |
| 2 | Core Engine | 4–6 | G1 | G2 |
| 3 | Floating UI | 5–7 | G2 | G3 |
| 4 | Hardening | 3–5 | G3 | G4 |
| 5 | Release | 3–5 | G4 | G5 |
| Total | | 17–26 | | |

## Phase 1 — Foundation

| ID | Scope | Depends | Files | Tests | Acceptance | Verify |
|---|---|---|---|---|---|---|
| T1.1 | Package scaffold (`flutter create --template=package`), lints, SDK placeholders (D-15), `example/` skeleton, LICENSE after D-19, `lib/src/version.dart` with `debugBubbleVersion` | — | `pubspec.yaml`, `analysis_options.yaml`, `LICENSE`, `lib/src/version.dart`, `example/` | version-vs-pubspec test | Package analyzes cleanly; version test passes (file path resolution under `flutter test` confirmed) | VERIFY-STATIC, VERIFY-UNIT test/unit/version |
| T1.2 | Owner approvals for D-03, D-04, D-07, D-08, D-14, D-15, D-19; write decision records; update PROJECT_SPEC statuses | — | `doc/decisions/*`, PROJECT_SPEC.md | — | Each pending decision is Confirmed or has a documented default accepted by the owner | doc review |
| T1.3 | CI skeleton (format, analyze, test) | T1.1 | CI config | — | CI runs on a change and passes | VERIFY-ALL |
| T1.4 | Public API stubs: exactly the ten symbols with signatures from API_DESIGN.md, bodies unimplemented/no-op | T1.1, T1.2 | `lib/debug_bubble.dart`, `lib/src/**` stubs | export-surface test (only ten symbols) | Stubs compile; surface matches API_DESIGN.md §1; no `src` type in any public signature | VERIFY-STATIC, VERIFY-UNIT test/unit/api |
| T1.5 | Cross-document consistency review #1 using the checklist in AI_WORKFLOW.md §7 | T1.2 | docs | — | Checklist completed with zero open contradictions; findings recorded | checklist |

**Gate G1:** T1.1–T1.5 done; owner approvals recorded or defaults explicitly accepted; documents consistent; `VERIFY-STATIC` output recorded.

## Phase 2 — Core Engine

| ID | Scope | Depends | Files | Tests | Acceptance | Verify |
|---|---|---|---|---|---|---|
| T2.1 | `DebugLogLevel`, `DebugLogEntry`, `DebugErrorInfo`, `DebugLogFilter`, `toJson` | T1.4 | `lib/src/core/*` | model/level/filter-model tests | Ordering, `isError`, equality by id, `toJson` match DATA_MODELS.md | VERIFY-UNIT test/unit/core |
| T2.2 | Bounded ring-buffer store with `droppedCount`, `errorCount`, snapshot caching | T2.1 | `lib/src/core/debug_log_store.dart` | store tests (D-23 semantics) | Never exceeds `maxEntries`; drop/clear semantics exact | VERIFY-UNIT test/unit/store |
| T2.3 | Redactor: key matching (normalized substring + tokens), value patterns, scan window, fail-closed, release forcing via build-mode seam | T2.1 | `lib/src/core/sanitize/redactor.dart`, `lib/src/utils/build_mode.dart` | redaction suite (SECURITY_PERFORMANCE §3) | All matching rules, false-positive/negative cases, forced-on-in-release pass | VERIFY-UNIT test/unit/redaction |
| T2.4 | **Bounded payload conversion:** budgeted traversal (depth, nodes, items, string/key caps, cycles, throwing `toString()`/iterables), combined entry budget, truncation algorithm | T2.1, T2.3 | `lib/src/core/sanitize/*` | sanitizer suite (TESTING_STRATEGY §2) | Deterministic output; no throw on hostile input; budgets honored; raw objects not retained | VERIFY-UNIT test/unit/sanitize |
| T2.5 | `DebugLogService` pipeline (gates, sanitize, entry creation, fan-out) + console sink with guarded formatting | T2.2, T2.3, T2.4 | `lib/src/core/debug_log_service.dart`, `lib/src/collectors/console_sink.dart` | pipeline tests, sentinel-secret test | Never throws; console and store receive only sanitized entries | VERIFY-UNIT test/unit/service |
| T2.6 | Filter matching and exporters (`exportJson` schema v1, `exportText`, clipboard cap logic) | T2.1, T2.2 | `lib/src/filters/*`, `lib/src/export/*` | filter and export tests | Semantics per DATA_MODELS.md §4, §8, §9 | VERIFY-UNIT test/unit/filters, VERIFY-UNIT test/unit/export |
| T2.7 | **Controller lifecycle and initialization:** `DebugBubbleController`, `DebugLog` facade, default-controller registry, coalesced notifications, dispose/replace semantics | T2.5, T2.6 | `lib/src/core/debug_bubble_controller.dart`, `lib/src/core/debug_log_registry.dart`, `lib/debug_bubble.dart` | lifecycle suite (L-1…L-12) | Every L-rule has a passing test; `removeListener`-after-dispose behavior verified and documented | VERIFY-UNIT test/unit/lifecycle |
| T2.8 | **Global error-handler integration:** `ErrorHookRegistry`, wrappers, restoration, replaced-handler detection | T2.7 | `lib/src/collectors/error_hook_registry.dart` | hook suite (E-1…E-9) | Chaining, restoration, null previous, replaced/wrapped handlers, repeated init, multiple controllers pass; installation safety before binding verified | VERIFY-UNIT test/unit/hooks |
| T2.9 | Benchmark harness skeleton (no results claimed) | T2.5 | `test/performance/*` | harness runs | Scenarios from SECURITY_PERFORMANCE §6 execute; results not committed as claims | `flutter test test/performance` (informational) |
| T2.10 | Consistency review #2 (docs vs. implemented core) | T2.1–T2.9 | docs | — | Checklist done; discrepancies fixed in docs or code via decision record | checklist |

**Gate G2:** T2.1–T2.10 done; `VERIFY-ALL` and `VERIFY-COVERAGE` output recorded; `core/` does not import `ui/`; re-estimate recorded.

## Phase 3 — Floating UI

| ID | Scope | Depends | Files | Tests | Acceptance | Verify |
|---|---|---|---|---|---|---|
| T3.1 | **UI hosting and navigation spike (time-boxed).** Verify hosting in `MaterialApp`, `CupertinoApp`, `WidgetsApp` builders (Material, Overlay, MediaQuery, Localizations, text selection). Evaluate back-handling mechanisms. **Go/no-go:** (a) dashboard renders and text selection works in all three hosts; (b) with dashboard closed, host back behavior is unchanged (verified by tests); (c) with dashboard open, back closes it without popping the host route (Android device/emulator, including gesture navigation). Outcome of (c) negative → ship close-button-only, update D-27 and UI_UX_SPEC.md. Outcome of (a) negative → stop and open a decision record on D-01 | G2 | `lib/src/ui/debug_bubble.dart`, `lib/src/ui/dashboard_host.dart`, decision record | hosting + back integration tests (UI-14, UI-15, UI-17, UI-20) | Written outcome with evidence; D-01/D-27 updated | VERIFY-WIDGET, VERIFY-INTEG |
| T3.2 | Draggable bubble, snap, badge, visibility rules (L-6, L-8) | T3.1 | `lib/src/ui/bubble.dart` | UI-01…UI-03 | Behaves per UI_UX_SPEC §1 | VERIFY-WIDGET |
| T3.3 | Dashboard shell, tabs, close, animations/reduced motion | T3.1 | `lib/src/ui/dashboard.dart` | UI-04, UI-13, UI-18 | Per UI_UX_SPEC §2 | VERIFY-WIDGET |
| T3.4 | Logs/Errors lists, search, level chips, counts line, empty states | T3.3, T2.6 | `lib/src/ui/log_list.dart` | UI-04…UI-07 | Filter semantics match DATA_MODELS §4 | VERIFY-WIDGET |
| T3.5 | Entry detail view (on-demand pretty JSON, truncated notice, selectable text) | T3.4 | `lib/src/ui/entry_detail.dart` | UI-08, UI-17 | Per UI_UX_SPEC §4 | VERIFY-WIDGET |
| T3.6 | Actions: copy entry/all, export JSON (+ `onExport` failures), clear with confirm, clipboard cap, outcome messages | T3.4, T2.7 | `lib/src/ui/actions.dart` | UI-09…UI-12 | Per UI_UX_SPEC §6 incl. independent clipboard/callback failure handling | VERIFY-WIDGET |
| T3.7 | Theme, accessibility, large text, keyboard insets | T3.3 | `lib/src/ui/theme.dart` | UI-16, UI-19, theme tests | Contrast checked manually and recorded | VERIFY-WIDGET |
| T3.8 | Info tab (read-only snapshot; version constant; hook status) | T3.3, T2.8 | `lib/src/ui/info_tab.dart` | Info tests | Shows no log content | VERIFY-WIDGET |
| T3.9 | Example app exercising all features, including enabling `captureUncaughtErrors` | T3.2–T3.8 | `example/` | integration tests | Runs on Android and iOS; notes recorded | VERIFY-INTEG |
| T3.10 | Consistency review #3 | T3.1–T3.9 | docs | — | Checklist done | checklist |

**Gate G3:** T3.1 outcome recorded; widget and integration tests executed and passing (output recorded); manual device notes recorded; no known blocking UI defects; re-estimate recorded.

## Phase 4 — Hardening

| ID | Scope | Depends | Files | Tests | Acceptance | Verify |
|---|---|---|---|---|---|---|
| T4.1 | **Redaction testing and security review:** sentinel-secret tests across all outputs, property/fuzz tests, scan-window edge review | G3 | `test/unit/redaction/*`, review notes | fuzz + sentinel | No sentinel in any output; findings triaged | VERIFY-UNIT test/unit/redaction |
| T4.2 | **Performance measurement** per SECURITY_PERFORMANCE §6; record real figures with device/mode/date; propose thresholds | G3 | `test/performance/*`, results note | benchmarks | Results recorded as measured; limits revisited if warranted via decision record | benchmark run (profile) |
| T4.3 | Lifecycle and handler verification on devices incl. hot restart (R-11) | G3 | task notes, tests | lifecycle/integration | L-9 and E-5/E-6 behavior confirmed or docs corrected | VERIFY-INTEG |
| T4.4 | **Release-mode verification** (built release and profile example apps) | G3 | task notes | release checks | Release inert; profile active as documented | VERIFY-BUILD + manual checklist |
| T4.5 | Compatibility verification: SDK floor and platform matrix; clipboard limits (R-15) | G3 | `pubspec.yaml`, README notes | build/test per version | Only verified versions/platforms stated | VERIFY-ALL per version |
| T4.6 | Complete CI (format, analyze, tests, example build) | T4.1–T4.5 | CI config | — | CI green on a change | VERIFY-ALL |
| T4.7 | Consistency review #4 | T4.1–T4.6 | docs | — | Checklist done | checklist |

**Gate G4:** all hardening results recorded; performance figures are measurements (not targets); compatibility statement lists only verified items; open defects triaged; re-estimate recorded.

## Phase 5 — Release

| ID | Scope | Depends | Files | Tests | Acceptance | Verify |
|---|---|---|---|---|---|---|
| T5.1 | README: install, integration, config, build-mode behavior, redaction limits, error-hook ordering, no unmeasured claims | G4 | `README.md` | README code samples compiled in `example/` | Samples compile and run | VERIFY-STATIC |
| T5.2 | Dartdoc for all public symbols | G4 | `lib/**` | — | `dart doc` has no warnings for public API (output recorded) | `dart doc` |
| T5.3 | CHANGELOG and version `0.1.0` (version constant and pubspec in sync) | T5.1 | `CHANGELOG.md`, `pubspec.yaml`, `lib/src/version.dart` | version test | Version test passes | VERIFY-UNIT test/unit/version |
| T5.4 | Finalize example app | G4 | `example/` | integration | Works per README | VERIFY-INTEG |
| T5.5 | **Documentation and publish validation:** dry-run, package score review where available | T5.1–T5.4 | — | — | Dry-run succeeds (output recorded); license confirmed | VERIFY-PUBLISH |
| T5.6 | Final consistency review and release checklist; owner decides whether to publish | T5.5 | docs | — | Checklist clean; every DoD item evidenced | checklist |

**Gate G5:** PROJECT_SPEC §10 fully evidenced; no pending decision remains; `VERIFY-ALL`, `VERIFY-INTEG`, `VERIFY-BUILD`, `VERIFY-PUBLISH` outputs recorded.

## After 0.1.0

- 0.2.x: `debug_bubble_dio` (separate package, D-07) with its own roadmap, tests and security review.
- 0.3.x: diagnostic sources and storage adapters.
- 1.0.0: API freeze, complete documentation, verified compatibility.

Nothing is scheduled until 0.1.0 ships.

## Risk-to-task map

R-06/R-16/R-18 → T3.1 · R-08/R-20 → T2.8, T4.3 · R-09/R-17 → T2.4, T2.9, T4.2 · R-11 → T4.3 · R-14 → T4.5 · R-15 → T3.6, T4.5 · R-19 → T1.1, T5.3.
