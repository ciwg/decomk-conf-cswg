# TODO-sibak: channel branch rendering

## Decision Intent Log

ID: DI-bikor
Date: 2026-05-10 12:04:59 -0700
Status: active
Decision: Store the rendered `overrideCommand` comment in `.decomk/channels.json` using decomk's `devcontainer.comments.overrideCommand` registry field.
Intent: Preserve the existing `DI-fiduv` runit/entrypoint rationale after `.devcontainer/devcontainer.json` became a generated channel artifact.
Constraints: Keep comment data in the channel registry; do not hand-edit the generated devcontainer comment; preserve the main/testing/stable channel registry behavior.
Affects: `.decomk/channels.json`, `.devcontainer/devcontainer.json`, `TODO/TODO-sibak-channel-branch-rendering.md`

ID: DI-losiv
Date: 2026-05-07 15:30:00 -0700
Status: active
Decision: Add a cross-repo ownership boundary to `AGENTS.md` requiring decomk implementation changes to be made only by the Codex session running in `/home/stevegt/lab/decomk`, while this repo may write decomk TODO handoff files to request that work.
Intent: Prevent this conf-repo session from drifting into direct decomk implementation work while preserving a precise, reviewable handoff path for decomk-owned changes needed by this repo.
Constraints: Do not edit decomk production code from this repo session; use decomk TODO files for requests; keep existing channel-renderer rollout work in this repo limited to registry/rendered artifacts after decomk implements the requested renderer support.
Affects: `AGENTS.md`, `TODO/TODO-sibak-channel-branch-rendering.md`, `/home/stevegt/lab/decomk/TODO/018-rendered-devcontainer-comment-preservation.md`

ID: DI-tujul
Date: 2026-05-07 13:38:19 -0700
Status: active
Decision: Make `.decomk/channels.json` the source of branch-channel devcontainer policy for this conf repo and treat `.devcontainer/devcontainer.json` as a rendered artifact produced by `decomk branch render`.
Intent: Keep `main`, `testing`, and `stable` aligned across devcontainer source selection, image tags, conf repo refs, and decomk tool refs without reintroducing scattered `@latest` or mixed-channel defaults.
Constraints: Keep `DECOMK_HOME`, `DECOMK_LOG_DIR`, `RUNIT_*`, and remote identity owned by the image/Dockerfile path; keep `DECOMK_FAIL_NOBOOT` workspace-owned; use `testing`/`stable` decomk branch refs instead of `@latest`; avoid changing GUI/run targets.
Affects: `.decomk/channels.json`, `.devcontainer/devcontainer.json`, `TODO/TODO-sibak-channel-branch-rendering.md`, `TODO/TODO.md`

## Goal

Use the decomk branch renderer to make this repo's active devcontainer channel explicit before Codespaces or checkpoint tooling reads `.devcontainer/devcontainer.json`.

## Subtasks

- [x] sibak.1 Add the channel registry for `main`, `testing`, and `stable`.
- [x] sibak.2 Render the current `main` effective devcontainer file from the registry.
- [ ] sibak.3 Use the registry during the first `testing` and `stable` branch promotion.
