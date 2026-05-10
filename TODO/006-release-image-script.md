# TODO 006 - release image script

## Decision Intent Log

ID: DI-006-20260510-141252
Date: 2026-05-10 14:12:52 -0700
Status: active
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
- publish exactly one operator-supplied immutable tag such as `block00` or `block00-rc3`,
- move requested channel aliases such as `main`, `testing`, and `stable`,
- support promote-only retagging from an already-tested immutable source.

## Subtasks

- [x] 006.1 Record the release-image DI and TODO index entry.
- [x] 006.2 Add the `tools/release-image.sh` CLI wrapper.
- [x] 006.3 Validate syntax, shellcheck, and dry-run behavior.
