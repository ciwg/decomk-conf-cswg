# TODO 007 - apt-pin: use Ubuntu snapshots now, OCI cache later

## Decision Intent Log

ID: DI-007-20260510-163752
Date: 2026-05-10 16:37:52 -0700
Status: superseded
Decision: Add an `apt-oci` helper that turns an `apt install <pkgs>` request into an OCI-cached bundle (requested packages + dependency closure) and always installs from the cache.
Intent: Eliminate Codespaces build failures caused by upstream APT version pin rot and make decomk builds faster and more repeatable.
Constraints:
- Must work in Makefile recipes and Dockerfiles.
- Must resolve and freeze the current candidate version(s) at runtime.
- Must store each `.deb` as a separate OCI blob plus a small manifest file.
- On cache miss it must download+bundle+push, then install from the pulled bundle (so we always exercise the cache path).
- Default `DECOMK_HOME` is `/var/decomk`.
Affects: `Makefile` package install blocks, new `tools/apt-oci` helper, Codespaces build reliability for repos using `ghcr.io/ciwg/decomk-conf-cswg:*`.

ID: DI-007-20260513-190436
Date: 2026-05-13 19:04:36 UTC
Status: superseded
Decision: Replace the immediate `apt-oci` implementation with `apt-pin`, a `PATH`-installed `apt-get` passthrough that requires `APT_PIN_SNAPSHOT` and injects Ubuntu's `--snapshot` option for every APT command it runs.
Intent: Stabilize Codespaces package installs quickly with Canonical's snapshot service while preserving a single wrapper interface that can later grow an OCI/blob-cache backend without changing Makefile call sites again.
Constraints:
- Keep v1 small enough to use in `.devcontainer/Dockerfile` before Go, ORAS, or decomk are installed.
- Set `APT_PIN_SNAPSHOT` in the image/Dockerfile environment before `apt-pin update` or `apt-pin install` runs.
- Fail loudly when `APT_PIN_SNAPSHOT` is unset or malformed; do not provide hidden fallbacks.
- Keep the current Makefile package target wiring unchanged until `apt-pin` is proven in the producer image path.
- Defer OCI bundle layout, registry location, and cache-miss population policy to a later backend decision behind the `apt-pin` interface.
Affects: `bin/apt-pin`, `.devcontainer/Dockerfile`, `TODO/007-apt-oci-cache.md`, `TODO/TODO.md`, `docs/thought-experiments/TE-20260513-180434-apt-pin-cache-authority.md`
Supersedes: DI-007-20260510-163752

ID: DI-007-20260513-195450
Date: 2026-05-13 19:54:50 UTC
Status: active
Decision: Make APT's `APT::Snapshot` configuration the v1 snapshot authority; `apt-pin` validates that configuration and delegates to plain `apt-get` without passing `--snapshot` itself.
Intent: Pin raw `apt-get` and `apt-pin` through one system-level APT epoch so Codespaces package setup behaves like an image-local package source while later Block* milestones can advance the configured snapshot deliberately.
Constraints:
- Write `/etc/apt/apt.conf.d/50snapshot` before any `apt-pin update` or package install runs.
- Do not accept `APT_PIN_SNAPSHOT` as an alternate source of truth in v1.
- Keep `bin/apt-pin` small enough to use before Go, ORAS, or decomk are installed.
- Keep the current Makefile package target wiring unchanged until a later Makefile migration.
- Assume Block* progression is monotonic; old package prereqs are not expected to be manually rerun after later snapshot transitions.
Affects: `bin/apt-pin`, `.devcontainer/Dockerfile`, `TODO/007-apt-oci-cache.md`, `docs/thought-experiments/TE-20260513-180434-apt-pin-cache-authority.md`
Supersedes: DI-007-20260513-190436

ID: DI-007-20260514-050759
Date: 2026-05-14 05:07:59 UTC
Status: active
Decision: Align the `Block10` `openssh-client` package target with the image-owned `20260430T000000Z` APT snapshot by moving the pinned version from `1:9.6p1-3ubuntu13.15` to `1:9.6p1-3ubuntu13.16`.
Intent: Fix the mob-sandbox consumer selftest failure without broadening the change into the deferred Makefile `apt-pin` migration; the published `main` image already pins raw `apt-get` to the snapshot, and Docker validation showed every current Makefile package pin except `openssh-client=1:9.6p1-3ubuntu13.15` is installable from that snapshot.
Constraints:
- Keep the Makefile using direct `apt-get` for now because `DI-007-20260513-195450` explicitly defers the broader Makefile migration.
- Preserve versioned Makefile target names so the changed package version is visible in the dependency graph.
- Do not change the producer image snapshot while fixing this consumer-only pin mismatch.
Affects: `Makefile`, `TODO/007-apt-oci-cache.md`, consumer Codespaces that install `Block10`.

## Background / Problem

We currently pin exact APT package versions in `Makefile` “Block” targets. This is convenient until upstream mirrors drop older patch versions, at which point installs fail and Codespaces builds break.

Example failure (from mob-sandbox Codespaces build logs):

