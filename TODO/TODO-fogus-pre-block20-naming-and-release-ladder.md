# TODO-fogus - Pre-Block20 naming and release ladder

## Decision Intent Log

ID: DI-ruvop
Date: 2026-05-18 11:33:29 -0700
Status: active
Decision: Before any Block00, Block10, or Block20 image release work, migrate coordination artifacts to proquint handles, then clean up underscore-heavy Makefile target and decomk context names; release each block by building an `-rcN` immutable tag first, testing that exact image, and promoting the tested digest to the final block tag without rebuilding.
Intent: Keep the artifact namespace and operational target names clean before publishing more baseline images, and avoid treating an untested rebuild as equivalent to a tested release candidate.  The final `block00`, `block10`, and `block20` tags should be registry promotions of already-tested RC images, not fresh builds.
Constraints: Preserve identifier-style variables and public action names such as `updateContent`, `postCreate`, `HELLO_TEXT`, `DECOMK_*`, `RUNIT_*`, and Make variables; keep existing historical IDs discoverable through a generated cross-reference; never overwrite immutable image tags; if an RC fails, cut the next `-rcN` tag.
Affects: `TODO/`, `docs/thought-experiments/`, `AGENTS.md`, `Makefile`, `decomk.conf`, `README.md`, `tools/`, `numeric-proquint-xref.md`, release-image workflow, Codespaces selftests, and consumer repo validation.

## Goal

Prepare the repo for Block20 by doing the namespace cleanup first, then cutting
Block00, Block10, and Block20 through an RC-tested release ladder.

## Subtasks

- [x] fogus.1 Add local proquint tooling for minting, migration, citation sweeping, and index/xref generation.
- [x] fogus.2 Migrate TODO, TE, and DI artifact IDs from integer/timestamp forms to proquint handles.
- [x] fogus.3 Create `numeric-proquint-xref.md` and `tools/migrate-handles/mapping.tsv` so old IDs remain discoverable.
- [x] fogus.4 Update AGENTS and README guidance so new TODO, TE, and DI artifacts use proquint handles.
- [x] fogus.5 Apply hyphen-name cleanup to Makefile targets and decomk contexts before any image build/tag/push work.
- [x] fogus.6 Validate post-cleanup `decomk plan updateContent` and `decomk plan postCreate` for this repo, `mob-sandbox`, `fpga-workbench`, and the GUI selftest context.
- [x] fogus.7 Build and test `block00-rc7`; if it passes, promote the same digest to `block00` and move `main`.
- [ ] fogus.8 Switch `main` from devcontainer `build` to `ghcr.io/ciwg/decomk-conf-cswg:main`, advance the producer context to `Block10`, then build and test `block10-rc1`; if it passes, promote the same digest to `block10` and move `main`.
- [ ] fogus.9 Make GUI default in Block20, then build and test `block20-rc1`; if it passes, promote the same digest to `block20` and move `main`.
- [ ] fogus.10 Run consumer validation for `mob-sandbox` and `fpga-workbench` after each channel-moving release step.

## Release command pattern

Build an RC image with the operator-chosen immutable RC tag:

```bash
tools/release-image.sh --immutable-tag block10-rc1 --channel main
```

Promote the tested RC digest to the final immutable block tag without
rebuilding:

```bash
tools/release-image.sh \
  --source ghcr.io/ciwg/decomk-conf-cswg:block10-rc1 \
  --immutable-tag block10 \
  --channel main
```

The same pattern applies to `block00`, `block10`, and `block20`.  A failed RC is
retired by moving forward to the next tag such as `block10-rc2`; no immutable
tag is reused.

## Block10 transition notes

Before building `block10-rc1`, `main` must stop using the genesis `build`
stanza. Update `.decomk/channels.json` so `channels.main` uses
`image: ghcr.io/ciwg/decomk-conf-cswg:main`, render
`.devcontainer/devcontainer.json`, then advance the `decomk-conf-cswg` context
from `Block00` to `Block10`.

## Acceptance criteria

- Proquint IDs are the active artifact IDs for TODO, TE, and DI records.
- Historical integer and timestamp IDs remain findable through the xref and mapping files.
- Active Makefile targets and decomk contexts no longer use underbars where hyphens are valid.
- `block00`, `block10`, and `block20` final tags each point to the tested RC digest for that block.
- Normal and GUI Codespaces selftests pass at the required points in the ladder.
- `mob-sandbox` and `fpga-workbench` pass their consumer validation after channel movement.
