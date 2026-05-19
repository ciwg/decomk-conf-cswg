#!/bin/bash
set -euo pipefail

# Intent: Keep the current OSS CAD Suite install behavior in a normal script
# while TODO-sapan designs the future OCI-backed artifact cache.
# Source: DI-dadak (TODO-rifol); follow-up: TODO-sapan.

oss_url="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-03-07/oss-cad-suite-linux-x64-20260307.tgz"
archive_path="/tmp/oss-cad-suite.tgz"
install_root="/opt"
profile_path="/etc/profile.d/oss-cad-suite.sh"

cleanup_archive() {
  if [[ -e "$archive_path" ]]; then
    if ! rm -f "$archive_path"; then
      echo "WARN: failed to remove temporary archive: $archive_path" >&2
    fi
  fi
}

trap cleanup_archive EXIT

if ! wget -q "$oss_url" -O "$archive_path"; then
  rc="$?"
  echo "ERROR: failed to download OSS CAD Suite archive (rc=$rc): $oss_url" >&2
  exit "$rc"
fi

install -d -m 0755 "$install_root"

if ! tar xzf "$archive_path" -C "$install_root"; then
  rc="$?"
  echo "ERROR: failed to extract OSS CAD Suite archive (rc=$rc): $archive_path" >&2
  exit "$rc"
fi

if ! rm -f "$archive_path"; then
  rc="$?"
  echo "ERROR: failed to remove temporary archive (rc=$rc): $archive_path" >&2
  exit "$rc"
fi
trap - EXIT

# Intent: Write a profile fragment with literal `$PATH` so login shells expand
# their current path at session start instead of freezing this installer shell's
# path at image setup time. Source: DI-dadak (TODO-rifol)
# shellcheck disable=SC2016
printf '%s\n' 'export PATH="/opt/oss-cad-suite/bin:$PATH"' >"$profile_path"
chmod 0644 "$profile_path"
