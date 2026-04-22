# decomk-conf-cswg

Shared configuration for dev environment setup. Works with
[decomk](https://github.com/stevegt/decomk) to install the right tools
for each project.

Developers don't interact with this repo directly — their project repos
pull from it automatically when a container starts.

See `gold-server/glossary.md` for how this repo fits alongside
workspace-base, fpga-workbench, and decomk.

## How it works

Each project repo's `.devcontainer/` has a `postCreateCommand.sh` that:

1. Ensures decomk is on `PATH`
2. Clones this repo to `/var/decomk/conf`
3. Runs `decomk run`

decomk reads `decomk.conf`, resolves the project name to a set of Make
targets, and runs the Makefile. Stamp files in `/var/decomk/stamps/`
make re-runs idempotent.

## What's in this repo

- **decomk.conf** — maps project repo names to tool sets.
- **Makefile** — defines every install target, in order, with version
  pins and stamp-based idempotency.

## Block structure

The Makefile groups targets into blocks that mirror the gold-image
versions:

- `block00` — Microsoft base + decomk (placeholder; content lives in
  workspace-base Dockerfile)
- `block0`  — `block00` + TOOLS + GO + PYTHON (gold-image payload)
- `block10` — `block0` + next shared layer (reserved)
- `DEFAULT` — alias for `block0`, kept so existing `decomk.conf` entries
  continue to resolve

Project keys in `decomk.conf` depend on `DEFAULT` plus any project-specific
macros (e.g. `FPGA`).

## Current projects

| Project        | Config key        | What it adds on top of block0 |
|----------------|-------------------|-------------------------------|
| fpga-workbench | `DEFAULT FPGA`    | oss-cad-suite, I2C reference, cocotb 2.0.1 |

## How to add a new project

1. Open `decomk.conf`
2. Add a line mapping the repo name to its tool set:

    ```
    my-new-repo: DEFAULT
    ```

    or, if it needs FPGA tools:

    ```
    my-new-repo: DEFAULT FPGA
    ```

3. Commit and push.
4. In the new project repo, add a `.devcontainer/` — copy from
   [fpga-workbench/.devcontainer](https://github.com/ciwg/fpga-workbench/tree/decomk-setup/.devcontainer).

## How to add a new tool group

1. Add a target to the Makefile with install steps, ending with
   `touch $@` (so decomk's stamp dir records the success).
2. Add its prereqs (e.g. `NEWTOOL: block0` if it needs the gold-image
   shared layer).
3. Optionally add a macro to `decomk.conf` to group related targets
   (`FPGA` groups OSS, I2C, COCOTB).
4. Add the macro or target to project lines in `decomk.conf`.

## Pinning policy

Every package install is pinned.

- **apt packages**: pinned to exact Ubuntu 24.04 (noble) versions, as of
  the workspace-base Dockerfile's base image sha256. When that digest
  is updated, re-query versions (see `workspace-base/README.md`) and
  update both files together.
- **Go**: pinned via goenv in the GO target.
- **Python**: pinned via pyenv in the PYTHON target.
- **cocotb, cocotb-bus**: pinned in the COCOTB target.
- **oss-cad-suite**: pinned by release date in the OSS target URL.

Unpinned installs are not permitted. LLMs that suggest "this package is
stable enough, no need to pin" are wrong.

## How to change a tool version (append-only policy)

Devs should NEVER EDIT HISTORY IN THE MAKEFILE.

Only exception: during testing/bugfix before deployment of production
container(s) based on the stanza being edited.

For all production changes, use append-only updates:

1. Create a new Makefile stanza for the new version (do not modify old
   stanzas).
2. Wire the new stanza by one of these methods:
   - add it to the end of the target list for an existing Makefile
     stanza, or
   - add it to the RHS of a key in `decomk.conf`.

Example 1: add new stanza to the end of an existing Makefile target list.

```make
GO_1_24_14: TOOLS
	# install/pin Go 1.24.14
	touch $@

Block10: block00 TOOLS GO PYTHON GO_1_24_14
   # never call 'touch' in Block (checkpoint) stanzas -- that would
   # prevent additions to the prereq list and break the append-only policy
```

Example 2: add new stanza to the RHS of a key in `decomk.conf`.

```conf
DEFAULT: TOOLS GO PYTHON GO_1_24_14 SETUP='TOOLS GO PYTHON'

somerepo: GO_1_24_14
```

After adding a new version stanza and wiring it in, the next container
create picks up the new version. Existing containers keep the old
version until rebuilt.

## Pinned versions (current)

| Tool           | Version                           | Target |
|----------------|-----------------------------------|--------|
| Go             | 1.24.13                           | GO     |
| Python         | 3.12                              | PYTHON |
| cocotb         | 2.0.1                             | COCOTB |
| cocotb-bus     | 0.3.0                             | COCOTB |
| oss-cad-suite  | 2026-03-07                        | OSS    |

For apt package pins, see the `TOOLS` target in the Makefile.

## Questions

Talk to JJ or check the [decomk docs](https://github.com/stevegt/decomk).
