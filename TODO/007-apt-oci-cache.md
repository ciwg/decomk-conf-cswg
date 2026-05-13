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
Status: active
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

1. Require `APT_PIN_SNAPSHOT=YYYYMMDDTHHMMSSZ`.
2. Reject unset or malformed snapshot values before touching APT.
3. Pass the user's command through to `apt-get` with `--snapshot "$APT_PIN_SNAPSHOT"`.
4. Keep the wrapper available in `PATH` at Codespaces runtime, like `decomk`.
5. Keep the public wrapper name stable when OCI/blob caching is added later.

## Design Sketch (v1)

### Snapshot wrapper behavior

`apt-pin` is intentionally boring in v1:

- It is a shell script, not Go, because `.devcontainer/Dockerfile` needs it before installing Go.
- It lives in the conf repo as `bin/apt-pin` and is copied to `/usr/local/bin/apt-pin` early in the producer image build.
- It executes `apt-get --snapshot "$APT_PIN_SNAPSHOT" "$@"`.
- It performs only wrapper-level validation; package solving, signature verification, and install behavior stay owned by APT.

### Snapshot ownership

`APT_PIN_SNAPSHOT` is image-owned for now:

- Dockerfile sets it before the first package install.
- The initial producer snapshot is `20260430T000000Z`, which covers the current Dockerfile bootstrap pins and the known stale `vim=2:9.1.0016-1ubuntu7.12` failure case.
- `apt-pin` has no fallback default.
- Makefile migration will use the same variable once the Dockerfile path is proven.

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

- `DI-007-20260513-190436`: v1 is `apt-pin`, not `apt-oci`.
- `DI-007-20260513-190436`: the required configuration source is `APT_PIN_SNAPSHOT`.
- `DI-007-20260513-190436`: the runtime path is `/usr/local/bin/apt-pin`.
- `DI-007-20260513-190436`: the source path is `bin/apt-pin`.
- `DI-007-20260513-190436`: Makefile package target migration is deferred.

## Subtasks

- [x] 007.1 Add a stable reference to a known failure log snippet so we can prove the motivation.
- [x] 007.2 TE: Compare first-run cache population alternatives and write the TE doc under `docs/thought-experiments/` (per AGENTS.md).
- [x] 007.3 Lock the DF decisions for the v1 snapshot-backed `apt-pin` wrapper.
- [x] 007.4 Implement `bin/apt-pin` as the v1 APT snapshot passthrough.
- [x] 007.5 Install `apt-pin` into `/usr/local/bin` during the producer Dockerfile build and use it for Dockerfile package installs.
- [ ] 007.6 Migrate Makefile package install targets from direct `apt-get` to `apt-pin` after producer-image validation.
- [ ] 007.7 Extend selftests to validate unset snapshot failure, snapshot-backed Dockerfile installs, and later Makefile migration.
- [ ] 007.8 Design and implement the future OCI/blob-cache backend behind the `apt-pin` interface.
