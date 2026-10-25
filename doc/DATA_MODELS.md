# DATA_MODELS.md — debug_bubble

Status: Draft v0.2 · Depends on: PROJECT_SPEC.md (D-05, D-11, D-20…D-23, D-25, D-26) · Used by: API_DESIGN.md, SECURITY_PERFORMANCE.md, UI_UX_SPEC.md, TESTING_STRATEGY.md

All limits are proposed defaults (unmeasured) and are counted in UTF-16 code units (Dart `String.length`), never bytes. Truncation must not split a surrogate pair.

## 1. `DebugLogLevel`

Order (low → high), identical to the enum index: `debug`=0, `info`=1, `success`=2, `warning`=3, `error`=4, `critical`=5. Each has a stable lowercase `name` used in export. `isError` is true for `error` and `critical` (Errors tab). The `minLevel` gate keeps an entry when `level.index >= minLevel.index`; therefore `minLevel: warning` also drops `success` (D-11).

## 2. `DebugLogEntry` (immutable, sanitized)

| Field | Type | Notes |
|---|---|---|
| `id` | `int` | Monotonic per controller, starts at 1; not reset by `clear()`. |
| `timestamp` | `DateTime` | UTC, taken at ingestion. |
| `level` | `DebugLogLevel` | |
| `message` | `String` | Redacted, then truncated to `maxMessageLength`. |
| `tag` | `String?` | Redacted (value patterns), truncated to 100 chars. |
| `subTag` | `String?` | Same rules as `tag`; stored as given (no tag required). |
| `error` | `DebugErrorInfo?` | |
| `stackTrace` | `String?` | Redacted, truncated to `maxStackTraceLength`. |
| `metadata` | `Map<String, Object?>?` | Sanitized JSON-safe copy (§7). |
| `json` | `Object?` | Sanitized JSON-safe copy (§7). |
| `isUncaught` | `bool` | True if captured by the uncaught-error hooks. |
| `truncated` | `bool` | True if any budget caused data to be cut or omitted (§6). |

Methods: `Map<String, Object?> toJson()` (export shape, §8), `==`/`hashCode` by `id`, `toString()` (short, non-sensitive summary). There is **no** `copyWith`, and **no cached pretty-JSON string** (D-22): pretty text is produced on demand by the UI or console sink and not retained.

The entry never references the host's original objects. Raw message, error, stack and payload values exist only as local variables inside the ingestion function.

## 3. `DebugErrorInfo`

| Field | Type | Notes |
|---|---|---|
| `type` | `String` | `error.runtimeType.toString()` (guarded; capped at 200 chars). |
| `message` | `String` | Guarded `error.toString()`; redacted; truncated to `maxMessageLength`. |

The original error object is not retained.

## 4. `DebugLogFilter` (exact semantics)

| Field | Type | Semantics |
|---|---|---|
| `levels` | `Set<DebugLogLevel>` | Exact-level match; empty = all levels. Not a minimum. |
| `query` | `String` | Trimmed; empty after trim = no text filter. Case-insensitive substring (`toLowerCase()`, locale-independent) against `message`, `tag`, `subTag`, `error.type`, `error.message`. **Not** matched against `stackTrace`, `metadata` or `json` (D-22). |
| `tag` | `String?` | Exact, case-sensitive match on `tag`; `null` = no tag filter. |

All present criteria combine with AND. `matches(entry)` is pure; filtering never mutates the store. `isEmpty` is true when no criterion is set.

## 5. Store contract (internal in 0.1.0)

```
add(entry)        // if length == maxEntries: evict the single oldest entry, droppedCount += 1; then append
snapshot()        // unmodifiable view, oldest → newest; cached until next mutation
clear()           // empties the store; droppedCount = 0; id counter NOT reset
length            // always <= maxEntries
droppedCount      // entries evicted by capacity since creation or last clear()
errorCount        // entries currently stored with level.isError
```

`droppedCount` semantics (D-23), used identically by store, controller, UI, export and tests:
- Counts **only** capacity evictions.
- Entries rejected by the `minLevel` gate or an inert controller never enter the store and are not counted.
- Truncated fields are reported per entry (`truncated`), not in `droppedCount`.
- Reset to 0 by `clear()`; not affected by filters.

No persistence (D-13). The store interface stays internal until 0.3.x.

## 6. Retained-size budget and truncation (D-21)

Per-entry combined budget `maxEntryChars` (default 40,000) covers: tag, subTag, message, error type+message, stack trace, and the serialized size of metadata and json.

**Retention priority (highest first):** tag/subTag → message → error → stack trace → metadata → json.

Algorithm (deterministic):
1. `remaining = maxEntryChars`.
2. For each field in priority order: `allowed = min(fieldCap, remaining)`. Strings longer than `allowed` are cut and end with the marker `…[truncated]` (the marker counts toward `allowed`; if `allowed` cannot hold the marker the field is omitted and `truncated = true`). `remaining -= retainedLength`.
3. Field caps: tag/subTag 100; error type 200; message and error message `maxMessageLength` (8,000); stack trace `maxStackTraceLength` (16,000).
4. Metadata and json **share** `maxPayloadLength` (32,000): metadata is converted first with budget `min(maxPayloadLength, remaining)`; json gets `min(maxPayloadLength − metadataUsed, remaining)`.
5. Structured payloads are not cut mid-text (that would break JSON). The converter (§7) counts approximate serialized size while traversing; when the budget is exhausted the rest is replaced by marker values and traversal stops.
6. `truncated = true` whenever any cut, omission or marker caused by a budget or traversal cap occurred. Redaction replacements alone do not set it.

