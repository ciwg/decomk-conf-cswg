#!/usr/bin/env bash
set -euo pipefail

# Self-orchestrating codespace diagnostic for python apt pin failures.
# Local mode: runs this script remotely in a codespace and pulls back artifacts.
# Remote mode: collects package/version diagnostics and streams a tarball payload.

PAYLOAD_BEGIN="__CODESPACE_DIAG_PAYLOAD_BEGIN__"
PAYLOAD_END="__CODESPACE_DIAG_PAYLOAD_END__"

usage() {
  cat <<'USAGE'
Usage (local mode):
  bin/codespace-python-pin-diagnose.sh [--codespace NAME] [--outdir DIR] [--pin VERSION]

Examples:
  bin/codespace-python-pin-diagnose.sh --codespace my-codespace
  bin/codespace-python-pin-diagnose.sh --outdir ./tmp/diag --pin 3.12.3-0ubuntu1

Notes:
- Requires GitHub CLI (`gh`) authenticated for Codespaces.
- If --codespace is omitted, the first Available codespace is used.
- Produces an extracted artifact dir plus tarball under --outdir.
USAGE
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 1
  fi
}

decode_base64_file() {
  local in_file="$1"
  local out_file="$2"

  if base64 --decode "$in_file" >"$out_file" 2>/dev/null; then
    return 0
  fi
  if base64 -d "$in_file" >"$out_file" 2>/dev/null; then
    return 0
  fi
  if base64 -D "$in_file" >"$out_file" 2>/dev/null; then
    return 0
  fi

  echo "ERROR: failed to decode base64 payload" >&2
  return 1
}

pick_default_codespace() {
  gh codespace list --json name,state --jq '.[] | select(.state=="Available") | .name' | head -n1
}

run_remote_capture() {
  local name="$1"
  shift

  {
    echo "### ${name}"
    echo "+ $*"
  } >"$REPORT_DIR/${name}.txt"

  if "$@" >>"$REPORT_DIR/${name}.txt" 2>&1; then
    echo >>"$REPORT_DIR/${name}.txt"
    echo "exit_code=0" >>"$REPORT_DIR/${name}.txt"
  else
    local rc="$?"
    echo >>"$REPORT_DIR/${name}.txt"
    echo "exit_code=$rc" >>"$REPORT_DIR/${name}.txt"
  fi
}

run_remote_shell_capture() {
  local name="$1"
  local script="$2"
  run_remote_capture "$name" bash -lc "$script"
}

