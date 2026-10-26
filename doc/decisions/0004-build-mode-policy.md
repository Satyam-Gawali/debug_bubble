# Decision Record: 0004 — Build-Mode Policy (D-04)

- **Status:** Confirmed (Approved by project owner on 2026-10-26)
- **Deciders:** Project Owner
- **Related Requirements:** NFR-03, D-04, ARCHITECTURE §7

## Context
Debug toolkits must prevent accidental exposure of logs, error details, or debug UI in release builds distributed to end users.

## Decision
Option A (Inert in release) is approved:
- The package is active in debug and profile modes when `config.enabled` is true.
- The package is completely inert in release mode (`kReleaseMode == true`).
- In version 0.1.0, there is **no release override flag** (`allowInRelease` is not supported).
- `config.enabled` can only switch the package off, never on in release builds.
- An internal build-mode seam (`BuildMode`) provides test seams to verify inactive behavior deterministically in unit tests.

## Consequences
- Eliminates the risk of sensitive log leakage in production.
- Profile mode remains active to allow performance measurements and memory profiling.
- Release-mode apps treat logging as a silent, non-throwing no-op and render host widget content without debug UI overhead.
