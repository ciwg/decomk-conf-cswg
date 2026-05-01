## Decision Intent Log

ID: DI-004-20260501-182529
Date: 2026-05-01 18:25:29 UTC
Status: active
Decision: Move `DECOMK_HOME`, `DECOMK_LOG_DIR`, and the `RUNIT_*` path contract into `.devcontainer/Dockerfile`, remove fallback definitions for those values from stage-0 and `Makefile`, and keep `DECOMK_FAIL_NOBOOT` owned by `devcontainer.json` with no fallback elsewhere.
Intent: Eliminate split ownership between image bootstrap, workspace config, stage-0, and Make targets so runtime paths come from one authoritative layer and missing configuration fails loudly.
Constraints: Keep the existing runit-backed architecture; preserve current path values; keep `DECOMK_FAIL_NOBOOT` workspace-scoped; avoid unrelated behavioral changes.
Affects: `.devcontainer/Dockerfile`, `.devcontainer/decomk-stage0.sh`, `Makefile`, `TODO/004-mob-consensus-gui-stack.md`

ID: DI-004-20260501-023052
Date: 2026-05-01 02:30:52 UTC
Status: active
Decision: Stop redefining `DECOMK_REMOTE_USER` and `DECOMK_REMOTE_UID` in `Makefile`; instead, require the remote user contract to come from the container/stage-0 environment and derive the UID from the configured username at GUI runtime.
Intent: Remove redundant fallback identity defaults from the conf repo so Dockerfile/stage-0 remain the single source of truth and GUI setup fails loudly if that contract is missing.
Constraints: Keep the current producer-image/stage-0 identity contract intact; preserve existing GUI behavior; avoid broad changes outside `Makefile`; keep Desktop-note ownership behavior correct.
Affects: `Makefile`, `TODO/004-mob-consensus-gui-stack.md`

ID: DI-004-20260430-194224
Date: 2026-04-30 19:42:24 UTC
Status: active
Decision: Fix the producer bootstrap and noVNC landing behavior by updating the stale `openssh-server` package pin in `.devcontainer/Dockerfile` and adding a GUI-time `/usr/share/novnc/index.html -> vnc.html` shim in `gui_runit_sync` so the generated `websockify --web=/usr/share/novnc/` service serves a stable default page only when GUI packages are present.
Intent: Keep the GUI smoke test reproducible with the existing runit/websockify design while removing the two concrete runtime assumptions that failed in container validation.
Constraints: Preserve the current runit-backed GUI architecture; keep `gui_runit_sync` service names and command structure stable; keep the producer Dockerfile GUI-neutral apart from the required bootstrap package pin update; do not introduce new GUI packages or postCreate behavior.
Affects: `.devcontainer/Dockerfile`, `Makefile`, `TODO/004-mob-consensus-gui-stack.md`

ID: DI-004-20260430-182956
Date: 2026-04-30 18:29:56
Status: active
Decision: Use a runit-backed producer image that starts with no GUI services enabled, then let decomk install GUI packages, write runit service definitions into `/etc/sv`, enable them via `/etc/service`, and write only a Desktop clipboard-help note during GUI `postCreate`.
Intent: Preserve decomk's producer/consumer split while moving the GUI stack into explicit, standard system locations and avoiding legacy popup/autostart reminder behavior.
Constraints: Keep `Block10` GUI-neutral; keep package targets append-only, lower-case, and one-package-per-target; keep runit config out of `/var/decomk`; keep Codespaces-managed SSH outside runit; do not add `libnotify-bin`.
Affects: `Makefile`, `decomk.conf`, `.devcontainer/Dockerfile`, `.devcontainer/devcontainer.json`, `TODO/004-mob-consensus-gui-stack.md`
Supersedes: DI-004-20260423-133950

ID: DI-004-20260423-133950
Date: 2026-04-23 13:39:50
Status: superseded
Decision: Create a dedicated GUI-stack TODO driven by the current `mob-sandbox` post-create script so GUI behavior is migrated deliberately into `decomk-conf-cswg` without losing user-facing functionality.
Intent: Preserve the working GUI experience (browser + noVNC clipboard reminder) while moving installs to decomk-managed, versioned, updateContent-first targets.
Constraints: Keep `Block10` GUI-neutral; use one versioned make stanza per package; avoid best-effort/silent-failure patterns from the legacy script; keep non-GUI contexts unchanged.
Affects: `Makefile`, `decomk.conf`, `TODO/TODO.md`, `TODO/004-mob-consensus-gui-stack.md`

## Source Review Summary

Source reviewed: `/home/stevegt/lab/mob-sandbox/.devcontainer/postCreateCommand.sh`

GUI-specific behavior currently in that script:
- Gate: `MOB_SANDBOX_GUI=1`.
- GUI package installs: `libnotify-bin`, `x11-utils`, `epiphany-browser`.
- Browser rationale: prefer Epiphany in container/noVNC flows because Firefox/Chromium apt paths often pull Snap dependencies.
- noVNC clipboard reminder assets:
  - `~/.local/bin/mob-novnc-clipboard-reminder`
  - `~/.config/autostart/mob-novnc-clipboard-reminder.desktop`
- Reminder runtime behavior: use `notify-send` when available; fallback to `xmessage`.

## Task 004 - GUI Stack Migration Plan

- [x] 004.1 Lock GUI stack boundary for this repo: what remains in devcontainer Features vs what moves to `Makefile` now.
- [x] 004.2 Add versioned GUI-only apt package targets for `xvfb`, `openbox`, `x11vnc`, `novnc`, `websockify`, `x11-apps`, `x11-utils`, and `epiphany-browser`, with append-only naming and isolated GUI wiring.
- [x] 004.3 Replace `GUIDesktop` placeholder with concrete idempotent targets that compose GUI package installs and GUI runtime setup.
- [x] 004.4 Implement a decomk-managed GUI user note target that writes `~/Desktop/clipboard-help.md` for the dev user.
- [x] 004.5 Ensure GUI setup runs in `updateContent` and does not require package installs in `postCreate`.
- [x] 004.6 Validate GUI and non-GUI paths end-to-end (target graph, package presence, reminder files, and startup behavior).
- [ ] 004.7 Document migration/cleanup follow-up for `mob-sandbox` so overlapping GUI logic can be removed from `.devcontainer/postCreateCommand.sh`.

Implementation note: the popup/autostart reminder behavior from the legacy script is intentionally not carried forward; this repo now uses a Desktop note file instead.
