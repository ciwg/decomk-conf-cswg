# TODO 010 - Move non-trivial Makefile shell logic into bin scripts

## Decision Intent Log

ID: DI-010-20260516-035351
Date: 2026-05-16 03:53:51 UTC
Status: active
Decision: Keep `Makefile` responsible for the dependency graph and short command dispatch only; move non-trivial shell logic into reviewable scripts under `bin/`.
Intent: Avoid fragile Makefile-embedded shell blocks, especially blocks that create additional shell scripts, so runtime behavior is easier to read, lint, test, and maintain. `.ONESHELL` means recipe lines already execute as one shell script per target, so routine recipe line continuations are unnecessary and can accidentally leak make-only syntax such as `@touch` into shell execution.
Constraints:
- Keep target names and dependency graph semantics stable unless a later DI explicitly renames them.
- Keep simple one-command package install stanzas inline.
- Preserve existing GUI runtime behavior and existing user-facing paths.
- Treat the Cocotb system Python install as intentional for the dedicated FPGA container and make that explicit with `--break-system-packages` plus root-owned `HOME`.
Affects: `Makefile`, `bin/gui-runit-sync.sh`, `bin/write-gui-desktop-note.sh`, `bin/install-oss-cad-suite.sh`, `bin/install-cocotb.sh`, `bin/post-create-user-demo.sh`, FPGA and GUI consumer Codespaces.

## Background / Problem

The `Makefile` had several long recipes that were effectively embedded shell scripts. The most fragile example was `gui_runit_sync`, which embedded shell logic that generated multiple runit service shell scripts. The FPGA Cocotb target also used an unnecessary line continuation:

- `pip3 install cocotb==2.0.1 cocotb-bus==0.3.0; \`
- `@touch COCOTB_2_0_1`

Under `.ONESHELL`, that continuation made `@touch` part of the shell script instead of make syntax. The target also attempted a system pip install without acknowledging Ubuntu's PEP 668 guardrails.

## Goal

Keep `Makefile` readable as a target graph:

1. Dependency-only targets remain in the Makefile.
2. Simple apt package stanzas remain inline.
3. Non-trivial behavior moves to `bin/` scripts.
4. Runtime behavior keeps explicit error handling and no silent cleanup.
5. Future maintainers can find policy intent in this TODO and behavior in scripts instead of decoding long Makefile recipes.

## Subtasks

- [x] 010.1 Record the Makefile/script-boundary DI.
- [x] 010.2 Move GUI runit reconciliation into `bin/gui-runit-sync.sh`.
- [x] 010.3 Move GUI Desktop note writing into `bin/write-gui-desktop-note.sh`.
- [x] 010.4 Move OSS CAD Suite installation into `bin/install-oss-cad-suite.sh`.
- [x] 010.5 Move Cocotb installation into `bin/install-cocotb.sh` and make the dedicated-container system install explicit.
- [x] 010.6 Move post-create user evidence writing into `bin/post-create-user-demo.sh`.
- [x] 010.7 Simplify Makefile recipes to script calls and remove unnecessary recipe continuations.
