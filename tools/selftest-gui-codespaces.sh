#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/codespace-selftest-lib.sh
source "$script_dir/codespace-selftest-lib.sh"

usage() {
  cat <<'USAGE'
Create a GUI selftest codespace, validate runtime GUI health, and store results under /tmp.

Usage:
  tools/selftest-gui-codespaces.sh [options]

Options:
  --repo OWNER/REPO          Repository to create codespace from.
                             Default: ciwg/decomk-conf-cswg.
  --branch BRANCH            Branch to use. Default: current git branch, else main.
  --display-name NAME        Codespace display name.
                             Default: decomk-gui-selftest-<UTC timestamp>
  --devcontainer-path PATH   devcontainer.json path for codespace create.
                             Default: .devcontainer/gui-selftest/devcontainer.json
  --machine NAME             Machine type for codespace create.
                             Default: auto-resolve non-interactively,
                             then fallback to basicLinux32gb.
  --location NAME            Codespace region (EastUs, WestEurope, etc).
  --idle-timeout DURATION    e.g. 30m, 1h.
  --retention-period DUR     e.g. 1h, 72h.
  --out-root DIR             Local output root. Default: /tmp
  --ready-timeout SECONDS    GUI readiness timeout. Default: 180.
  --stable-seconds SECONDS   GUI stability delay before final probe. Default: 15.
  --start-timeout SECONDS    Codespace start timeout. Default: 3600.
  --lookup-timeout SECONDS   Codespace display-name lookup timeout. Default: 120.
  --poll-seconds SECONDS     Poll interval for Codespace state. Default: 15.
  --delete-after             Delete created codespace after capture.
  --keep                     Keep created codespace after capture (default).
  -h, --help                 Show help.

Examples:
  tools/selftest-gui-codespaces.sh --machine basicLinux32gb
  tools/selftest-gui-codespaces.sh --branch testing --delete-after

Note:
  The selected remote branch must already contain the selftest devcontainer path.
USAGE
}

GUI_SELFTEST_RESULT="FAIL"
GUI_SELFTEST_RUN_ROOT=""

finalize_gui_selftest() {
  local exit_code="$1"
  local status="PASS"

  if [[ "$GUI_SELFTEST_RESULT" != "PASS" || "$exit_code" -ne 0 ]]; then
    status="FAIL"
  fi

  echo "GUI SELFTEST ${status}"
  if [[ -n "$GUI_SELFTEST_RUN_ROOT" ]]; then
    echo "$GUI_SELFTEST_RUN_ROOT"
  fi
}
trap 'finalize_gui_selftest "$?"' EXIT

validate_seconds() {
  local value_name="$1"
  local value="$2"

  case "$value" in
    ''|*[!0-9]*)
      printf '%s must be a non-negative integer, got %q\n' "$value_name" "$value" >&2
      exit 1
      ;;
  esac
}

run_gui_health_check() {
  local codespace_name="$1"
  local health_log="$2"
  local ready_timeout_seconds="$3"
  local stable_seconds="$4"
  local healthcheck_script="$script_dir/../bin/gui-runtime-healthcheck.sh"

  if [[ ! -f "$healthcheck_script" ]]; then
    echo "ERROR: missing local healthcheck script: $healthcheck_script" >&2
    return 1
  fi

  # Intent: Send the checked-in healthcheck script over stdin so the remote
  # assertion logic exactly matches the branch being tested. Source:
  # DI-013-20260518-054020 (TODO/013)
  gh codespace ssh --codespace "$codespace_name" -- \
    "GUI_HEALTH_READY_TIMEOUT_SECONDS=$ready_timeout_seconds GUI_HEALTH_STABLE_SECONDS=$stable_seconds bash -s" \
    >"$health_log" 2>&1 <"$healthcheck_script"
}

evaluate_gui_result() {
  local capture_dir="$1"
  local remote_info_file="$2"
  local codespace_logs_rc="$3"
  local remote_info_rc="$4"
  local health_rc="$5"
  local health_log="$6"
  local failed=0

  if [[ "$health_rc" -ne 0 ]]; then
    echo "GUI health check failed (rc=$health_rc); see $health_log"
    failed=1
  fi

  if ! codespace_selftest_evaluate_capture "$capture_dir" "$remote_info_file" "$codespace_logs_rc" "$remote_info_rc"; then
    failed=1
  fi

  if [[ "$failed" -ne 0 ]]; then
    return 1
  fi
  return 0
}

