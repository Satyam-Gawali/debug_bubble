# Decision Record: 0015 — SDK Constraints (D-15)

- **Status:** Confirmed (Approved by project owner on 2026-10-26)
- **Deciders:** Project Owner
- **Related Requirements:** D-15, NFR-01, IMPLEMENTATION_ROADMAP T1.1/T4.5

## Context
Setting the package SDK constraints requires aligning the Dart SDK requirement with the Flutter toolchain while ensuring compatibility is verified before making broader support claims.

## Decision
Placeholder alignment approved:
- Keep `sdk: ^3.13.2` as the Dart constraint for now.
- Keep `flutter: ">=3.47.0"` as the Flutter minimum constraint, reflecting the installed and verified toolchain where Dart 3.13.2 was introduced.
- Broader SDK compatibility (such as lowering to Dart 3.0 / Flutter 3.10) will only be claimed after build verification in Task T4.5.

## Consequences
- No unverified claims regarding backwards compatibility with older Flutter releases.
- Dependency resolution passes cleanly without version solver errors on modern Flutter toolchains.
