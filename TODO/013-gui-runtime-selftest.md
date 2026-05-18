# 013 - Add GUI runtime Codespaces selftest

## Decision Intent Log

ID: DI-013-20260518-054020
Date: 2026-05-18 05:40:20 UTC
Status: active
Decision: Add a dedicated GUI runtime Codespaces selftest for this repo using `.devcontainer/gui-selftest/devcontainer.json`, `GUI_SELFTEST_1`, `tools/selftest-gui-codespaces.sh`, and `bin/gui-runtime-healthcheck.sh`.
Intent: Validate TODO 011 and the current GUI runtime path in a decomk-controlled Codespace without changing the normal `decomk-conf-cswg` context, which intentionally remains `Block00` for baseline producer bootstrap captures.
Constraints: Keep successful GUI selftest Codespaces by default; support `--delete-after`; keep the normal `tools/selftest-codespaces.sh` command behavior compatible; avoid repo-local consumer dependencies such as `mob-sandbox` for this selftest; keep all temporary local artifacts under `/tmp`.
Affects: `decomk.conf`, `.devcontainer/gui-selftest/devcontainer.json`, `bin/gui-runtime-healthcheck.sh`, `tools/codespace-selftest-lib.sh`, `tools/selftest-codespaces.sh`, `tools/selftest-gui-codespaces.sh`, `docs/thought-experiments/TE-20260518-054020-gui-selftest-entrypoint.md`, `TODO/013-gui-runtime-selftest.md`, and `TODO/TODO.md`.

## Background

The normal `decomk-conf-cswg` Codespaces selftest validates bootstrap and
capture behavior, but it does not run GUI setup because the repo-specific
context overrides the default package list to `Block00`.  TODO 011 needs a
selftest that actually starts the runit-managed GUI stack and validates the
runtime result.

## Implementation Plan

- [x] 013.1 Record the GUI selftest entrypoint thought experiment.
- [x] 013.2 Add `GUI_SELFTEST_1` to `decomk.conf`.
- [x] 013.3 Add `.devcontainer/gui-selftest/devcontainer.json` with
  `DECOMK_CONTEXT=GUI_SELFTEST_1`.
- [x] 013.4 Add a reusable Codespaces selftest helper library.
- [x] 013.5 Update the existing capture selftest to use the shared helper
  library without changing its CLI contract.
- [x] 013.6 Add `bin/gui-runtime-healthcheck.sh`.
- [x] 013.7 Add `tools/selftest-gui-codespaces.sh`.
- [x] 013.8 Run static validation for changed shell scripts.
- [x] 013.9 Run `DECOMK_CONTEXT=GUI_SELFTEST_1 decomk plan updateContent`.
- [x] 013.10 Run `DECOMK_CONTEXT=GUI_SELFTEST_1 decomk plan postCreate`.
- [ ] 013.11 Run `tools/selftest-gui-codespaces.sh --machine basicLinux32gb`.
- [ ] 013.12 Run the normal `tools/selftest-codespaces.sh` regression check.

## Validation Notes

- 2026-05-18 05:47 UTC: Attempted
  `tools/selftest-gui-codespaces.sh --machine basicLinux32gb`.  GitHub rejected
  the Codespace before creation because `.devcontainer/gui-selftest/devcontainer.json`
  does not exist on remote branch `main` yet.  This runtime validation must be
  rerun after the branch containing this TODO is pushed.

## Acceptance Criteria

- The GUI selftest uses this repo and the selftest devcontainer path
  `.devcontainer/gui-selftest/devcontainer.json`.
- The normal `decomk-conf-cswg` devcontainer path still selects the existing
  `Block00` producer-bootstrap context.
- The GUI selftest fails if `GUIDesktop_1` is not selected.
- The GUI selftest fails if runit reports unhealthy `xvfb`, `openbox`,
  `x11vnc`, or `novnc` services.
- The GUI selftest fails if noVNC cannot serve HTTP or WebSocket traffic through
  to the VNC/RFB backend.
- The GUI selftest fails if the TODO 011 symptom
  `unsupported GUI runit service: .` appears in decomk or runit logs.
- Successful GUI selftest Codespaces are kept by default for manual inspection.
