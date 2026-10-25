# PROJECT_SPEC.md — debug_bubble

Status: Draft v0.2 (revision of v0.1) · Date: 2026-10-25 · **Source of truth for scope and the Decision Register (D-xx).** All other documents cite these IDs and must agree with them.

No decision below has been formally approved by the owner yet. Nothing has been implemented, tested or measured.

## 0. Status legend

| Status | Meaning |
|---|---|
| Confirmed | Approved by the owner. (None yet.) |
| Proposed default | Recommended and used consistently by all documents; the owner may override. |
| Pending approval | Needs an owner decision before gate G1. A recommended default is shown; options are in §6. |
| Unresolved | Cannot be decided without a spike or measurement; owning task named. |

## 1. Project assessment

`debug_bubble` is a Flutter debugging toolkit: a floating, draggable bubble that opens an in-app dashboard with logs, errors, stack traces and structured JSON.

- **Feasibility:** achievable for one developer with AI assistance; no native code and no third-party runtime dependencies are required.
- **Hardest part:** hosting UI from `MaterialApp.builder`, which sits above the `Navigator`, including back-button behavior (D-01, D-27, T3.1 spike).
- **Highest-risk parts:** (1) redaction and payload conversion on untrusted, arbitrary objects (D-05, D-21, D-28); (2) global error-handler interaction with other tools (D-08); (3) accidental exposure outside debug builds (D-04).
- **Effort estimate:** 17–26 working days, carried over from the original plan. **Unvalidated.** Re-estimate at every phase gate; tasks added in this revision may extend it.
- **Reference code:** YoDoctor `AppLogger` is a design reference only. No YoDoctor imports or architecture are carried over.

## 2. Vision, goals, non-goals

**Vision:** an integrated in-app debugging experience, not just a logger.

**Goals (0.1.0):** reusable, minimal dependencies, inert in release builds, bounded memory and CPU per entry, independently testable, non-throwing toward host code.

**Non-goals (0.1.0):** network inspection, persistence, remote log shipping, native crash reporting, performance profiling, section/highlight console helpers (D-12), logs from other isolates, a pre-initialization log buffer (D-24).

## 3. Target users

Flutter developers and QA testers who want to inspect app behavior on a device without a debugger or the IDE console.

## 4. Requirements (MVP, 0.1.0)

| ID | Requirement |
|---|---|
| FR-01 | Logging API: six levels (debug, info, success, warning, error, critical), tag, subTag, metadata, error object, stack trace, JSON payload. |
| FR-02 | Immutable, sanitized structured log entries (`DATA_MODELS.md`). |
| FR-03 | Bounded in-memory store: entry-count bound with oldest-first eviction, plus a per-entry retained-size budget (D-06, D-21, D-23). |
| FR-04 | Console output and dashboard collection from one pipeline. |
| FR-05 | Capture and inspect exceptions and stack traces from explicit log calls; optional, opt-in capture of uncaught Flutter/platform errors (D-08). |
| FR-06 | Pretty JSON viewing of sanitized payloads. |
| FR-07 | Floating, draggable bubble. |
| FR-08 | Dashboard with Logs / Errors / Info tabs, search, severity filters, entry details. |
| FR-09 | Copy entry, copy all/filtered (plain text), export filtered entries (versioned JSON), clear (with confirmation) (D-26). |
| FR-10 | Theme and configuration options. |
| FR-11 | Inert in release builds; redaction on ingestion with documented limits (D-04, D-05, D-28). |
| FR-12 | Unit, widget, integration and performance tests (`TESTING_STRATEGY.md`). |

| ID | Non-functional requirement |
|---|---|
| NFR-01 | Core runtime depends only on the Flutter SDK (D-07). |
| NFR-02 | Memory and CPU per entry are bounded by explicit limits (D-06, D-21); no exact memory figure is claimed without measurement. |
| NFR-03 | Logging never throws into host code; internal failures fail closed (sensitive content is dropped, not shown). |
| NFR-04 | One unambiguous lifecycle contract (L-1…L-12 in `ARCHITECTURE.md`). |
| NFR-05 | Small public API: exactly the ten symbols in `API_DESIGN.md` §1; all else lives in `lib/src/`. |
| NFR-06 | Performance numbers are targets until measured in T4.2; none are claimed. |
| NFR-07 | The host app's error handling and navigation behavior must not be changed (D-08, D-27). |

