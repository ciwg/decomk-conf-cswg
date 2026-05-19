# TE-fivis: apt-pin cache authority and first-run behavior

TE ID: TE-fivis

## Decision under test

For TODO-hopun, decide whether APT stabilization should start as an OCI cache that any first runner can populate, an explicit manual bundle/push workflow, or a snapshot-backed wrapper with OCI caching deferred behind the same user-facing command.

## Assumptions

- Codespaces lifecycle hooks should stay fire-and-forget for normal users.
- Ordinary consumer Codespaces should not need package-cache write credentials.
- The conf repo needs a near-term fix for exact APT pins disappearing from live Ubuntu mirrors.
- Ubuntu 24.04 supports Canonical's snapshot service through APT's `--snapshot` option.
- Future OCI caching is still useful for long-term blob retention and for non-Ubuntu install assets.

## Alternatives

- A: Any first runner populates the OCI cache through `install`; on miss it downloads, bundles, pushes, pulls, then installs.
- B: A human/operator runs explicit `bundle` and `push` commands before anyone can install from the cache.
- C: One public install command with gated auto-populate; authorized writers populate on miss, unauthorized users fail clearly.
- D: CI/release warmer runs the same install path first so users normally hit the cache.
- E: Start with `apt-pin`, a snapshot-backed `apt-get` wrapper, and defer OCI/blob caching behind the same command name.

## Scenario analysis

Normal missing cache:
- A gives Alice the simplest UX, but makes Alice's environment the cache authority.
- B blocks Alice until Carol performs an operator step.
- C and D keep the user command simple, but still need trusted write environments.
- E avoids cache-miss authority entirely for v1 by asking Ubuntu snapshots for the package state.

Concurrent first runners:
- A creates Alice/Bob races unless tags are content-addressed and pushes verify the winning digest.
- B centralizes the race into Carol's operator action.
- C and D limit races to trusted writers.
- E has no cache-population race in v1.

Auth and trust boundaries:
- A requires broad package-cache write credentials in ordinary Codespaces, which is too much authority for consumer repos.
- B keeps write credentials centralized, but adds manual ceremony.
- C and D are acceptable if write credentials are unavailable outside producer/CI contexts.
- E requires no registry write credentials for v1 and keeps future write authority as a separate backend decision.

APT mirror churn:
- A self-heals only if the first runner arrives while upstream still has the required packages.
- B works when Carol refreshes in time.
- C and D can self-heal from trusted runners only.
- E directly addresses current mirror churn by selecting a dated Ubuntu archive snapshot.

Reproducibility:
- A makes first-arrival time an implicit release decision.
- B is auditable but manual.
- C and D can be auditable with manifests that record source snapshot, package versions, dependency closure, actor, and timestamp.
- E is auditable through APT's single configured `APT::Snapshot` value and preserves a stable command interface for later manifests.

Base image drift:
- A, C, and D must compute dependency closure relative to a declared base image or include base identity in the cache key.
- B has the same obligation but can enforce it manually.
- E leaves dependency solving to APT against a known Ubuntu snapshot and current installed base, which is acceptable for the immediate Dockerfile/bootstrap path.

## Conclusions

- Reject unrestricted A because arbitrary first runners should not define canonical package-cache content.
- Reject B as the normal workflow because it loses the fire-and-forget lifecycle property.
- Keep C and D as future OCI/backend patterns, but only after trusted-writer detection and manifest design are locked.
- Adopt E for v1: `apt-pin` is a small, snapshot-backed wrapper that fixes the current pin-rot problem while keeping the later OCI cache behind the same command.

## Implications for TODO-hopun

- `apt-pin` supersedes `apt-oci` as the immediate implementation.
- APT's `APT::Snapshot` config becomes the required v1 configuration source.
- OCI artifact layout, registry location, and cache-miss policy are deferred.
- The Makefile migration should happen only after the producer Dockerfile path proves the wrapper works.