remote_main() {
  local pin_version="$1"

  local tmp_root
  tmp_root="$(mktemp -d)"
  REPORT_DIR="$tmp_root/report"
  mkdir -p "$REPORT_DIR"

  run_remote_shell_capture meta-env '
    date -u
    echo
    whoami
    id
    pwd
    uname -a
    echo
    cat /etc/os-release
  '

  run_remote_shell_capture apt-mark-hold 'apt-mark showhold || true'
  run_remote_shell_capture dpkg-audit 'sudo dpkg --audit || true'

  run_remote_shell_capture apt-sources '
    if [[ -f /etc/apt/sources.list ]]; then
      sed -n "1,240p" /etc/apt/sources.list
    fi
    for f in /etc/apt/sources.list.d/*.list; do
      [[ -e "$f" ]] || continue
      echo
      echo "### $f"
      sed -n "1,240p" "$f"
    done
  '

  run_remote_shell_capture apt-policy-python '
    apt-cache policy \
      python3 python3-minimal libpython3-stdlib \
      python3.12 python3.12-minimal \
      python3-pip python3-setuptools python3-wheel
  '

  run_remote_shell_capture apt-madison-python '
    apt-cache madison \
      python3 python3-minimal libpython3-stdlib \
      python3.12 python3.12-minimal \
      python3-pip python3-setuptools python3-wheel
  '

  run_remote_shell_capture dpkg-python-installed '
    dpkg -l | grep -E "^ii\\s+(python3|python3-minimal|libpython3-stdlib|python3\\.12|python3\\.12-minimal|python3-pip|python3-setuptools|python3-wheel)\\b" || true
  '

  run_remote_shell_capture apt-simulate-requested-pin "
    sudo apt-get -o Debug::pkgProblemResolver=yes -s install python3=${pin_version}
  "

  run_remote_shell_capture apt-simulate-coherent-python-set "
    if apt-cache madison python3 >/dev/null 2>&1; then
      py_ver=\"\$(apt-cache madison python3 | awk 'NR==1 {print \$3}')\"
    else
      py_ver=''
    fi
    if apt-cache madison python3.12 >/dev/null 2>&1; then
      py312_ver=\"\$(apt-cache madison python3.12 | awk 'NR==1 {print \$3}')\"
    else
      py312_ver=''
    fi
    echo \"py_ver=\${py_ver:-<none>}\"
    echo \"py312_ver=\${py312_ver:-<none>}\"
    if [[ -n \"\${py_ver}\" && -n \"\${py312_ver}\" ]]; then
      sudo apt-get -o Debug::pkgProblemResolver=yes -s install \
        \"python3=\${py_ver}\" \
        \"python3-minimal=\${py_ver}\" \
        \"libpython3-stdlib=\${py_ver}\" \
        \"python3.12=\${py312_ver}\" \
        \"python3.12-minimal=\${py312_ver}\"
    else
      echo 'Could not determine matching python versions from apt-cache madison.'
      exit 2
    fi
  "

  run_remote_shell_capture repo-makefile-python-lines '
    if [[ -f Makefile ]]; then
      grep -nE "python3(_|=)|python3\.12|python3-pip" Makefile || true
    else
      echo "Makefile not found in current directory"
    fi
  '

  run_remote_shell_capture repo-git-status 'git status --short || true'

  {
    echo "$PAYLOAD_BEGIN"
    tar -C "$REPORT_DIR" -czf - . | base64 | tr -d '\n'
    echo
    echo "$PAYLOAD_END"
  }

  rm -rf "$tmp_root"
}

local_main() {
  require_cmd gh
  require_cmd awk
  require_cmd tar
  require_cmd base64

  local codespace=""
  local outdir=""
  local pin_version="3.12.3-0ubuntu1"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --codespace)
        codespace="${2:-}"
        shift 2
        ;;
      --outdir)
        outdir="${2:-}"
        shift 2
        ;;
      --pin)
        pin_version="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "ERROR: unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$codespace" ]]; then
    codespace="$(pick_default_codespace)"
  fi
  if [[ -z "$codespace" ]]; then
    echo "ERROR: no available codespace found; pass --codespace NAME" >&2
    exit 1
  fi

  local ts
  ts="$(date -u +%Y%m%d-%H%M%S)"
  if [[ -z "$outdir" ]]; then
    outdir="./tmp/codespace-python-pin-diag-${codespace}-${ts}"
  fi

  mkdir -p "$outdir"

  local session_log="$outdir/session.log"
  local payload_file="$outdir/payload.b64"
  local tarball="$outdir/report.tgz"
  local extract_dir="$outdir/report"

  echo "Codespace: $codespace"
  echo "Output dir: $outdir"
  echo "Pin under test: python3=${pin_version}"

  gh codespace ssh -c "$codespace" -- "bash -s -- --remote --pin ${pin_version}" <"$0" | tee "$session_log"

  awk -v b="$PAYLOAD_BEGIN" -v e="$PAYLOAD_END" '
    $0==b {in_payload=1; next}
    $0==e {in_payload=0; next}
    in_payload {print}
  ' "$session_log" >"$payload_file"

  if [[ ! -s "$payload_file" ]]; then
    echo "ERROR: did not find payload markers in session log: $session_log" >&2
    exit 1
  fi

  decode_base64_file "$payload_file" "$tarball"

  mkdir -p "$extract_dir"
  tar -xzf "$tarball" -C "$extract_dir"

  echo
  echo "Diagnostics ready:"
  echo "- Session log: $session_log"
  echo "- Tarball:     $tarball"
  echo "- Extracted:   $extract_dir"
  echo
  echo "Share these files back in chat (or paste key files):"
  echo "- $extract_dir/apt-policy-python.txt"
  echo "- $extract_dir/apt-madison-python.txt"
  echo "- $extract_dir/apt-simulate-requested-pin.txt"
  echo "- $extract_dir/apt-simulate-coherent-python-set.txt"
}

main() {
  local mode="local"
  local pin_version="3.12.3-0ubuntu1"

  if [[ "${1:-}" == "--remote" ]]; then
    mode="remote"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pin)
        pin_version="${2:-}"
        shift 2
        ;;
      --codespace|--outdir)
        # handled only in local_main
        break
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        # defer unknown args handling to local_main
        break
        ;;
    esac
  done

  if [[ "$mode" == "remote" ]]; then
    remote_main "$pin_version"
  else
    local_main "$@"
  fi
}

main "$@"
