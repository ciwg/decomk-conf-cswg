# TODO 006 - release image script

## Decision Intent Log

ID: DI-006-20260510-144211
Date: 2026-05-10 14:42:11 -0700
Status: active
Decision: Use `decomk checkpoint build` only for the build step; perform all release and channel publishing with explicit `docker push`, `docker pull`, `docker tag`, and `docker push` commands.
Intent: Make the release transcript show every registry mutation directly, including the channel tag push after each channel tag is moved, instead of hiding channel pushes inside `decomk checkpoint tag`.
Constraints: Build mode passes `${IMAGE}:${IMMUTABLE_TAG}` directly to `decomk checkpoint build -tag`; build mode checks the immutable tag is absent before building, then pushes it with `docker push`; promote mode pulls `--source`, optionally tags/pushes `${IMAGE}:${IMMUTABLE_TAG}` when `--source` differs, then tags and pushes each requested channel explicitly.
Affects: `tools/release-image.sh`, `TODO/006-release-image-script.md`
Supersedes: DI-006-20260510-142425

ID: DI-006-20260510-142425
Date: 2026-05-10 14:24:25 -0700
Status: superseded
Decision: Pass the canonical release reference `${IMAGE}:${IMMUTABLE_TAG}` directly to `decomk checkpoint build -tag` in build mode, then push that exact tag to the registry.
Intent: Make `--immutable-tag` the build artifact's canonical image tag from the moment decomk commits the checkpoint, so operator-provided tags such as `block00` and `block00-rc3` are not temporary aliases or post-build destinations.
Constraints: Check whether the remote release tag already exists before the build path pushes it; do not generate or use a temporary local build-source tag; keep `RUN_ID` only for artifact directory uniqueness; keep promote mode able to publish a distinct `--source` to the requested immutable tag.
Affects: `tools/release-image.sh`, `TODO/006-release-image-script.md`
Supersedes: DI-006-20260510-142027

ID: DI-006-20260510-142027
Date: 2026-05-10 14:20:27 -0700
Status: superseded
Decision: Remove the public `--stamp` release-image argument and generate an internal `RUN_ID` for artifact directory names and temporary local build-source tags.
Intent: Keep the public release interface focused on operator-owned image tags; callers who need a deterministic artifact path can use `--out-dir` instead of controlling an unrelated timestamp flag.
Constraints: Do not let the generated run identifier affect any published registry tag; include the shell process ID in `RUN_ID` so same-second invocations do not collide; keep `/tmp/decomk-conf-cswg-release-image-<RUN_ID>/` as the default artifact pattern; keep the temporary `decomk-release:<immutable>-<RUN_ID>` tag local to the build/push handoff.
Affects: `tools/release-image.sh`, `TODO/006-release-image-script.md`
Supersedes: DI-006-20260510-141252

ID: DI-006-20260510-141252
Date: 2026-05-10 14:12:52 -0700
Status: superseded
Decision: Replace the generated `--block`/candidate/immutable tag model with an explicit `--immutable-tag` operator input; the script publishes exactly `${IMAGE}:${IMMUTABLE_TAG}` and moves only the requested channel tags to that release reference.
Intent: Keep release tag naming under operator control so tags such as `block00` and `block00-rc3` mean exactly what the operator typed instead of being expanded into additional candidate, timestamped immutable, or block-alias tags by the script.
Constraints: Keep checkpoint build/push/tag as the underlying mechanism; use an internal local build source only when checkpoint build needs a temporary local tag; do not expose or persist the old generated candidate/immutable/block-alias metadata model; preserve strict preflight and `/tmp/decomk-conf-cswg-release-image-<UTCSTAMP>/` artifacts.
Affects: `tools/release-image.sh`, `TODO/006-release-image-script.md`
Supersedes: DI-006-20260510-134857

ID: DI-006-20260510-134857
Date: 2026-05-10 13:48:57 -0700
Status: superseded
Decision: Add `tools/release-image.sh` as a checkpoint-backed release helper that builds candidate images, pushes immutable block-stamped tags, and moves explicit block/channel aliases with `decomk checkpoint tag -m`.
Intent: Make the periodic producer-image release workflow repeatable and auditable without bypassing decomk checkpoint's existing build/push/tag guardrails.
Constraints: Use a flags-only CLI; require `--block` and explicit repeatable `--channel` values; infer `--image` from `.decomk/channels.json` when possible; fail strict preflight checks unless explicitly skipped; write runtime artifacts under `/tmp/decomk-conf-cswg-release-image-<UTCSTAMP>/`; keep immutable tag publishing separate from moving aliases so accidental immutable overwrites still fail.
Affects: `tools/release-image.sh`, `TODO/006-release-image-script.md`, `TODO/TODO.md`

## Goal

Provide an operator script for periodic image releases:

- build a checkpoint image from the current rendered devcontainer,
- pass exactly one operator-supplied immutable tag such as `block00` or `block00-rc3` to `decomk checkpoint build -tag`,
- push that exact immutable tag to the registry,
- move requested channel aliases such as `main`, `testing`, and `stable` with explicit Docker tag/push commands,
- support promote-only retagging from an already-tested immutable source,
- generate an internal run identifier only for local artifacts.

## Subtasks

- [x] 006.1 Record the release-image DI and TODO index entry.
- [x] 006.2 Add the `tools/release-image.sh` CLI wrapper.
- [x] 006.3 Validate syntax, shellcheck, and dry-run behavior.
