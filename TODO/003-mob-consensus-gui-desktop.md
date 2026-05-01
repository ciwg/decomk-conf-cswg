## Decision Intent Log

ID: DI-003-20260430-182956
Date: 2026-04-30 18:29:56
Status: active
Decision: Implement the GUI desktop as a runit-backed producer-image substrate plus decomk-managed GUI package/service reconciliation keyed off `GUI_DESKTOP`, using standard runit paths (`/etc/sv`, `/etc/service`) and replacing the legacy clipboard popup with a Desktop note file.
Intent: Keep the consumer repo image-only while making GUI behavior auditable, repeatable, and isolated from the non-GUI baseline.
Constraints: Keep `Block10` GUI-neutral, keep GUI package targets append-only and lower-case, leave Codespaces-managed SSH outside runit, and write only `~/Desktop/clipboard-help.md` in `postCreate` for GUI users.
Affects: `Makefile`, `decomk.conf`, `.devcontainer/Dockerfile`, `.devcontainer/devcontainer.json`, `TODO/003-mob-consensus-gui-desktop.md`, `TODO/004-mob-consensus-gui-stack.md`
Supersedes:

ID: DI-003-20260423-125217
Date: 2026-04-23 12:52:17
Status: active
Decision: Track implementation of GUI desktop support for `mob-consensus` as a dedicated TODO with explicit scope, dependencies, and validation steps.
Intent: Replace the current `GUIDesktop` placeholder with real, auditable behavior while keeping baseline installs minimal and non-GUI by default.
Constraints: Preserve append-only versioned package target policy, keep GUI-specific dependencies isolated from baseline `Block10`, and keep decomk context wiring explicit.
Affects: `Makefile`, `decomk.conf`, `TODO/TODO.md`, `TODO/003-mob-consensus-gui-desktop.md`

## Task 003 - Implement GUI Desktop for mob-consensus

- [x] 003.1 Define the GUI desktop requirements for `mob-consensus` (window manager, browser/noVNC strategy, and required tooling) and capture accepted scope.
- [x] 003.2 Add or confirm a `mob-consensus` repo context in `decomk.conf` that maps to `GUI_DESKTOP` behavior intentionally.
- [x] 003.3 Replace the `GUIDesktop` placeholder Make target with concrete idempotent setup targets for GUI mode.
- [x] 003.4 Keep `Block10` GUI-neutral by placing GUI-only apt installs in dedicated versioned GUI targets referenced only by GUI flows.
- [ ] 003.5 Validate both `updateContent` and `postCreate` for GUI and non-GUI contexts, including manual target troubleshooting runs.
- [ ] 003.6 Record verification evidence, update index/status, and close TODO 003.

Implementation note: the repo context currently implemented is `mob-sandbox`, which now inherits `GUI_DESKTOP` directly in `decomk.conf`.
