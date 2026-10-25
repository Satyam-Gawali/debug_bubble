# AI_WORKFLOW.md — debug_bubble

Status: Draft v0.2 · Depends on: IMPLEMENTATION_ROADMAP.md, TESTING_STRATEGY.md (VERIFY-* sets), PROJECT_SPEC.md

How AI tools (Claude and others) are used to plan, implement, test, review and refactor this package safely, one small task at a time.

## 1. Ground rules

1. **No fabricated verification.** Never claim a test, analysis, build or benchmark passed or measured something unless it was actually executed and the output is available. An AI statement that it "ran" something counts only if the output is pasted.
2. **No silent changes** to approved architecture or public APIs. Any change needs a decision record in `doc/decisions/` and updates to every affected document (§7).
3. **Small, reviewable tasks.** One roadmap task at a time; no whole-package generation; diffs small enough for a human to read fully.
4. **Tests alongside implementation** in the same task; a task without its tests is not Done.
5. **Human review of every diff** before merge; AI output is a draft.
6. **No invented numbers.** Limits are "proposed defaults" until measured (T4.2); compatibility claims need T4.5 evidence; the package is not "pub.dev-ready" until G5.
7. **Minimal API and dependencies.** No new public symbols, features or dependencies without justification and an approved decision record.
8. **Privacy.** Never paste secrets or private app data (including YoDoctor data) into AI tools; `AppLogger` is a design reference only.

## 2. Task file template (`doc/tasks/T<phase>.<n>-<slug>.md`)

```
# T2.4 — Bounded payload conversion
Status: Not started | In progress | In review | Done | Unverified | Blocked
Phase / depends on: P2 / T2.1, T2.3
Scope: <included / explicitly excluded>
Prerequisites: <approved decisions, files, tools>
Expected file changes: <paths>
Acceptance criteria: <observable, testable statements>
Relevant tests: <files / cases written or run>
Verification commands: <VERIFY-* names and exact commands>
Verification results: <pasted real output + date + environment, or "not run">
Review: <human review, AI review, security/performance review notes>
Docs updated: <files> · Decision records: <ids or none>
Completion notes: <deviations, follow-ups>
```

**Done** requires: criteria met, tests written, verification commands run with output recorded, analyzer/formatter clean, review complete, docs and decision records updated. If any verification could not run, the status is **Unverified**.

## 3. Development loop per task

1. Pick the next roadmap task whose dependencies are Done.
2. Write the task file (AI may draft; the developer approves scope and acceptance criteria).
3. Give the AI the task file and only the relevant sections of the docs; ask for tests together with code and for a list of assumptions.
4. Review the diff: scope creep, API drift, hidden dependencies, error handling, never-throw paths, redaction and budget paths, lifecycle ownership.
5. Run the verification commands yourself; paste results into the task file.
6. Run the AI review passes in §5 and record findings and responses.
7. Update affected docs and CHANGELOG; add a decision record for any architecture/API change.
8. Commit with the task ID; mark the task Done (or Unverified).

## 4. Phase-level practices

- **Phase 1:** AI cross-reviews the nine documents; the consistency checklist (§7) is run at T1.5 and again at T2.10, T3.10, T4.7, T5.6.
- **Phases 2–3:** task-sized prompts with DATA_MODELS.md and API_DESIGN.md as context; keep `core/` free of UI imports.
- **Phase 4:** AI security/performance reviews are inputs, not evidence. Evidence is executed tests, fuzz runs, built apps and recorded measurements.
- **Phase 5:** AI may draft README and dartdoc; the developer verifies that every sample compiles in the example app.
- After each phase, validate with the example app and record what was run.

## 5. AI review checklists

**Code review:** matches task scope and API_DESIGN.md; no new public symbols or dependencies; null safety; logging paths never throw; every `toString()`, iteration and regex is guarded; dispose and ownership rules (L-7, L-8) respected; error handlers chained and restored (E-1…E-9); limits from D-21 honored.

**Security review:** every path handling message, tag, metadata, JSON, error text, stack trace, copy and export goes through sanitization; no raw value retained (D-22); inert in release (D-04); redaction cannot be disabled in release; no secrets in config echoes or exports; release-mode text never claims guarantees.

**Performance review:** no unbounded loops over payloads; no duplicate serialized copies; notifications coalesced; no work done when inactive.

**Test review:** tests assert behavior, cover limit−1/limit/limit+1 boundaries and disabled/release paths, are deterministic (injected clock, ids, build mode, sinks), and none is skipped silently.

