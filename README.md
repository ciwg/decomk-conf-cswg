# decomk-conf-cswg

This is a decomk configuration repository shared by all CSWG
codespaces.

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

Target repos invoke decomk stage-0 hooks, which call `decomk run <action>`
(e.g. `updateContent` and `postCreate`).

## `decomk.conf` model (generic)

- RHS tokens are other decomk.conf keys, or env var tuples (`NAME=value`).
- Bare make target names are not used directly on RHS.
- Action tuple values (for example `updateContent='...'`) hold make target lists.
- Compose reusable keys/macros to avoid duplication.

## Makefile model (generic)

- Keep targets idempotent where appropriate.
- Handle command failures explicitly; do not silently ignore errors.
- Split shared baseline work from optional/special feature work.

## Version and history policy

Devs should NEVER EDIT HISTORY IN THE MAKEFILE.

Only exception: testing/bugfix before deployment of production container(s)
based on the stanza being edited.

For production updates:

1. Add a new stanza for the new version (do not edit old stanzas).
2. Wire the new stanza by appending it to existing target dependencies and/or
   action tuple values in `decomk.conf`.
3. Keep prior versioned stanzas for auditability and rollback context.

## Producer `.devcontainer` note

If this repo includes a producer workspace:

- a `build` stanza is typically for genesis/bootstrap only,
- after stabilization, switch to a pinned image reference,
- long-term provisioning logic should live in `decomk.conf` and `Makefile`,
  not only in Dockerfile layers.

## Reference

For decomk behavior and commands, see:

- https://github.com/stevegt/decomk
