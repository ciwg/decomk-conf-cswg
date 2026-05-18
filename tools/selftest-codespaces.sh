#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/codespace-selftest-lib.sh
source "$script_dir/codespace-selftest-lib.sh"

usage() {
  cat <<'USAGE'
Create a codespace, capture /var/decomk, and store results under /tmp.

Usage:
  tools/selftest-codespaces.sh [options]

Options:
  --repo OWNER/REPO          Repository to create codespace from.
                             Default: inferred from git remote origin.
  --branch BRANCH            Branch to use. Default: current git branch, else main.
  --display-name NAME        Codespace display name.
                             Default: decomk-capture-<UTC timestamp>
  --devcontainer-path PATH   devcontainer.json path for codespace create.
                             Default: .devcontainer/devcontainer.json
  --machine NAME             Machine type for codespace create.
                             Default: auto-resolve non-interactively,
                             then fallback to basicLinux32gb.
  --location NAME            Codespace region (EastUs, WestEurope, etc).
  --idle-timeout DURATION    e.g. 30m, 1h.
  --retention-period DUR     e.g. 1h, 72h.
  --out-root DIR             Local output root. Default: /tmp
  --delete-after             Delete created codespace after capture.
  --keep                     Keep created codespace after capture (default).
  -h, --help                 Show help.

Examples:
  tools/selftest-codespaces.sh
  tools/selftest-codespaces.sh --repo ciwg/decomk-conf-cswg --branch main --delete-after
USAGE
}

SELFTEST_RESULT="FAIL"
SELFTEST_RUN_ROOT=""

finalize_selftest() {
  local exit_code="$1"
  local status="PASS"

  if [[ "$SELFTEST_RESULT" != "PASS" || "$exit_code" -ne 0 ]]; then
    status="FAIL"
  fi

  echo "SELFTEST ${status}"
  if [[ -n "$SELFTEST_RUN_ROOT" ]]; then
    echo "$SELFTEST_RUN_ROOT"
  fi
}
trap 'finalize_selftest "$?"' EXIT

main() {
  codespace_selftest_require_cmd gh
  codespace_selftest_require_cmd git
  codespace_selftest_require_cmd awk
  codespace_selftest_require_cmd sort
  codespace_selftest_require_cmd tar

  local repo=""
  local branch=""
  local display_name=""
  local devcontainer_path=".devcontainer/devcontainer.json"
  local machine=""
  local location=""
  local idle_timeout=""
  local retention_period=""
  local out_root="/tmp"
  local delete_after="false"
  local lookup_timeout_seconds="120"
  local poll_seconds="5"
  local start_timeout_seconds="900"

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
      --delete-after)
        delete_after="true"
        shift
        ;;
      --keep)
        delete_after="false"
        shift
        ;;
      -h|--help)
        SELFTEST_RESULT="PASS"
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

  if [[ -z "$repo" ]]; then
    if ! repo="$(codespace_selftest_infer_repo_from_git)"; then
      repo=""
    fi
  fi
  if [[ -z "$repo" ]]; then
    echo "ERROR: unable to infer repo; pass --repo OWNER/REPO" >&2
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
    display_name="decomk-capture-${ts}"
  fi

  local run_root
  run_root="${out_root%/}/codespace-var-decomk-${ts}"
  mkdir -p "$run_root"
  SELFTEST_RUN_ROOT="$run_root"

  local create_log="$run_root/create.log"

  echo "Creating codespace"
  echo "- repo:         $repo"
  echo "- branch:       $branch"
  echo "- machine:      $machine"
  echo "- display_name: $display_name"
  echo "- out_dir:      $run_root"

  codespace_selftest_create_codespace "$repo" "$branch" "$display_name" "$devcontainer_path" "$machine" "$location" "$idle_timeout" "$retention_period" "$create_log"

  local codespace_name
  codespace_name="$(codespace_selftest_wait_for_codespace_name "$repo" "$display_name" "$lookup_timeout_seconds" "$poll_seconds")"

  echo "Resolved codespace name: $codespace_name"

  codespace_selftest_wait_for_codespace_start "$codespace_name" "$start_timeout_seconds" "$poll_seconds"

  local capture_dir="$run_root/decomk-capture"
  local capture_method
  capture_method="$(codespace_selftest_capture_var_decomk "$codespace_name" "$capture_dir")"

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
    echo "capture_method=$capture_method"
    echo "capture_dir=$capture_dir"
    echo "remote_info_file=$remote_info_file"
    echo "remote_info_rc=$remote_info_rc"
    echo "codespace_logs_file=$codespace_logs_file"
    echo "codespace_logs_err_file=$codespace_logs_err_file"
    echo "codespace_logs_rc=$codespace_logs_rc"
  } >"$run_root/metadata.env"

  local artifact_tgz="$run_root/decomk-capture.tgz"
  tar -C "$capture_dir" -czf "$artifact_tgz" .

  local result_reasons_file="$run_root/result-reasons.txt"
  if codespace_selftest_evaluate_capture "$capture_dir" "$remote_info_file" "$codespace_logs_rc" "$remote_info_rc" >"$result_reasons_file"; then
    SELFTEST_RESULT="PASS"
  else
    SELFTEST_RESULT="FAIL"
  fi

  echo
  echo "Capture complete"
  echo "- metadata:   $run_root/metadata.env"
  echo "- remote-info:$remote_info_file"
  echo "- logs:       $codespace_logs_file"
  echo "- logs err:   $codespace_logs_err_file"
  echo "- capture dir:$capture_dir"
  echo "- tarball:    $artifact_tgz"
  if [[ "$SELFTEST_RESULT" == "FAIL" ]]; then
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