## 6. Prompt guidelines

- State the task ID, paste or link the relevant doc sections, list acceptance criteria and constraints (no new dependencies, no API changes).
- Ask the AI to list assumptions and anything it could not verify, and to state which commands it ran (if none, treat every claim as unverified).
- Request minimal diffs and tests together.
- If the AI proposes an API, architecture, default or limit change, stop and write a decision record instead of accepting it inside the diff.
- Never ask the AI to "make all tests pass" by editing expectations without explaining why the expectation was wrong.

## 7. Documentation consistency checklist (run at T1.5, T2.10, T3.10, T4.7, T5.6)

Update every affected document when a decision changes, then verify all nine files against each other:

| Area | Check |
|---|---|
| Public symbols | The same ten symbols in PROJECT_SPEC NFR-05, API_DESIGN §1, and no extra public type in any doc or example |
| Signatures | API_DESIGN signatures match DATA_MODELS fields, UI actions, and the lifecycle text |
| Lifecycle | L-1…L-12 (ARCHITECTURE §5) agree with API_DESIGN, UI_UX_SPEC (L-6, L-8), TESTING_STRATEGY and the roadmap tasks |
| Init example | Every `init`/`DebugBubble` example uses the same pattern (API_DESIGN §2) |
| Config defaults | `enabled`, `minLevel`, limits, `captureUncaughtErrors=false`, `consoleOutput` identical in API_DESIGN, PROJECT_SPEC D-xx, SECURITY_PERFORMANCE |
| Build modes | Debug/profile/release behavior identical in PROJECT_SPEC D-04, ARCHITECTURE §7, SECURITY_PERFORMANCE §2, API_DESIGN `enabled`, UI_UX_SPEC |
| Redaction | Rules in SECURITY_PERFORMANCE §3 = defaults in API_DESIGN §6 = tests in TESTING_STRATEGY §2 |
| Limits | 1,000 / 40,000 / 8,000 / 16,000 / 32,000 / 100 / 200 / depth 8 / 2,000 nodes / 200 items / 2,000 string / 500,000 clipboard — same everywhere, always "proposed, unmeasured" |
| Units | Characters (UTF-16 code units) everywhere; no byte claims |
| Log levels | Order and `success` placement identical in DATA_MODELS, API_DESIGN, UI, tests |
| Filters | Semantics identical in DATA_MODELS §4, UI_UX_SPEC §3, tests |
| `droppedCount` | D-23 semantics identical in DATA_MODELS §5, UI counts line, export schema, tests |
| Export schema | Fields and `schemaVersion` identical in DATA_MODELS §8, UI_UX_SPEC §6, API_DESIGN, tests |
| Error handlers | E-1…E-9 agree with SECURITY_PERFORMANCE, tests, roadmap (T2.8, T4.3) |
| UI actions | D-26 semantics identical in UI_UX_SPEC §6, API_DESIGN `onExport`, tests (UI-09…UI-12) |
| Package structure | Directory layout and module names match ARCHITECTURE §3 and task file paths |
| Phases/tasks | Every task ID referenced anywhere exists in the roadmap; dependencies acyclic; each task has files, tests, acceptance, verify |
| Verification | VERIFY-* names used in roadmap are defined in TESTING_STRATEGY §7 |
| Versions | 0.1.0 / 0.2.x / 0.3.x / 1.0.0 scope identical in PROJECT_SPEC §9 and roadmap |
| Decision IDs | Every D-xx, R-xx, L-xx, E-xx, UI-xx reference resolves; statuses current |
| Claims | No document claims tests passed, measurements, compatibility or pub.dev readiness without recorded evidence |

Record who ran the check, when, and the findings in the corresponding review task file. A scripted partial check (grep for ID and number consistency) may be used but does not replace a read-through.

## 8. Definition of Done for an AI-assisted task

Scope delivered · acceptance criteria met · tests written · verification commands executed with recorded output · analyzer and formatter clean · human diff review and AI review complete · security/performance review where the task touches sanitization, hooks, lifecycle or UI hosting · docs and decision records updated · status set to Done.

## 9. What AI must not decide alone

Public API shape or changes, build-mode and release-mode policy, redaction defaults and matching rules, limits and budgets, dependency additions, license, SDK/platform support claims, version numbers, and the decision to publish. The AI may propose; the owner approves in a decision record.