## 5. Decision Register

Numeric values are **proposed defaults, not measured facts**. All limits are in UTF-16 code units (Dart `String.length`) unless stated; none are in bytes.

| ID | Decision | Status | Recommended default (summary) |
|---|---|---|---|
| D-01 | Dashboard hosting | Proposed default; feasibility unverified (T3.1) | In-tree layer inside `DebugBubble`'s own `Stack`; no `Navigator`/`showDialog`; nested `Overlay` for text selection. |
| D-02 | Integration point | Proposed default | `MaterialApp(builder: (c, child) => DebugBubble(child: child ?? const SizedBox.shrink()))`. |
| D-03 | Lifecycle and ownership | **Pending approval** (re-`init` semantics) | Contract L-1…L-12: one default controller owned by `DebugLog`; `init` replaces and disposes the previous default; widgets never dispose. |
| D-04 | Build-mode policy | **Pending approval** | Inert in release with **no release override in 0.1.0**; active in debug and profile; `enabled` can only switch the package off. |
| D-05 | Redaction | Proposed default | At ingestion, before store/console/export; fail-closed; cannot be disabled in release; never described as guaranteed. |
| D-06 | Entry-count bound | Proposed default | Ring buffer, `maxEntries` = 1,000. |
| D-07 | Dependencies | **Pending approval** (Dio split); core deps proposed | Core: Flutter SDK only. Dio integration = separate package `debug_bubble_dio` in 0.2.x. |
| D-08 | Uncaught-error capture | **Pending approval** | **Opt-in** (`captureUncaughtErrors` default `false`); single process-wide hook registry; chain, never swallow, restore when safe. |
| D-09 | *(Superseded by D-26 — export/copy/callback semantics)* | Superseded | See D-26. |
| D-10 | Info tab | Proposed default | Read-only session snapshot incl. package version from a constant (D-25); no log content. |
| D-11 | Level ordering | Proposed default | `debug(0) < info(1) < success(2) < warning(3) < error(4) < critical(5)`; `minLevel` gate uses this order. |
| D-12 | Section/highlight helpers | Proposed default | Deferred beyond 0.1.0. |
| D-13 | Persistence | Proposed default | None in 0.1.x; adapters in 0.3.x. |
| D-14 | Platform support | **Pending approval**; verification in T4.5 | Android and iOS validated in the example; others best-effort and unverified. |
| D-15 | SDK constraints | **Pending approval**; resolved in T1.1/T4.5 | Placeholder = current stable at T1.1; lowest supported version only after build verification. |
| D-16 | State management | Proposed default | `DebugBubbleController extends ChangeNotifier`; no state-management packages. |
| D-17 | Theme | Proposed default | `DebugBubbleTheme` with `ThemeMode` (default `system`). |
| D-18 | Notification rate | Proposed default | Listener notifications coalesced to at most one per frame (fallback: one per microtask when no binding). |
| D-19 | License | **Pending approval** | MIT (assumption). |
| D-20 | JSON conversion | Proposed default | Single budgeted traversal; never throws; valid JSON structure always preserved. |
| D-21 | Per-entry payload budget | Proposed default | `maxEntryChars` = 40,000 combined; `maxMessageLength` = 8,000; `maxStackTraceLength` = 16,000; `maxPayloadLength` = 32,000 shared by metadata then json; internal caps: depth 8, 2,000 nodes, 200 items per collection, 2,000 chars per string value, 100 chars per tag/subTag. Retention priority: tag/subTag → message → error → stack trace → metadata → json. |
| D-22 | Raw payload non-retention | Proposed default | Raw objects are never retained; one sanitized structure per entry; no cached pretty-JSON string; search excludes payload and stack trace. |
| D-23 | `droppedCount` | Proposed default | Number of entries **evicted by capacity** since controller creation or last `clear()`. Gate rejections and truncation do not count. |
| D-24 | Logs before `init` | Proposed default | Silent no-op; no pre-init buffer (config is needed for redaction/limits; buffering would retain unsanitized data). Call `init` first in `main()`. |
| D-25 | Package version | Proposed default | `const String debugBubbleVersion` in `lib/src/version.dart`, verified equal to `pubspec.yaml` by a unit test; no runtime dependency. |
| D-26 | UI action semantics | Proposed default | Copy entry (text), Copy all/filtered (text), Export JSON (versioned JSON; clipboard + optional `onExport`; callback failure reported, never thrown), Clear (confirm). Clipboard cap 500,000 chars (internal). |
| D-27 | Back-button handling | **Unresolved** (T3.1 spike) | Intended: back closes the dashboard when open and never consumes back when closed. Mechanism unverified; fallback = on-screen close only. |
| D-28 | Redaction matching | Proposed default | Normalized-key substring set + whole-token set; optional value patterns; redact before truncate on a bounded scan window; pattern failure → field replaced. |

