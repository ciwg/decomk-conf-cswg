## Decision Intent Log

ID: DI-003-20260423-125217
Date: 2026-04-23 12:52:17
Status: active
Decision: Track implementation of GUI desktop support for `mob-consensus` as a dedicated TODO with explicit scope, dependencies, and validation steps.
Intent: Replace the current `GUIDesktop` placeholder with real, auditable behavior while keeping baseline installs minimal and non-GUI by default.
Constraints: Preserve append-only versioned package target policy, keep GUI-specific dependencies isolated from baseline `Block10`, and keep decomk context wiring explicit.
Affects: `Makefile`, `decomk.conf`, `TODO/TODO.md`, `TODO/003-mob-consensus-gui-desktop.md`

## Task 003 - Implement GUI Desktop for mob-consensus

- [ ] 003.1 Define the GUI desktop requirements for `mob-consensus` (window manager, browser/noVNC strategy, and required tooling) and capture accepted scope.
- [ ] 003.2 Add or confirm a `mob-consensus` repo context in `decomk.conf` that maps to `GUI_DESKTOP` behavior intentionally.
- [ ] 003.3 Replace the `GUIDesktop` placeholder Make target with concrete idempotent setup targets for GUI mode.
- [ ] 003.4 Keep `Block10` GUI-neutral by placing GUI-only apt installs in dedicated versioned GUI targets referenced only by GUI flows.
- [ ] 003.5 Validate both `updateContent` and `postCreate` for GUI and non-GUI contexts, including manual target troubleshooting runs.
- [ ] 003.6 Record verification evidence, update index/status, and close TODO 003.
