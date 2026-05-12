# TODO 007 - apt-oci: cache APT .debs in OCI and always install from cache

## Decision Intent Log

ID: DI-007-20260510-163752
Date: 2026-05-10 16:37:52 -0700
Status: active
Decision: Add an `apt-oci` helper that turns an `apt install <pkgs>` request into an OCI-cached bundle (requested packages + dependency closure) and always installs from the cache.
Intent: Eliminate Codespaces build failures caused by upstream APT version pin rot and make decomk builds faster and more repeatable.
Constraints:
- Must work in Makefile recipes and Dockerfiles.
- Must resolve and freeze the current candidate version(s) at runtime.
- Must store each `.deb` as a separate OCI blob plus a small manifest file.
- On cache miss it must download+bundle+push, then install from the pulled bundle (so we always exercise the cache path).
- Default `DECOMK_HOME` is `/var/decomk`.
Affects: `Makefile` package install blocks, new `tools/apt-oci` helper, Codespaces build reliability for repos using `ghcr.io/ciwg/decomk-conf-cswg:*`.

## Background / Problem

We currently pin exact APT package versions in `Makefile` “Block” targets. This is convenient until upstream mirrors drop older patch versions, at which point installs fail and Codespaces builds break.

Example failure (from mob-sandbox Codespaces build logs):

- `apt-get install -y -qq vim=2:9.1.0016-1ubuntu7.12`
- `E: Version '2:9.1.0016-1ubuntu7.12' for 'vim' was not found`

We want to keep the ease of “install these packages” while making the build resilient to mirror churn by caching the exact `.deb` artifacts (and their dependencies) we install.

## Goal

Be able to write something as simple as:

- `apt-oci vim`
- `apt-oci install vim git curl`

…in a Makefile stanza or Dockerfile, and have it:

1. Discover the current candidate version(s) for the requested packages.
2. Compute a stable “bundle identity” based on distro/codename, arch, requested pkgs, frozen versions, and relevant APT flags.
3. Check an OCI registry for that bundle.
4. If present: pull it.
5. If absent: download the requested packages and **all dependencies**, build a local APT repo index, push the bundle to the registry, then pull it back.
6. Install **only from the pulled bundle** (offline) so we never “accidentally succeed from the network” when the cache is incomplete.

## Design Sketch (v1)

### OCI artifact contents

Store one OCI artifact per “bundle” (requested packages + full dependency closure).

Artifact layers/files:

- Each `.deb` as a separate OCI layer/blob (this enables deduplication across bundles via digest addressing).
- `Packages.gz` generated for the directory of `.deb` files.
- `apt-oci.json` manifest containing:
  - bundle metadata (distro/codename, arch, creation time),
  - the user request (e.g. `vim`),
  - the frozen package set (name, version, arch),
  - checksums for each `.deb` (at least sha256),
  - the computed bundle identity.

### Bundle identity / tagging

OCI tags must be tag-safe; Debian versions may contain characters like `:` (epoch) that are not tag-safe. Keep the real versions in `apt-oci.json` and use a hash-based tag.

Recommended tag pattern:

- `pkgset-<short-hash>` where `short-hash = sha256(distro+codename+arch + sorted(pkg=version) + apt flags)` truncated for readability.

Also add OCI annotations so humans can inspect the requested packages without pulling.

### Offline install approach

Install from the pulled bundle by pointing APT at a temporary `file:` repository:

- write a temporary `sources.list` that contains only the local `file:` entry (with `trusted=yes` for v1),
- run `apt-get update` and `apt-get install` with `Dir::Etc::sourcelist=<tmp>` and `Dir::Etc::sourceparts=-` so no other sources are consulted,
- verify `.deb` checksums from `apt-oci.json` before installing.

## Open Questions / Decisions Needed (DF)

- Registry location for the cache:
  - (A) dedicated repo such as `ghcr.io/ciwg/apt-oci-cache`
  - (B) reuse `ghcr.io/ciwg/decomk-conf-cswg` namespace
- Bundle granularity:
  - (A) one artifact per full dependency-closure bundle (recommended)
  - (B) one artifact per package version plus a resolver that fetches deps separately
- Locking behavior:
  - (A) resolve “current candidate” every run (easy, but not deterministic)
  - (B) write/require a lockfile (deterministic, but more ceremony)
- Security / integrity for v1 vs v2:
  - (A) verify checksums + rely on OCI digests and GHCR permissions (v1)
  - (B) sign bundle manifests (e.g. cosign) (v2)

## Subtasks

- [ ] 007.1 Add a stable reference to a known failure log (and/or paste minimal failing snippet) so we can prove the motivation.
- [ ] 007.2 TE: Compare alternative OCI layouts and install strategies, then write the TE doc under `docs/thought-experiments/` (per AGENTS.md).
- [ ] 007.3 Lock the DF decisions (registry path, identity scheme, lockfile policy, security policy).
- [ ] 007.4 Implement `tools/apt-oci` (bash or Go) using ORAS for push/pull and APT for dependency resolution.
- [ ] 007.5 Integrate into the `Makefile` blocks so package installs use `apt-oci` instead of exact `apt-get install pkg=ver` pins.
- [ ] 007.6 Extend `tools/selftest-codespaces.sh` (or add a new selftest) to validate:
  - cache hit path (no network dependency for the packages being installed),
  - cache miss path (opt-in; requires registry creds).
- [ ] 007.7 Document usage in `README.md`, including required GitHub token scopes (`read:packages`/`write:packages`) and required tools (`oras`).