## 6. Decisions needing owner approval (options and trade-offs)

**D-03 — `DebugLog.init` called while a default controller exists.**
- A (recommended): replace — dispose the old default, create a new one, print a debug-only notice. Hot-restart friendly, deterministic; any widget following the default rebinds.
- B: ignore the new call and return the existing controller. No surprise disposal, but a changed config is silently ignored.
- C: throw `StateError`. Loud, but breaks hot-restart-style flows and test setups.

**D-04 — Release builds.**
- A (recommended): inert in release; no override in 0.1.0. Safest; QA on release-like builds is not supported.
- B: allow `enabled: true` in release. Convenient, but one misconfigured flavor exposes logs and a UI; a build-mode check alone does not guarantee that sensitive data cannot be exposed.
- C: a separate explicit `allowInRelease: true` flag plus a visible dashboard banner. Possible post-0.1.0 if there is demand; requires its own security review.
- Profile mode: recommended active (needed for T4.2 measurements; profile builds are not intended for distribution). Alternative: debug only.
- In all cases redaction cannot be disabled when `kReleaseMode` is true (defense in depth).

**D-07 — Dio integration.** Recommended: separate `debug_bubble_dio` package (core never depends on Dio; two packages to maintain). Alternative: optional sub-library in core (still adds a Dio dependency to the package graph).

**D-08 — Uncaught-error capture default.** Recommended `false`: touching global handlers is invasive and interacts with Crashlytics/Sentry. Alternative `true`: better out-of-box discoverability. Either way handlers are chained, host behavior is unchanged, and the example app enables it.

**D-14/D-15 — Platforms and SDK floor.** Recommended: claim only what T4.5 verifies; until then constraints are placeholders.

**D-19 — License.** MIT assumed; confirm before T5.5.

**D-07/D-10 are otherwise proposed defaults**; D-10 (Info tab includes the version constant) can be reverted without API impact.

## 7. Ambiguities, conflicts and risks

