# workspace-config

This repo helps automate setting up and running your dev environment, reliably and repeatedly.

It works with [decomk](https://github.com/stevegt/decomk) to install the right tools for each project. Developers don't interact with this repo directly — their project repos pull from it automatically when a container starts.

## How it works

Each project repo has a `.devcontainer/` folder that points here. When a developer opens a Codespace (or local devcontainer), the bootstrap script:

1. Installs decomk
2. Clones this repo
3. Runs decomk, which reads `decomk.conf` to figure out what to install
4. Runs the matching targets in the `Makefile`

The developer just opens their repo and waits. They don't need to know any of this.

## What's in this repo

- **decomk.conf** — maps project repos to the tools they need
- **Makefile** — defines how each tool is installed, with version pins

## Current projects

| Project | Config key | What it gets |
|---------|-----------|--------------|
| All repos | `DEFAULT` | System tools, goenv, pyenv, Go 1.24.13, Python 3.12 |
| fpga-workbench | `FPGA` | oss-cad-suite, I2C reference repo, cocotb 2.0.1 |

## How to add a new project

1. Open `decomk.conf`
2. Add a line with the repo name and the tools it needs:

```conf
my-new-repo: DEFAULT
```

If it needs FPGA tools too:

```conf
my-new-repo: DEFAULT FPGA
```

3. Commit and push to main

Then in the new project's repo, add a `.devcontainer/` folder with the standard `devcontainer.json` and `postCreateCommand.sh`. Copy them from [fpga-workbench](https://github.com/ciwg/fpga-workbench/tree/decomk-setup/.devcontainer).

## How to add a new tool group

1. Add a target to the `Makefile` with the install steps, ending with `touch $@`
2. If it depends on another target, add the dependency (e.g. `NEWTOOL: TOOLS`)
3. Optionally add a macro to `decomk.conf` to group it (like `FPGA` groups OSS, I2C, and COCOTB)
4. Add the macro or target to the relevant project lines in `decomk.conf`

## How to change a tool version

Edit the version in the `Makefile`. Examples:

- **oss-cad-suite**: change the date in the download URL in the `OSS` target
- **cocotb**: change the version number in `pip install` in the `COCOTB` target
- **Go**: change `1.24.13` in the `GO` target
- **Python**: change `3.12` in the `PYTHON` target

After changing a version, anyone who creates a new container gets the updated version automatically. Existing containers keep the old version until they are rebuilt.

## Pinned versions

| Tool | Version | Where it's set |
|------|---------|---------------|
| Go | 1.24.13 | Makefile → `GO` target |
| Python | 3.12 | Makefile → `PYTHON` target |
| cocotb | 2.0.1 | Makefile → `COCOTB` target |
| cocotb-bus | 0.3.0 | Makefile → `COCOTB` target |
| oss-cad-suite | 2026-03-07 | Makefile → `OSS` target |

## Questions

Talk to JJ or check the [decomk docs](https://github.com/stevegt/decomk).
