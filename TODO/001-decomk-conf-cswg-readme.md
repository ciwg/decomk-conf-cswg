## Decision Intent Log

ID: DI-001-20260422-192624
Date: 2026-04-22 19:26:24
Status: active
Decision: Align README identity to `decomk-conf-cswg` and replace version-change guidance with an append-only Makefile/decomk.conf policy.
Intent: Prevent history-rewriting drift in provisioning logic and make version rollout behavior explicit and auditable for maintainers.
Constraints: Docs-only implementation; modify `README.md` only for content updates; enforce hard "never edit history in the Makefile" language with an explicit pre-production testing/bugfix exception.
Affects: `README.md`, `TODO/TODO.md`, `TODO/001-decomk-conf-cswg-readme.md`

ID: DI-001-20260423-194216
Date: 2026-04-23 19:42:16
Status: active
Decision: Make README generic and low-churn; remove repo-specific config mirrors so README does not require routine updates after `decomk init-conf`.
Intent: Keep `decomk.conf` and `Makefile` as the only live configuration source of truth and prevent documentation drift from duplicated operational details.
Constraints: Keep guidance general to decomk config repos; preserve append-only Makefile history policy language.
Affects: `README.md`, `TODO/001-decomk-conf-cswg-readme.md`

## Task 001 - README Rename + Version Policy

- [x] 001.1 Update README repo identity wording to `decomk-conf-cswg`.
- [x] 001.2 Replace README version-change section with append-only policy and examples.
- [x] 001.3 Document the allowed exception for pre-production testing/bugfix.
- [x] 001.4 Validate diff scope and record compliance artifacts in final handoff.
- [x] 001.5 Rewrite README as generic, low-churn guidance without mirrored live config details.
