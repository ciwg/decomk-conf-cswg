# TODO-tozoh: Add GUI runtime Codespaces selftest

## Decision Intent Log

ID: DI-tazit
Date: 2026-05-18 05:40:20 UTC
Status: active
Decision: Add a dedicated GUI runtime Codespaces selftest for this repo using `.devcontainer/gui-selftest/devcontainer.json`, `GUI-SELFTEST-1`, `tools/selftest-gui-codespaces.sh`, and `bin/gui-runtime-healthcheck.sh`.
Intent: Validate TODO-dagij and the current GUI runtime path in a decomk-controlled Codespace without changing the normal `decomk-conf-cswg` context, which intentionally remains `Block00` for baseline producer bootstrap captures.
Constraints: Keep successful GUI selftest Codespaces by default; support `--delete-after`; keep the normal `tools/selftest-codespaces.sh` command behavior compatible; avoid repo-local consumer dependencies such as `mob-sandbox` for this selftest; keep all temporary local artifacts under `/tmp`.
Affects: `decomk.conf`, `.devcontainer/gui-selftest/devcontainer.json`, `bin/gui-runtime-healthcheck.sh`, `tools/codespace-selftest-lib.sh`, `tools/selftest-codespaces.sh`, `tools/selftest-gui-codespaces.sh`, `docs/thought-experiments/TE-galan-gui-selftest-entrypoint.md`, `TODO/TODO-tozoh-gui-runtime-selftest.md`, and `TODO/TODO.md`.

ID: DI-gipif
Date: 2026-05-18 06:10:19 UTC
Status: active
Decision: Remove `DEVCONTAINER_GUI` from decomk policy, Makefile plumbing, demo scripts, and GUI runtime health checks.
Intent: Avoid a stale second source of GUI truth.  GUI selection is already represented by the decomk target graph (`GUIDesktop-1`, `postCreateGUIDesktopNote`) and proven by runtime service, process, HTTP, WebSocket, and desktop-note checks.
Constraints: Do not replace the demo `gui=` field with another metadata field; ignore any external `DEVCONTAINER_GUI` value rather than adding compatibility shims; keep GUI selftest assertions tied to actual selected targets and runtime health.
Affects: `decomk.conf`, `Makefile`, `bin/hello-world.sh`, `bin/post-create-user-demo.sh`, `bin/gui-runtime-healthcheck.sh`, and `TODO/TODO-tozoh-gui-runtime-selftest.md`.

## Background

The normal `decomk-conf-cswg` Codespaces selftest validates bootstrap and
capture behavior, but it does not run GUI setup because the repo-specific
context overrides the default package list to `Block00`.  TODO-dagij needs a
selftest that actually starts the runit-managed GUI stack and validates the
runtime result.

## Implementation Plan

- [x] tozoh.1 Record the GUI selftest entrypoint thought experiment.
- [x] tozoh.2 Add `GUI-SELFTEST-1` to `decomk.conf`.
- [x] tozoh.3 Add `.devcontainer/gui-selftest/devcontainer.json` with
  `DECOMK_CONTEXT=GUI-SELFTEST-1`.
- [x] tozoh.4 Add a reusable Codespaces selftest helper library.
- [x] tozoh.5 Update the existing capture selftest to use the shared helper
  library without changing its CLI contract.
- [x] tozoh.6 Add `bin/gui-runtime-healthcheck.sh`.
- [x] tozoh.7 Add `tools/selftest-gui-codespaces.sh`.
- [x] tozoh.8 Run static validation for changed shell scripts.
- [x] tozoh.9 Run `DECOMK_CONTEXT=GUI-SELFTEST-1 decomk plan updateContent`.
- [x] tozoh.10 Run `DECOMK_CONTEXT=GUI-SELFTEST-1 decomk plan postCreate`.
- [x] tozoh.11 Run `tools/selftest-gui-codespaces.sh --machine basicLinux32gb`.
- [ ] tozoh.12 Run the normal `tools/selftest-codespaces.sh` regression check.

## Validation Notes

- 2026-05-18 05:47 UTC: Attempted
  `tools/selftest-gui-codespaces.sh --machine basicLinux32gb`.  GitHub rejected
  the Codespace before creation because `.devcontainer/gui-selftest/devcontainer.json`
  does not exist on remote branch `main` yet.  This runtime validation must be
  rerun after the branch containing this TODO is pushed.
- 2026-05-18 06:10 UTC: Removed `DEVCONTAINER_GUI` live references and validated
  that `GUI-SELFTEST-1` still resolves `Block10`, `GUIDesktop-1`, and
  `postCreateGUIDesktopNote` through the decomk target graph.
- 2026-05-18 06:25 UTC: GUI selftest passed from
  `/tmp/decomk-conf-cswg-gui-selftest-20260518-061714`.  It validated
  `GUI-SELFTEST-1`, runit-managed `xvfb`, `openbox`, `x11vnc`, and `novnc`,
  noVNC HTTP, WebSocket-to-RFB connectivity, the desktop note, and absence of the
  TODO-dagij `unsupported GUI runit service: .` log symptom.

## Acceptance Criteria

- The GUI selftest uses this repo and the selftest devcontainer path
  `.devcontainer/gui-selftest/devcontainer.json`.
- The normal `decomk-conf-cswg` devcontainer path still selects the existing
  `Block00` producer-bootstrap context.
- The GUI selftest fails if `GUIDesktop-1` is not selected.
- The GUI selftest fails if runit reports unhealthy `xvfb`, `openbox`,
  `x11vnc`, or `novnc` services.
- The GUI selftest fails if noVNC cannot serve HTTP or WebSocket traffic through
  to the VNC/RFB backend.
- The GUI selftest fails if the TODO-dagij symptom
  `unsupported GUI runit service: .` appears in decomk or runit logs.
- Successful GUI selftest Codespaces are kept by default for manual inspection.
