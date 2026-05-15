# TODO 009 - Replace OSS CAD Suite wget fetch with OCI cache

## Decision Intent Log

ID: DI-009-20260515-042945
Date: 2026-05-15 04:29:45 UTC
Status: active
Decision: Replace the direct `wget` fetch in the `Makefile` `OSS_20260307` target with a cache-backed artifact fetch that uses the same future OCI cache authority planned for `apt-pin`.
Intent: Keep large non-APT build artifacts under the same repeatability and availability model as package installs, so Codespaces builds are not exposed directly to upstream GitHub release availability, URL churn, or repeated large downloads.
Constraints:
- Do not change `OSS_20260307` behavior until the shared OCI cache backend has a locked design and trusted-writer policy.
- Preserve the current installed layout under `/opt/oss-cad-suite` unless a later Decision Intent entry explicitly changes it.
- Preserve the current Makefile dependency graph shape for `FPGA_1` unless a later Decision Intent entry explicitly changes target names.
- Treat upstream URL, expected digest, extracted path, OCI reference, cache metadata, and fallback policy as future DF decisions.
Affects: `Makefile`, `OSS_20260307`, `FPGA_1`, future OCI cache backend behind `apt-pin`, FPGA consumer Codespaces.

## Background / Problem

`Makefile` currently downloads OSS CAD Suite directly from GitHub releases:

- target: `OSS_20260307`
- URL: `https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-03-07/oss-cad-suite-linux-x64-20260307.tgz`
- temp artifact: `/tmp/oss-cad-suite.tgz`
- install root: `/opt/oss-cad-suite`

That direct fetch has the same reliability problem as raw upstream APT access: it depends on an external service and exact upstream object remaining reachable at build time. The future `apt-pin` OCI backend should therefore not be APT-only in spirit; it should also support large pinned blobs needed by repo-specific Makefile targets.

## Goal

Replace the direct `wget` path with a cache-backed flow that:

1. Resolves the OSS CAD Suite archive by immutable version and digest.
2. Retrieves it from the shared OCI cache when available.
3. Populates or refreshes the cache only through the same trusted-writer policy used by the future `apt-pin` backend.
4. Verifies the downloaded blob before extraction.
5. Keeps the `FPGA_1` setup fire-and-forget for normal Codespaces users.

## Open Design Questions

- Whether the shared cache interface should be a generic blob helper, an `apt-pin` subcommand, or a separate decomk-managed tool.
- Whether the OCI reference should be derived from URL+digest, Make target name, upstream release version, or a repo-managed lockfile.
- Whether normal Codespaces users may read only, while producer/release jobs may populate cache misses.
- Whether direct upstream fallback is allowed on cache miss, and if so only for trusted writer contexts.
- How extracted-tree validation should work after the archive is pulled and unpacked.

## Subtasks

- [ ] 009.1 Run a TE comparing direct `wget`, generic OCI blob helper, `apt-pin` subcommand, and decomk-managed artifact helper designs.
- [ ] 009.2 Lock DF decisions for cache interface name, OCI reference format, digest policy, trusted-writer behavior, and fallback behavior.
- [ ] 009.3 Add a manifest or lock entry for the OSS CAD Suite archive, including source URL, version, digest, expected extracted root, and OCI reference.
- [ ] 009.4 Replace the `OSS_20260307` direct `wget` recipe with the locked cache-backed fetch flow.
- [ ] 009.5 Validate the FPGA setup path in a consumer Codespace or realistic container-like smoke test.