- `apt-get install -y -qq vim=2:9.1.0016-1ubuntu7.12`
- `E: Version '2:9.1.0016-1ubuntu7.12' for 'vim' was not found`

We want to keep the ease of “install these packages” while making the build resilient to mirror churn. The fastest stable path is to install from a known Ubuntu snapshot now, then add an OCI-backed blob/cache backend later if snapshots are not enough.

## Goal

Be able to write something as simple as:

- `apt-pin update -qq`
- `apt-pin install -y -qq vim=2:9.1.0016-1ubuntu7.12`

…in a Makefile stanza or Dockerfile, and have it:

1. Require `APT::Snapshot "YYYYMMDDTHHMMSSZ";` in APT config.
2. Reject unset or malformed snapshot values before touching package state.
3. Pass the user's command through to plain `apt-get`.
4. Keep the wrapper available in `PATH` at Codespaces runtime, like `decomk`.
5. Keep the public wrapper name stable when OCI/blob caching is added later.

## Design Sketch (v1)

### Snapshot wrapper behavior

`apt-pin` is intentionally boring in v1:

- It is a shell script, not Go, because `.devcontainer/Dockerfile` needs it before installing Go.
- It lives in the conf repo as `bin/apt-pin` and is copied to `/usr/local/bin/apt-pin` early in the producer image build.
- It reads `APT::Snapshot` with `apt-config shell Snapshot APT::Snapshot`.
- It executes `apt-get "$@"` after validating the configured snapshot.
- It performs only wrapper-level validation; package solving, signature verification, and install behavior stay owned by APT.

### Snapshot ownership

APT config is the snapshot source of truth:

- Dockerfile writes `/etc/apt/apt.conf.d/50snapshot` before the first package install.
- The initial producer snapshot is `20260430T000000Z`, which covers the current Dockerfile bootstrap pins and the known stale `vim=2:9.1.0016-1ubuntu7.12` failure case.
- `apt-pin` has no fallback default and does not accept `APT_PIN_SNAPSHOT` as another authority.
- Future Makefile migration should use a first prereq such as `apt_snapshot_20260601` to advance `/etc/apt/apt.conf.d/50snapshot`, run `apt-pin update -qq`, and then build the new package prereqs.
- Block progression is expected to be monotonic; old prereqs are not expected to be manually rerun after later snapshot transitions.

### Future OCI/blob-cache backend

The future backend should keep `apt-pin install ...` as the user-facing interface. Surviving cache-design conclusions from `TE-20260513-180434`:

- Keep fire-and-forget UX for users.
- Allow cache population only from trusted writer environments.
- Treat manual bundle/push as an operator escape hatch, not the normal path.
- Preserve enough manifest metadata to prove source snapshot, package versions, dependency closure, actor, and timestamp.

## Deferred OCI Questions

These are deliberately not v1 decisions:

- Registry location for package/blob cache artifacts.
- OCI artifact layout and media types.
- Bundle identity and lockfile policy.
- Authorized-writer detection and cache-miss race handling.
- Whether the OCI implementation uses the `oras` CLI, `oras-go`, or `apt-transport-oci`.
- Go toolchain strategy for future ORAS work; current `oras-go v2.6.0` requires Go 1.23+, while the current Dockerfile still pins Ubuntu's Go 1.22 package.

## Decision Lock Summary

- `DI-007-20260513-195450`: v1 is `apt-pin`, not `apt-oci`.
- `DI-007-20260513-195450`: the required configuration source is APT's `APT::Snapshot`.
- `DI-007-20260513-195450`: the runtime path is `/usr/local/bin/apt-pin`.
- `DI-007-20260513-195450`: the source path is `bin/apt-pin`.
- `DI-007-20260513-195450`: Makefile package target migration is deferred.
- `DI-007-20260514-050759`: `Block10` uses `openssh-client=1:9.6p1-3ubuntu13.16` for the current `20260430T000000Z` snapshot.

## Subtasks

- [x] 007.1 Add a stable reference to a known failure log snippet so we can prove the motivation.
- [x] 007.2 TE: Compare first-run cache population alternatives and write the TE doc under `docs/thought-experiments/` (per AGENTS.md).
- [x] 007.3 Lock the DF decisions for the v1 snapshot-backed `apt-pin` wrapper.
- [x] 007.4 Implement `bin/apt-pin` as the v1 APT snapshot passthrough.
- [x] 007.5 Install `apt-pin` into `/usr/local/bin` during the producer Dockerfile build and use it for Dockerfile package installs.
- [ ] 007.6 Migrate Makefile package install targets from direct `apt-get` to `apt-pin` after producer-image validation.
- [ ] 007.7 Extend selftests to validate missing apt-config snapshot failure, snapshot-backed Dockerfile installs, and later Makefile migration.
- [ ] 007.8 Design and implement the future OCI/blob-cache backend behind the `apt-pin` interface.
- [x] 007.9 Align the `Block10` `openssh-client` pin with the current producer image snapshot after the mob-sandbox consumer selftest failed.
