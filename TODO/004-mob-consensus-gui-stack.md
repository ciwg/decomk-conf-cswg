## Decision Intent Log

ID: DI-004-20260423-133950
Date: 2026-04-23 13:39:50
Status: active
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

- [ ] 004.1 Lock GUI stack boundary for this repo: what remains in devcontainer Features vs what moves to `Makefile` now.
- [ ] 004.2 Add versioned GUI-only apt package targets for `libnotify-bin`, `x11-utils`, and `epiphany-browser`, with append-only naming and isolated GUI wiring.
- [ ] 004.3 Replace `GUIDesktop` placeholder with concrete idempotent targets that compose GUI package installs and GUI runtime setup.
- [ ] 004.4 Implement a decomk-managed noVNC clipboard reminder install target that creates the reminder script and XDG autostart file for the dev user.
- [ ] 004.5 Ensure GUI setup runs in `updateContent` and does not require package installs in `postCreate`.
- [ ] 004.6 Validate GUI and non-GUI paths end-to-end (target graph, package presence, reminder files, and startup behavior).
- [ ] 004.7 Document migration/cleanup follow-up for `mob-sandbox` so overlapping GUI logic can be removed from `.devcontainer/postCreateCommand.sh`.
