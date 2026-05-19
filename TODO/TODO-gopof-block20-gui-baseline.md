# TODO-gopof: Build Block20 with baseline GUI desktop

## Decision Intent Log

ID: DI-rutoj
Date: 2026-05-17 21:32:23 UTC
Status: active
Decision: Track `Block20` as the append-only baseline image block that installs and supervises the GUI desktop stack for every repository consuming the decomk baseline image.
Intent: Treat `xvfb`, `openbox`, `x11vnc`, and `novnc` as baseline workspace infrastructure rather than repo-specific application features, so every decomk-controlled repository starts with the same human-facing desktop control surface.
Constraints: Do not rewrite the meaning of `Block10`; keep GUI startup supervised by runit; fix or explicitly remove per-service log supervision before release; document localhost/noVNC security assumptions before moving channel tags.
Affects: `Makefile`, `Dockerfile`, `.devcontainer/devcontainer.json`, `decomk.conf`, `bin/gui-runit-sync.sh`, `bin/write-gui-desktop-note.sh`, `docs/gui-baseline-decision-tree.md`, release-image workflow, and consumer repo pull tests.

## Background

The GUI baseline decision tree is documented in
`docs/gui-baseline-decision-tree.md`.  The short version is that the GUI desktop
stack is part of the universal bootstrap substrate: every repo should have the
same browser-accessible desktop path unless a future decision explicitly narrows
that scope.

`Block20` should therefore represent the first image block where the baseline
image includes always-on GUI desktop support.  `Block10` remains the prior
non-GUI baseline and should not be retroactively redefined.

## Dependencies

- [ ] gopof.1 Resolve TODO-dagij or otherwise prove runit-managed GUI services stay
  healthy under Codespaces startup.
- [ ] gopof.2 Confirm whether per-service runit `log/run` supervision is required
  or intentionally omitted for the GUI services.
- [ ] gopof.3 Confirm the security model for noVNC and x11vnc, including
  localhost binding, forwarded ports, and VNC authentication assumptions.
- [ ] gopof.4 Confirm the expected desktop note path and owner for repos using the
  baseline image.

## Implementation Plan

- [ ] gopof.5 Add a locked implementation DI before touching behavior-changing
  files.
- [ ] gopof.6 Move the GUI package and service prerequisites into the append-only
  `Block20` path.
- [ ] gopof.7 Ensure `xvfb`, `openbox`, `x11vnc`, and `novnc` are installed in the
  image rather than reinstalled by each consumer repo.
- [ ] gopof.8 Ensure the runit service definitions are created repeatably and are
  active for every baseline image consumer.
- [ ] gopof.9 Ensure `postCreateGUIDesktopNote` still writes the expected note for
  the remote user.
- [ ] gopof.10 Update docs for how a repo consumes the `Block20` GUI baseline.
- [ ] gopof.11 Build, tag, and push a `Block20` release candidate image.
- [ ] gopof.12 Move the chosen channel tag only after a fresh consumer Codespace
  validates GUI service health and noVNC connectivity.

## Validation Plan

- [ ] gopof.13 Run the decomk-conf-cswg selftest against the `Block20` image.
- [ ] gopof.14 Run a fresh `mob-sandbox` consumer pull test and confirm SSH,
  updateContent, postCreate, GUI service health, and noVNC WebSocket
  connectivity pass.
- [ ] gopof.15 Run or prepare the equivalent `fpga-workbench` consumer test, since
  FPGA workflows also need GUI desktop support.
- [ ] gopof.16 Inspect `sv status` for `xvfb`, `openbox`, `x11vnc`, and `novnc`
  inside a fresh Codespace.
- [ ] gopof.17 Confirm the expected long-lived processes are present: `Xvfb`,
  `openbox`, `x11vnc`, and `websockify`.

## Acceptance Criteria

- `Block20` is append-only and does not change the meaning of `Block10`.
- Every repo using the `Block20` baseline image receives the GUI desktop stack
  without repo-local GUI bootstrap installation.
- The GUI services are supervised by runit and remain healthy after startup.
- noVNC serves on the expected local port and connects to the x11vnc backend.
- The desktop note exists at the expected path for the remote user.
- At least one fresh consumer Codespace validates the full path before any stable
  channel movement.
