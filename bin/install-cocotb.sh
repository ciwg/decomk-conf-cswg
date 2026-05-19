#!/bin/bash
set -euo pipefail

# Intent: Keep Cocotb as a deliberate system Python install in the dedicated
# FPGA container instead of introducing a virtualenv boundary for this image.
# Ubuntu's PEP 668 guard requires --break-system-packages for that explicit
# container-level mutation, and HOME=/root avoids root-owned pip writes under
# the remote user's home directory.
# Source: DI-dadak (TODO-rifol)

if [[ "$(id -u)" != "0" ]]; then
  echo "ERROR: Cocotb system install must run as root" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required before installing Cocotb" >&2
  exit 1
fi

export HOME=/root

if ! python3 -m pip install --break-system-packages cocotb==2.0.1 cocotb-bus==0.3.0; then
  rc="$?"
  echo "ERROR: failed to install Cocotb packages (rc=$rc)" >&2
  exit "$rc"
fi
