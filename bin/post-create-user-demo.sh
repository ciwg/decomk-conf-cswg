#!/bin/bash
set -euo pipefail

# Intent: Keep a runtime/user-level evidence hook that appends per-user entries
# on every postCreate run without relying on stamp-skipped file targets.
# Source: DI-002-20260423-182418 (TODO/002)

user="${GITHUB_USER:-unknown-user}"
dest_dir="${DECOMK_HOME:?DECOMK_HOME must be set}/users"
gui="${DEVCONTAINER_GUI:-0}"

mkdir -p "$dest_dir"

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s phase=%s user=%s repo=%s gui=%s\n' \
  "$timestamp" \
  "${DECOMK_STAGE0_PHASE:-postCreate}" \
  "$user" \
  "${GITHUB_REPOSITORY:-<unset>}" \
  "$gui" \
  >>"$dest_dir/$user.txt"

echo "Appended postCreate user demo entry to $dest_dir/$user.txt"
