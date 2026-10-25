# SECURITY_PERFORMANCE.md — debug_bubble

Status: Draft v0.2 · Depends on: PROJECT_SPEC.md (D-04, D-05, D-08, D-20…D-23, D-26, D-28), ARCHITECTURE.md, DATA_MODELS.md · Every number is a proposed limit or a target. **No measurement exists yet; none is claimed.**

## 1. Threat model (scope)

| Threat | Mitigation |
|---|---|
| Debug UI or logs reachable in a shipped build | Inert in release, no override in 0.1.0 (D-04); README warning; see §2 for why this is not a guarantee |
| Secrets in logs shown, copied or exported | Redaction at ingestion, fail closed (D-05, D-28); documented as best-effort |
| Unbounded memory/CPU from large, deep, cyclic or hostile objects | Entry-count bound (D-06), per-entry budget and traversal caps (D-21), non-retention of raw values (D-22) |
| Logging code crashing the host app | Pipeline never throws (NFR-03); every `toString()`, iteration and regex use is guarded |
| Interfering with host error handling | Opt-in capture, chained and never swallowing (D-08, E-1…E-9) |
| Export leaking data off-device | User-initiated; built only from sanitized entries; `onExport` is host-controlled |

Out of scope: rooted devices, debugger access, memory forensics, tamper resistance, encryption at rest (nothing is persisted, D-13).

## 2. Build-mode behavior (D-04) and its limits

| Mode | Behavior |
|---|---|
| Debug | Active when `enabled` (default true). |
| Profile | Active when `enabled`; logging overhead can affect profiling results (documented). *(Default pending approval.)* |
| Release | **Inert.** No store, console output, hooks or UI. No override in 0.1.0. |

Honest limits: a build-mode check is only as reliable as how the app is built. Misconfigured flavors, debug builds distributed by mistake, or tooling that changes build constants can still expose a debug tool. A check such as `kReleaseMode` is not claimed to remove code from binaries. Therefore: redaction stays on regardless of mode and cannot be disabled when `kReleaseMode` is true (asserted in debug, forced on otherwise); the README states these limits; release-mode behavior is verified on built apps in T4.4.

Unresolved options (D-04): an explicit release override (`allowInRelease`) is **not** part of 0.1.0; if ever added it needs a visible in-app banner, its own security review and owner approval.

## 3. Redaction (D-05, D-28)

**Position in the pipeline:** step 2 of ARCHITECTURE.md §2. Raw values are local variables only; the store, console sink, dashboard and exporters never see them. (Dart cannot zero memory; "not retained" means no references are kept.)

**Key matching (maps in `metadata` and map-shaped `json`, at every depth, including maps inside lists):**
1. Normalize the key: lowercase, remove all non-alphanumeric characters. If it contains any entry of `sensitiveKeys`, redact.
2. Split the original key into tokens at non-alphanumerics, camelCase and acronym boundaries (`accessToken` → `access`,`token`; `APIKey` → `api`,`key`), lowercase them. If any token equals an entry of `sensitiveKeyTokens`, redact.
3. A redacted value becomes `replacement`; its subtree is not traversed (nor counted toward budgets).
Defaults are listed in API_DESIGN.md §6. Short ambiguous terms (`pin`, `otp`, `card`, `session`, …) are token-only to reduce false positives such as `shipping`. Remaining expected false positives (e.g. `secretary`, `tokenizer` via substring terms; `cardType` via the `card` token) and false negatives (e.g. `ssn_last4` is caught only via token `ssn`; a secret under key `data`) are documented and covered by tests.

**Value patterns (optional):** `valuePatterns` are applied to: message, error message, stack trace, tag/subTag and string values inside payloads. Map keys are not scanned (documented limitation). Recommended examples (Bearer tokens, JWT-shaped strings) will be shown in the README as examples, not guarantees.

**Order and window:** redact first, then truncate. To keep regex cost bounded, only the first `2 × fieldCap` characters of a string are scanned (payload string values: first 4,000 chars) and the rest is discarded; a secret that straddles the scan edge is cut with the discarded part. T4.1 reviews this edge case.

**Fail closed:** if redaction of a field throws (custom regex, custom `toString()`), that field is replaced by `[REDACTION_ERROR]`; the entry is still recorded.

