# TODO 008 - Codespaces selftest machine fallback

## Decision Intent Log

ID: DI-008-20260515-040231
Date: 2026-05-15 04:02:31 UTC
Status: active
Decision: Use `basicLinux32gb` as the documented default fallback machine for `tools/selftest-codespaces.sh` when noninteractive machine auto-resolution cannot find a repository-specific machine.
Intent: Keep the Codespaces selftest runnable in unattended workflows even when GitHub's existing-codespace/API machine lookup returns no result, while still showing operators exactly how to override the machine explicitly.
Constraints:
- Preserve explicit `--machine` precedence.
- Do not reintroduce interactive machine selection prompts.
- Print a suggested command that includes the resolved repo and branch when fallback is used.
Affects: `tools/selftest-codespaces.sh`, `README.md`, `TODO/008-selftest-codespaces-machine-fallback.md`.

## Subtasks

- [x] 008.1 Lock the default fallback machine decision.
- [x] 008.2 Implement `basicLinux32gb` fallback behavior in `tools/selftest-codespaces.sh`.
- [x] 008.3 Document fallback and override examples in `README.md`.
- [x] 008.4 Validate script syntax, help text, and docs.
