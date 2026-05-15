# decomk-conf-cswg

This is a decomk configuration repository shared by all CSWG
codespaces.

This repository was bootstrapped by `decomk init -conf`.

A decomk config repo provides shared bootstrap policy and execution logic for
target repositories.

## Stability rule for this README

Do not duplicate live, repo-specific configuration details from:

- `decomk.conf`
- `Makefile`

Examples of details that should stay out of this file:

- active context names,
- current target lists,
- current package/version pins,
- repo-specific wiring choices.

Those belong in `decomk.conf` and `Makefile`, which are the source of truth.

## What this type of repository does

A decomk config repo provides shared bootstrap policy and execution logic:

- `decomk.conf` maps 'decomk' run args to env var tuples.
- `Makefile` contains the executable target graph decomk runs.
- optional helper scripts under `bin/` support Makefile stanzas.

Target repositories invoke stage-0 lifecycle hooks that call
`decomk run <action>` (for example, `updateContent` and `postCreate`).

## `decomk.conf` model (generic)

- RHS tokens are other decomk.conf keys, or env var tuples (`NAME=value`).
- Bare make target names are not used directly on RHS.
- Action tuple values (for example `updateContent='...'`) hold make target lists.
- Compose reusable keys/macros to avoid duplication.

## Makefile model (generic)

- Keep targets idempotent where appropriate.
- Handle command failures explicitly; do not silently ignore errors.
- Split shared baseline work from optional/special feature work.


## How to customize

1. Edit `decomk.conf`:
   - keep `DEFAULT` for shared policy,
   - add/adjust reusable keys and repo-specific keys,
   - update action tuple composition (for example `updateContent='...'` and
     `postCreate='...'`).
2. Edit `Makefile`:
   - replace demo targets with real setup targets,
   - keep targets idempotent where appropriate for repeatable runs.
3. Edit `.devcontainer/devcontainer.json` (producer workspace only):
   - set the desired `DECOMK_CONF_URI`,
   - set the desired `DECOMK_TOOL_URI`,
   - keep lifecycle hooks pointed at `.devcontainer/decomk-stage0.sh`.

## Version and history policy

Devs should NEVER EDIT HISTORY IN THE MAKEFILE.

Only exception: testing/bugfix before deployment of production container(s)
based on the stanza being edited.

For production updates:

1. Add a new stanza for the new version (do not edit old stanzas).
2. Wire the new stanza by appending it to existing target dependencies and/or
   action tuple values in `decomk.conf`.
3. Keep prior versioned stanzas for auditability and rollback context.

## Producer `.devcontainer` workflow

The generated `.devcontainer/Dockerfile` and `build` stanza in
`.devcontainer/devcontainer.json` are intended for the first image ("genesis")
bootstrap only.

After the genesis image is stable:

1. remove the `build` stanza from `.devcontainer/devcontainer.json`,
2. replace it with an `image` stanza that points to your stable channel tag,
3. remove `.devcontainer/Dockerfile` from active use in this repo.

Long-term shared setup should live in `decomk.conf` and `Makefile`; Dockerfile
content should remain minimal.

## Codespaces selftest

Use `tools/selftest-codespaces.sh` to create a real Codespace, wait for it to
become available, capture `/var/decomk`, capture remote environment evidence,
and store the local result bundle under `/tmp`.

Prerequisites:

- `gh` authenticated with Codespaces access.
- `git`, `awk`, `sort`, and `tar` available locally.
- A branch pushed to GitHub; `gh codespace create` cannot test unpublished local
  commits.
- The script tries to resolve a recent or API-provided Codespaces machine, then
  falls back to `basicLinux32gb` when no machine can be resolved.

Typical run:

```bash
tools/selftest-codespaces.sh \
  --repo ciwg/decomk-conf-cswg \
  --branch main \
  --delete-after
```

Useful variants:

```bash
# Keep the Codespace for manual inspection after capture.
tools/selftest-codespaces.sh --repo ciwg/decomk-conf-cswg --branch testing --keep

# Override the fallback or auto-resolved machine explicitly.
tools/selftest-codespaces.sh --repo ciwg/decomk-conf-cswg --branch testing --machine basicLinux32gb --delete-after
```

The script prints `SELFTEST PASS` or `SELFTEST FAIL` at exit. It also prints the
run directory, normally `/tmp/codespace-var-decomk-<UTC timestamp>/`. Inspect:

- `metadata.env` for the Codespace name, branch, capture method, and artifact paths.
- `remote-info.txt` for identity, OS, and `/var/decomk` evidence.
- `codespace.log` and `codespace.log.err` for GitHub Codespaces lifecycle logs.
- `decomk-capture/` and `decomk-capture.tgz` for the captured `/var/decomk` tree.
- `result-reasons.txt` when the selftest fails.

## Image release

Use `tools/release-image.sh` to build or promote a decomk checkpoint image,
publish one immutable tag, and then move one or more channel tags. Immutable
tags such as `block00` or `block00-rc3` are intended never to move. Channel tags
such as `main`, `testing`, and `stable` are moving aliases.

Prerequisites:

- Clean git worktree, unless intentionally using `--allow-dirty`.
- Rendered `.devcontainer/devcontainer.json` is fresh, unless intentionally using
  `--skip-render-check`.
- `decomk`, `docker`, `git`, `jq`, and `sort` available locally.
- Docker authenticated to the target registry, for example GHCR.

Before publishing, inspect any tag that matters:

```bash
docker manifest inspect ghcr.io/<org>/<image>:<tag>
```

Build and publish a new immutable image, then move the `main` channel:

```bash
tools/release-image.sh --immutable-tag block00-rc3 --channel main
```

Move multiple channels from the newly built image:

```bash
tools/release-image.sh \
  --immutable-tag block00-rc3 \
  --channel main \
  --channel testing
```

Promote an existing source image instead of rebuilding:

```bash
tools/release-image.sh \
  --source ghcr.io/<org>/<image>:block00-rc3 \
  --immutable-tag block00-rc3 \
  --channel stable
```

Use `--dry-run` first when checking command shape. The script writes release
artifacts under `/tmp/decomk-conf-cswg-release-image-<run id>/`, including
`metadata.env`, command logs, checkpoint build output, Docker push output, and
per-channel tag/push logs.

## Reference

- https://github.com/stevegt/decomk