Dropping or truncation never throws and never changes `droppedCount`.

## 7. JSON-safe conversion (D-20, D-22, D-28)

One bounded traversal performs redaction, conversion and size counting. Internal caps (unmeasured defaults): depth 8; 2,000 nodes visited per payload; 200 items per collection; string values 2,000 chars; map keys 200 chars.

| Input | Result |
|---|---|
| `null`, `bool`, finite `num`, `String` | As is (strings redacted by value patterns, capped). `NaN`/`Infinity` → string `"NaN"`/`"Infinity"`. |
| `DateTime` | UTC ISO-8601 string. |
| `Map` | Keys → guarded `toString()`, capped. Sensitive key → value `"[REDACTED]"` and the subtree is not traversed. More than 200 entries → first 200 plus `"[truncated]": "N more entries omitted"`. |
| `List`/`Iterable` | Iterated **once**, at most 200 items, inside try/catch. Overflow → final element `"[N more items omitted]"` (N omitted when length is unknown). Iteration error → items collected so far plus `"[IterationError: Type]"`. |
| Reference cycle (identity check on the ancestor path) | `"[Circular]"` |
| Depth > 8 | `"[MaxDepth]"` |
| Node budget or size budget exhausted | `"[Truncated]"` |
| Anything else | Guarded `toString()` (capped). If it throws → `"[Unprintable: Type]"` (type name itself guarded). |
| Redaction failure on a string | `"[REDACTION_ERROR]"` (fail closed). |

`Future`, `Stream` and similar objects are never awaited or listened to; only their `toString()` is used. Infinite or lazy iterables are bounded by the item cap; side effects of iterating a lazy iterable cannot be undone (documented). A slow custom `toString()` or iterable cannot be preempted (SECURITY_PERFORMANCE.md §4).

## 8. Export schema (version 1)

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-10-25T10:00:00.000Z",
  "packageVersion": "0.1.0",
  "buildMode": "debug",
  "redaction": { "enabled": true, "valuePatternCount": 0 },
  "limits": {
    "maxEntries": 1000, "maxEntryChars": 40000, "maxMessageLength": 8000,
    "maxStackTraceLength": 16000, "maxPayloadLength": 32000
  },
  "totalEntries": 1,
  "exportedEntries": 1,
  "droppedCount": 0,
  "filter": { "levels": [], "query": "", "tag": null },
  "entries": [
    {
      "id": 1,
      "timestamp": "2026-10-25T09:59:58.123Z",
      "level": "error",
      "message": "Login failed",
      "tag": "Auth",
      "subTag": "Login",
      "error": { "type": "FormatException", "message": "Unexpected character" },
      "stackTrace": "#0 ...",
      "metadata": { "userId": 42, "token": "[REDACTED]" },
      "json": null,
      "isUncaught": false,
      "truncated": false
    }
  ]
}
```

Rules:
- `entries` are oldest → newest and are exactly the filtered, already-sanitized entries; `exportedEntries == entries.length`; `totalEntries` = store length at export time; `droppedCount` is the controller-wide value (D-23) regardless of filter.
- `buildMode` is `"debug"` or `"profile"` (an inert release controller cannot export; a disposed controller returns the same schema with zero entries).
- `redaction.enabled` reports whether redaction was enabled for this controller; `valuePatternCount` is the number of configured value patterns (patterns themselves are not exported).
- `limits` echoes the configured limits so consumers can interpret truncation.
- Field names are stable within a `schemaVersion`; consumers must ignore unknown fields; any breaking change bumps `schemaVersion` and requires a decision record.

## 9. Plain-text rendering (Copy entry, Copy all)

Entry block:
```
[2026-10-25T09:59:58.123Z] ERROR Auth/Login (#1)
Login failed
Error: FormatException: Unexpected character
Metadata: <pretty JSON>
JSON: <pretty JSON>
Stack trace:
<stack trace>
```
Lines for absent fields are omitted; a `(truncated)` suffix is appended to the header line when `truncated` is true. Timestamps in text and JSON are UTC ISO-8601 (the dashboard list shows local time for readability).

"Copy all" (`exportText`) starts with `debug_bubble log export — N entries (M older entries dropped)`, then blocks separated by a blank line, oldest → newest. If the text would exceed the internal clipboard cap (500,000 chars, D-26) the oldest entries in the selection are omitted and the header states how many.

## 10. Session info (Info tab, read-only, no log content)

Package version (`debugBubbleVersion`, D-25) · build mode (`debug`/`profile`) · active flag · limits in §6 · entry count · `droppedCount` · per-level counts · console output on/off · uncaught-capture: `off`, `active`, or `inactive (handler replaced)` · redaction on/off and value-pattern count.