| ID | Item | Resolution / owner task |
|---|---|---|
| R-01 | "Info view" undefined | D-10 (resolved as proposed default). |
| R-02 | `DebugLogService` in architecture vs API | Internal only (D-03). |
| R-03 | Section/highlight helpers | Deferred (D-12). |
| R-04 | Dio packaging | D-07 (pending). |
| R-05 | Export needs file/share access | D-26: clipboard + `onExport`. |
| R-06 | Hosting above `Navigator` | D-01; spike T3.1. |
| R-07 | Redaction timing | D-05: ingestion. |
| R-08 | Handler conflicts with Crashlytics/Sentry/others | D-08, E-1…E-9 in `ARCHITECTURE.md`; tests T2.8, T4.3. |
| R-09 | Log bursts and large payloads | D-18, D-21; benchmark T4.2. |
| R-10 | Facade used before init | D-24 / L-4. |
| R-11 | Hot restart behavior of static state and platform hooks is **unverified** | T4.3 on device. |
| R-12 | Estimate unvalidated | Re-estimate at gates. |
| R-13 | Profile mode active by default | D-04 (pending). |
| R-14 | SDK/platform floor unknown | D-14, D-15; T4.5. |
| R-15 | Platform clipboard size limits vary and are **unverified** | 500,000-char cap is a placeholder; verify T3.6/T4.5. |
| R-16 | Back-button interception above the Navigator may not take priority over host routes | D-27; T3.1 go/no-go. |
| R-17 | Custom `toString()` or user-supplied regex can be slow; cannot be preempted | Bounded inputs, documented limitation; T4.1/T4.2. |
| R-18 | Ancestors available at `MaterialApp.builder` (Localizations, MediaQuery, Directionality) assumed, not verified | T3.1. |
| R-19 | Version constant can drift from `pubspec.yaml` | Unit test (D-25). |
| R-20 | Other libraries replacing error handlers after `init` | Detected and shown in Info tab; documented (E-6). |

## 8. Documentation structure

```
debug_bubble/
├── README.md
├── CHANGELOG.md
└── doc/
    ├── PROJECT_SPEC.md             # scope, decision register, risks (this file)
    ├── ARCHITECTURE.md             # modules, lifecycle contract L-xx, error hooks E-xx
    ├── API_DESIGN.md               # exact public signatures
    ├── DATA_MODELS.md              # entry, filter, store, export schema
    ├── UI_UX_SPEC.md
    ├── SECURITY_PERFORMANCE.md
    ├── IMPLEMENTATION_ROADMAP.md
    ├── TESTING_STRATEGY.md
    ├── AI_WORKFLOW.md              # includes the consistency checklist
    ├── decisions/                  # NNNN-title.md, one per approved/changed decision
    └── tasks/                      # T<phase>.<n>-slug.md task files with recorded results
```

Reading order: PROJECT_SPEC → ARCHITECTURE → DATA_MODELS → API_DESIGN → SECURITY_PERFORMANCE → UI_UX_SPEC → TESTING_STRATEGY → IMPLEMENTATION_ROADMAP → AI_WORKFLOW.

## 9. Version scope

| Version | Scope |
|---|---|
| 0.1.0 | FR-01…FR-12 |
| 0.2.x | Separate `debug_bubble_dio` (D-07): request/response metadata, timing, errors, header/body redaction |
| 0.3.x | Custom diagnostic sources, optional storage adapters, extra runtime diagnostics |
| 1.0.0 | Stable API, complete documentation, verified compatibility |

0.1.0 excludes network inspection, persistent storage, remote logging and native crash reporting. A version ships only when its acceptance gate passes.

## 10. Definition of Done (0.1.0)

- Core logger, lifecycle contract and data models implemented.
- Bubble and dashboard working, including actions in D-26.
- Search, filters, details, copy and export tested.
- Memory/payload limits, lifecycle and error-handler chaining/restoration verified by executed tests.
- Redaction tested, with limitations documented.
- Release-mode (inert) behavior verified on built release and profile apps and documented.
- Automated tests and static analysis executed and passing, with results recorded in task files.
- Performance measured (T4.2) and compatibility matrix recorded (T4.5); no unmeasured claims in docs.
- Example app and documentation complete; cross-document consistency check passed.
- `flutter pub publish --dry-run` succeeds.
- The package is not described as pub.dev-ready until every item above is evidenced.

## 11. Change record (v0.1 → v0.2)

Lifecycle contract rewritten (D-03, D-24); release policy tightened (D-04); error capture made opt-in with a hook registry (D-08); payload budget, traversal caps and non-retention added (D-21, D-22); `droppedCount` defined (D-23); version constant added (D-25); UI action semantics defined (D-26); back handling marked unresolved (D-27); redaction matching rewritten (D-28); controller changed to `ChangeNotifier` (D-16); new risks R-15…R-20; statuses introduced for every decision.