**Not guaranteed:** key- and regex-based redaction cannot remove every secret (free-form text, unusual key names, encoded or split values). Developers should not log secrets. The package must never describe redaction as perfect, complete or guaranteed.

**Consistency requirement:** console output, dashboard, copy, and export are all produced from the sanitized entry; tests assert that a sentinel secret never appears in any of them (T2.5, T3.6, T4.1).

## 4. Bounds, CPU safety and truncation (D-21, D-22)

| Limit | Default | Unit |
|---|---|---|
| Entries (`maxEntries`) | 1,000 | entries |
| Combined retained text per entry (`maxEntryChars`) | 40,000 | chars |
| Message / error message (`maxMessageLength`) | 8,000 | chars |
| Stack trace (`maxStackTraceLength`) | 16,000 | chars |
| Metadata + json (`maxPayloadLength`, shared, metadata first) | 32,000 | serialized chars (approximate count) |
| Tag, subTag | 100 each | chars |
| Error type | 200 | chars |
| Payload traversal (internal) | depth 8 · 2,000 nodes · 200 items per collection · 2,000 chars per string · 200 chars per key | — |
| Clipboard text (internal, D-26) | 500,000 | chars |

- All limits are UTF-16 code units, not bytes; none are byte limits. Dart may store strings with 1 or 2 bytes per code unit, so characters cannot be converted to bytes reliably.
- Retention priority and the deterministic truncation algorithm: DATA_MODELS.md §6. Eviction is oldest-first; `droppedCount` counts only evictions (D-23).
- Worst-case retained text is bounded by `maxEntries × maxEntryChars` (1,000 × 40,000 = 40 million chars) by arithmetic. This is a ceiling for text only; Dart object overhead for the retained structures is additional and **not measured**. No exact memory budget is claimed; T4.2 records actual figures. Lower the limits if memory is a concern.
- Traversal handling: cycles → `[Circular]`; too deep → `[MaxDepth]`; large or infinite collections stop at the item cap; iterables that throw yield `[IterationError: Type]`; `toString()` failures yield `[Unprintable: Type]`; lazy iterables are iterated once and their side effects cannot be undone.
- CPU limits: work per entry is bounded by node, item and string caps. **Not bounded:** a custom `toString()`, iterator or user-supplied regex that is itself slow or has catastrophic backtracking — Dart cannot preempt synchronous code. Mitigations: bounded inputs, simple default patterns, guidance in the README, benchmarks in T4.2.
- No rate limiting in 0.1.0; bursts are bounded per entry and notifications are coalesced (D-18).

## 5. Performance design

- Sanitization is a single traversal (redact + convert + count) performed once per entry.
- No cached pretty-JSON per entry (D-22): pretty text is generated on demand for the open detail view and for console output, then discarded.
- Store notifications coalesced to at most one per frame; UI uses `ListView.builder`; filtered results cached until snapshot or filter changes; search debounced (250 ms).
- Inert or filtered-out calls return after a boolean/level check.
- No isolates in 0.1.0; revisit only if measurements show a need (no speculative features).

## 6. Performance verification plan (results to be recorded only after measurement)

T2.9 creates a benchmark harness; T4.2 runs it and records results with device model, OS version, Flutter/Dart version, build mode (profile), date and iteration counts. Scenarios: ingest N small entries; entries with large messages; large, deep and cyclic payloads; redaction on/off with and without value patterns; memory growth up to `maxEntries`; burst of logs while the dashboard is open; scrolling a full store; copy-all and export at maximum size; pathological `toString()` (documented, not bounded). Pass/fail thresholds are set only after a first baseline exists. Until then README and pub.dev text make no performance claims.

## 7. Lifecycle and handler safety

Dispose follows L-8; handler chaining, restoration and replaced-handler detection follow E-1…E-9; tests cover repeated init, double dispose and handler restoration (T2.8, T4.3). Hot-restart behavior is verified on a device before any claim is made (R-11).

## 8. Security review checkpoints

- T4.1: manual and AI-assisted review of every path handling message, tag, metadata, JSON, error text, stack traces, copy and export; sentinel-secret tests; redaction property/fuzz tests (random nested structures, cycles, hostile `toString()`, throwing iterables); review of the scan-window edge.
- Confirm exporters and console sink read only sanitized entries.
- Dependency audit: core has no third-party runtime dependencies (D-07).
- README security section: redaction limits, release-mode limits, error-hook ordering advice.