main() {
  codespace_selftest_require_cmd gh
  codespace_selftest_require_cmd git
  codespace_selftest_require_cmd awk
  codespace_selftest_require_cmd sort
  codespace_selftest_require_cmd tar

  local repo="ciwg/decomk-conf-cswg"
  local branch=""
  local display_name=""
  local devcontainer_path=".devcontainer/gui-selftest/devcontainer.json"
  local machine=""
  local location=""
  local idle_timeout=""
  local retention_period=""
  local out_root="/tmp"
  local delete_after="false"
  local ready_timeout_seconds="180"
  local stable_seconds="15"
  local lookup_timeout_seconds="120"
  local poll_seconds="15"
  local start_timeout_seconds="3600"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        repo="${2:-}"
        shift 2
        ;;
      --branch)
        branch="${2:-}"
        shift 2
        ;;
      --display-name)
        display_name="${2:-}"
        shift 2
        ;;
      --devcontainer-path)
        devcontainer_path="${2:-}"
        shift 2
        ;;
      --machine)
        machine="${2:-}"
        shift 2
        ;;
      --location)
        location="${2:-}"
        shift 2
        ;;
      --idle-timeout)
        idle_timeout="${2:-}"
        shift 2
        ;;
      --retention-period)
        retention_period="${2:-}"
        shift 2
        ;;
      --out-root)
        out_root="${2:-}"
        shift 2
        ;;
      --ready-timeout)
        ready_timeout_seconds="${2:-}"
        shift 2
        ;;
      --stable-seconds)
        stable_seconds="${2:-}"
        shift 2
        ;;
      --start-timeout)
        start_timeout_seconds="${2:-}"
        shift 2
        ;;
      --lookup-timeout)
        lookup_timeout_seconds="${2:-}"
        shift 2
        ;;
      --poll-seconds)
        poll_seconds="${2:-}"
        shift 2
        ;;
      --delete-after)
        delete_after="true"
        shift
        ;;
      --keep)
        delete_after="false"
        shift
        ;;
      -h|--help)
        GUI_SELFTEST_RESULT="PASS"
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

  validate_seconds "GUI_HEALTH_READY_TIMEOUT_SECONDS" "$ready_timeout_seconds"
  validate_seconds "GUI_HEALTH_STABLE_SECONDS" "$stable_seconds"
  validate_seconds "CODESPACE_LOOKUP_TIMEOUT_SECONDS" "$lookup_timeout_seconds"
  validate_seconds "CODESPACE_POLL_SECONDS" "$poll_seconds"
  validate_seconds "CODESPACE_START_TIMEOUT_SECONDS" "$start_timeout_seconds"

  if [[ -z "$repo" ]]; then
    echo "ERROR: --repo must not be empty" >&2
    exit 1
  fi

  if [[ -z "$branch" ]]; then
    branch="$(codespace_selftest_infer_branch_from_git)"
  fi

  if [[ -z "$machine" ]]; then
    if ! machine="$(codespace_selftest_resolve_machine "$repo")"; then
      machine=""
    fi
  fi
  if [[ -z "$machine" ]]; then
    machine="$CODESPACE_SELFTEST_DEFAULT_MACHINE"
    echo "WARN: unable to resolve machine non-interactively for ${repo}; using fallback: ${machine}" >&2
    echo "WARN: override the machine with:" >&2
    printf 'WARN:   %q --repo %q --branch %q --machine <name>\n' "$0" "$repo" "$branch" >&2
  fi

  local ts
  ts="$(date -u +%Y%m%d-%H%M%S)"

  if [[ -z "$display_name" ]]; then
    display_name="decomk-gui-selftest-${ts}"
  fi

  local run_root
  run_root="${out_root%/}/decomk-conf-cswg-gui-selftest-${ts}"
  mkdir -p "$run_root"
  GUI_SELFTEST_RUN_ROOT="$run_root"

  local create_log="$run_root/create.log"

  echo "Creating GUI selftest codespace"
  echo "- repo:              $repo"
  echo "- branch:            $branch"
  echo "- machine:           $machine"
  echo "- devcontainer_path: $devcontainer_path"
  echo "- display_name:      $display_name"
  echo "- out_dir:           $run_root"

  codespace_selftest_create_codespace "$repo" "$branch" "$display_name" "$devcontainer_path" "$machine" "$location" "$idle_timeout" "$retention_period" "$create_log"

  local codespace_name
  codespace_name="$(codespace_selftest_wait_for_codespace_name "$repo" "$display_name" "$lookup_timeout_seconds" "$poll_seconds")"

  echo "Resolved codespace name: $codespace_name"

  codespace_selftest_wait_for_codespace_start "$codespace_name" "$start_timeout_seconds" "$poll_seconds"

  local health_log="$run_root/gui-health.log"
  local health_rc=0
  set +e
  run_gui_health_check "$codespace_name" "$health_log" "$ready_timeout_seconds" "$stable_seconds"
  health_rc=$?
  set -e

  cat "$health_log"

  local capture_dir="$run_root/decomk-capture"
  local capture_method=""
  local capture_rc=0
  set +e
  capture_method="$(codespace_selftest_capture_var_decomk "$codespace_name" "$capture_dir")"
  capture_rc=$?
  set -e
  if [[ "$capture_rc" -ne 0 ]]; then
    echo "WARN: failed to capture /var/decomk (rc=$capture_rc)" >&2
  fi

  local remote_info_file="$run_root/remote-info.txt"
  local remote_info_rc=0
  if ! codespace_selftest_capture_remote_info "$codespace_name" "$remote_info_file"; then
    remote_info_rc=$?
  fi

  local codespace_logs_file="$run_root/codespace.log"
  local codespace_logs_err_file="$run_root/codespace.log.err"
  local codespace_logs_rc=0
  if ! codespace_selftest_capture_codespace_logs "$codespace_name" "$codespace_logs_file" "$codespace_logs_err_file"; then
    codespace_logs_rc=$?
  fi

  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "repo=$repo"
    echo "branch=$branch"
    echo "display_name=$display_name"
    echo "codespace_name=$codespace_name"
    echo "devcontainer_path=$devcontainer_path"
    echo "capture_method=$capture_method"
    echo "capture_rc=$capture_rc"
    echo "capture_dir=$capture_dir"
    echo "remote_info_file=$remote_info_file"
    echo "remote_info_rc=$remote_info_rc"
    echo "codespace_logs_file=$codespace_logs_file"
    echo "codespace_logs_err_file=$codespace_logs_err_file"
    echo "codespace_logs_rc=$codespace_logs_rc"
    echo "health_log=$health_log"
    echo "health_rc=$health_rc"
  } >"$run_root/metadata.env"

  local artifact_tgz="$run_root/decomk-capture.tgz"
  if [[ -d "$capture_dir" ]]; then
    tar -C "$capture_dir" -czf "$artifact_tgz" .
  fi

  local result_reasons_file="$run_root/result-reasons.txt"
  if evaluate_gui_result "$capture_dir" "$remote_info_file" "$codespace_logs_rc" "$remote_info_rc" "$health_rc" "$health_log" >"$result_reasons_file"; then
    GUI_SELFTEST_RESULT="PASS"
  else
    GUI_SELFTEST_RESULT="FAIL"
  fi

  echo
  echo "GUI selftest complete"
  echo "- metadata:   $run_root/metadata.env"
  echo "- health:     $health_log"
  echo "- remote-info:$remote_info_file"
  echo "- logs:       $codespace_logs_file"
  echo "- logs err:   $codespace_logs_err_file"
  echo "- capture dir:$capture_dir"
  if [[ -f "$artifact_tgz" ]]; then
    echo "- tarball:    $artifact_tgz"
  fi
  if [[ "$GUI_SELFTEST_RESULT" == "FAIL" ]]; then
    echo "- result:     FAIL"
    echo "- reasons:    $result_reasons_file"
  else
    echo "- result:     PASS"
  fi

  if [[ "$delete_after" == "true" ]]; then
    echo "Deleting codespace: $codespace_name"
    codespace_selftest_delete_codespace "$codespace_name"
  else
    echo "Keeping codespace: $codespace_name"
  fi
}

main "$@"
