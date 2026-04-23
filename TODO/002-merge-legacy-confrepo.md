## Decision Intent Log

ID: DI-002-20260423-182418
Date: 2026-04-23 18:24:18
Status: active
Decision: Merge legacy `old/*` operational content into the current `decomk init-conf` scaffold while preserving the current decomk stage-0 and tuple-only policy model.
Intent: Keep modern decomk compatibility and lifecycle semantics while retaining important JJ-era policy, target graph, and tooling knowledge needed for shared repo operation.
Constraints: Prefer current scaffold contract (`updateContent`/`postCreate` action args, tuple-only RHS in `decomk.conf`), use `Block*` naming for shared baseline layers, keep repo keys as bare repo names with comments for owner/repo customization, drop legacy `SETUP` alias, and keep explicit error handling (no silent failure patterns).
Affects: `decomk.conf`, `Makefile`, `README.md`, `.devcontainer/devcontainer.json`, `.devcontainer/decomk-stage0.sh`, `TODO/TODO.md`, `TODO/002-merge-legacy-confrepo.md`

ID: DI-002-20260423-183647
Date: 2026-04-23 18:36:49
Status: active
Decision: Remove `DECOMK_STAGE0_PHASE` mismatch guards from `updateContent` and `postCreate` targets.
Intent: Keep lifecycle targets directly runnable for manual troubleshooting because decomk already selects the action target and does not require make-side phase enforcement.
Constraints: Preserve existing target dependency graph and runtime logging behavior; do not remove `DECOMK_STAGE0_PHASE` environment usage from `PostCreateUser`.
Affects: `Makefile`, `TODO/002-merge-legacy-confrepo.md`

ID: DI-002-20260423-184207
Date: 2026-04-23 18:42:07
Status: active
Decision: Replace monolithic pinned `TOOLS` install recipe with one versioned apt target stanza per package and wire those versioned targets into `Block10`.
Intent: Make package history append-only and auditable by package/version while keeping baseline composition explicit in `Block10`.
Constraints: Preserve existing pinned package set and versions, keep explicit error handling policy, and avoid reintroducing an unversioned aggregate apt install stanza.
Affects: `Makefile`, `README.md`, `TODO/002-merge-legacy-confrepo.md`

ID: DI-002-20260423-185531
Date: 2026-04-23 18:55:31
Status: active
Decision: Keep simple versioned apt package install target names lowercase (for example `apt_vim_...`) instead of uppercase `APT_*`.
Intent: Preserve readable, consistent target naming style for package-only stanzas while retaining append-only version semantics.
Constraints: Apply to simple apt package install targets and their references; keep existing behavior and pinned versions unchanged.
Affects: `Makefile`, `README.md`, `TODO/002-merge-legacy-confrepo.md`

ID: DI-002-20260423-192405
Date: 2026-04-23 19:24:05
Status: active
Decision: Remove `apt_` prefix from simple package install targets, align post-create user target naming to `PostCreateUser`, and replace `GO`/`PYTHON` env-manager targets with versioned distro package targets.
Intent: Keep target names concise and consistent, eliminate naming drift between `decomk.conf`/README/Makefile, and rely on container+distro package management for Go/Python runtime versions instead of goenv/pyenv bootstrapping.
Constraints: Preserve append-only versioning pattern, keep pinned package versions explicit in target names, remove goenv/pyenv bootstrap logic, and keep behavior compatible with existing `Block10`/`FPGA` graphs.
Affects: `Makefile`, `README.md`, `TODO/002-merge-legacy-confrepo.md`
Supersedes: DI-002-20260423-185531

ID: DI-002-20260423-192931
Date: 2026-04-23 19:29:31
Status: active
Decision: Rename post-create user evidence target from `PostCreateUser` to `postCreateUserDemo`.
Intent: Keep target naming aligned with requested project convention and ensure tuple/action references match executable Make target names.
Constraints: Update all references in `decomk.conf`, `Makefile`, and `README.md` together; preserve existing behavior and target dependencies.
Affects: `Makefile`, `decomk.conf`, `README.md`, `TODO/002-merge-legacy-confrepo.md`

## Task 002 - Merge Legacy Confrepo Content

- [x] 002.1 Rebuild `decomk.conf` with tuple-only action variables and repo contexts (`fpga-workbench`, `mob-sandbox`).
- [x] 002.2 Rebuild `Makefile` with `Block*` baseline layering, shared/special target split, and explicit error handling.
- [x] 002.3 Update `.devcontainer` stage-0 and env contract to match current decomk templates and real conf URI.
- [x] 002.4 Rewrite `README.md` to document merged architecture, lifecycle actions, append-only policy, and customization workflow.
- [x] 002.5 Validate merged config using `decomk plan` across key contexts/actions.
- [x] 002.6 Record compliance artifacts and close TODO 002.
- [x] 002.7 Split pinned apt tooling into versioned per-package stanzas and wire into `Block10`.
- [x] 002.8 Rename simple versioned apt package install targets to lowercase and update references/docs.
- [x] 002.9 Remove `apt_` prefix from simple package install targets and align references/docs.
- [x] 002.10 Replace `GO`/`PYTHON` env-manager targets with versioned distro package targets.
- [x] 002.11 Rename `PostCreateUser` target and references to `postCreateUserDemo`.
