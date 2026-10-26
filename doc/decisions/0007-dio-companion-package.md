# Decision Record: 0007 — Dio Integration Packaging (D-07)

- **Status:** Confirmed (Approved by project owner on 2026-10-26)
- **Deciders:** Project Owner
- **Related Requirements:** NFR-01, D-07

## Context
Many Flutter applications use Dio for networking. Providing HTTP request/response inspection is valuable, but adding Dio to the core package introduces a heavy third-party dependency into the core dependency graph.

## Decision
Separate companion package:
- Core `debug_bubble` depends strictly on the Flutter SDK only.
- Dio integration is split into a separate companion package named `debug_bubble_dio`, scheduled for version 0.2.x.
- `debug_bubble_dio` will feed logs and network inspection details into the core via public logging APIs without core depending on Dio.

## Consequences
- Core package maintains zero third-party runtime dependencies.
- Apps that do not use Dio (e.g. using `http` or custom clients) carry no unused network dependencies.
