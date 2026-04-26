#!/usr/bin/env bash
set -euo pipefail

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
  --machine NAME             Machine type for codespace create.
                             Default: auto-resolve non-interactively.
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

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 1
  fi
}

infer_repo_from_git() {
  local remote_url
  if ! remote_url="$(git config --get remote.origin.url 2>/dev/null)"; then
    return 1
  fi

  case "$remote_url" in
    git@github.com:*)
      remote_url="${remote_url#git@github.com:}"
      ;;
    https://github.com/*)
      remote_url="${remote_url#https://github.com/}"
      ;;
    *)
      return 1
      ;;
  esac

  remote_url="${remote_url%.git}"
  if [[ "$remote_url" == */* ]]; then
    printf '%s\n' "$remote_url"
    return 0
  fi

  return 1
}

infer_branch_from_git() {
  local branch
  if ! branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"; then
    branch=""
  fi

  if [[ -n "$branch" && "$branch" != "HEAD" ]]; then
    printf '%s\n' "$branch"
  else
    printf '%s\n' "main"
  fi
}

infer_machine_from_existing_codespaces() {
  local repo="$1"

  gh codespace list --repo "$repo" --json machineName,lastUsedAt,createdAt \
    --jq '.[] | select(.machineName != null and .machineName != "") | [(.lastUsedAt // ""), (.createdAt // ""), .machineName] | @tsv' \
    | sort -r \
    | head -n1 \
    | awk -F '\t' '{print $3}'
}

infer_machine_from_api() {
  local repo="$1"
  local repo_id
  if ! repo_id="$(gh api "repos/${repo}" --jq '.id' 2>/dev/null)"; then
    return 1
  fi

  if [[ -z "$repo_id" ]]; then
    return 1
  fi

  gh api "user/codespaces/machines?repository_id=${repo_id}" --jq '.machines[]? | select(.name != null and .name != "") | .name' 2>/dev/null | head -n1
}

resolve_machine() {
  local repo="$1"
  local machine=""

  if ! machine="$(infer_machine_from_existing_codespaces "$repo")"; then
    machine=""
  fi
  if [[ -n "$machine" ]]; then
    printf '%s\n' "$machine"
    return 0
  fi

  if ! machine="$(infer_machine_from_api "$repo")"; then
    machine=""
  fi
  if [[ -n "$machine" ]]; then
    printf '%s\n' "$machine"
    return 0
  fi

  return 1
}

wait_for_codespace_state() {
  local codespace_name="$1"
  local desired_state="$2"
  local timeout_seconds="$3"

  local start now elapsed state
  start="$(date +%s)"

  while true; do
    state=""
    if state="$(gh codespace list --json name,state --jq ".[] | select(.name == \"${codespace_name}\") | .state" 2>/dev/null)"; then
      state="$(printf '%s\n' "$state" | head -n1)"
    else
      state=""
    fi

    if [[ "$state" == "$desired_state" ]]; then
      return 0
    fi

    now="$(date +%s)"
    elapsed="$(( now - start ))"
    if (( elapsed >= timeout_seconds )); then
      echo "ERROR: timed out waiting for codespace '${codespace_name}' to reach state '${desired_state}' (last state='${state:-<none>}')" >&2
      return 1
    fi

    sleep 5
  done
}

create_codespace() {
  local repo="$1"
  local branch="$2"
  local display_name="$3"
  local devcontainer_path="$4"
  local machine="$5"
  local location="$6"
  local idle_timeout="$7"
  local retention_period="$8"
  local create_log="$9"

  local cmd
  cmd=(gh codespace create --repo "$repo" --branch "$branch" --display-name "$display_name" --default-permissions --status)

  if [[ -n "$devcontainer_path" ]]; then
    cmd+=(--devcontainer-path "$devcontainer_path")
  fi
  if [[ -n "$machine" ]]; then
    cmd+=(--machine "$machine")
  fi
  if [[ -n "$location" ]]; then
    cmd+=(--location "$location")
  fi
  if [[ -n "$idle_timeout" ]]; then
    cmd+=(--idle-timeout "$idle_timeout")
  fi
  if [[ -n "$retention_period" ]]; then
    cmd+=(--retention-period "$retention_period")
  fi

  {
    echo "### create-command"
    printf '%q ' "${cmd[@]}"
    echo
    echo
  } >"$create_log"

  "${cmd[@]}" | tee -a "$create_log"
}

resolve_codespace_name() {
  local repo="$1"
  local display_name="$2"

  gh codespace list --repo "$repo" --json name,displayName,createdAt --jq ".[] | select(.displayName == \"${display_name}\") | [.createdAt, .name] | @tsv" \
    | sort -r \
    | head -n1 \
    | awk -F '\t' '{print $2}'
}

capture_var_decomk() {
  local codespace_name="$1"
  local capture_dir="$2"

  mkdir -p "$capture_dir"

  local tarball="$capture_dir/decomk.tgz"
  if gh codespace cp --codespace "$codespace_name" --recursive "remote:/var/decomk" "$capture_dir/"; then
    if [[ -d "$capture_dir/decomk" ]]; then
      echo "cp"
      return 0
    fi
    echo "ERROR: copy reported success but expected directory is missing: $capture_dir/decomk" >&2
    return 1
  fi

  if ! gh codespace ssh --codespace "$codespace_name" -- 'set -euo pipefail; test -d /var/decomk; sudo tar -C /var -czf - decomk' >"$tarball"; then
    echo "ERROR: ssh/tar fallback failed to capture /var/decomk" >&2
    return 1
  fi
  if [[ ! -s "$tarball" ]]; then
    echo "ERROR: ssh/tar fallback produced an empty archive: $tarball" >&2
    return 1
  fi
  if ! tar -xzf "$tarball" -C "$capture_dir"; then
    echo "ERROR: failed to extract capture archive: $tarball" >&2
    return 1
  fi
  if [[ ! -d "$capture_dir/decomk" ]]; then
    echo "ERROR: extracted capture archive missing expected path: $capture_dir/decomk" >&2
    return 1
  fi

  echo "ssh-tar"
}

capture_remote_info() {
  local codespace_name="$1"
  local out_file="$2"

  gh codespace ssh --codespace "$codespace_name" -- '
set -euo pipefail

echo "# timestamp_utc"
date -u +%Y-%m-%dT%H:%M:%SZ

echo
echo "# identity"
whoami
id

echo
echo "# os-release"
cat /etc/os-release

echo
echo "# /var/decomk listing"
if [[ -d /var/decomk ]]; then
  ls -la /var/decomk
else
  echo "/var/decomk not found"
fi

echo
echo "# /var/decomk tree (maxdepth=3)"
if [[ -d /var/decomk ]]; then
  find /var/decomk -maxdepth 3 -printf "%M %u:%g %s %TY-%Tm-%TdT%TH:%TM:%TS %p\n" | sort
fi
' >"$out_file"
}

capture_codespace_logs() {
  local codespace_name="$1"
  local out_file="$2"
  local err_file="$3"

  gh codespace logs --codespace "$codespace_name" >"$out_file" 2>"$err_file"
}

evaluate_capture() {
  local capture_dir="$1"
  local remote_info_file="$2"
  local codespace_logs_rc="$3"
  local remote_info_rc="$4"
  local failed=0

  if [[ ! -d "$capture_dir/decomk" ]]; then
    echo "missing captured directory: $capture_dir/decomk"
    failed=1
  fi

  if [[ -f "$capture_dir/decomk.tgz" && ! -s "$capture_dir/decomk.tgz" ]]; then
    echo "empty fallback archive: $capture_dir/decomk.tgz"
    failed=1
  fi

  if [[ "$remote_info_rc" -ne 0 ]]; then
    echo "remote-info capture failed (rc=$remote_info_rc)"
    failed=1
  elif grep -q '^/var/decomk not found$' "$remote_info_file"; then
    echo "remote environment reports '/var/decomk not found'"
    failed=1
  fi

  if [[ "$codespace_logs_rc" -ne 0 ]]; then
    echo "codespace logs capture failed (rc=$codespace_logs_rc)"
    failed=1
  fi

  if [[ "$failed" -ne 0 ]]; then
    return 1
  fi
  return 0
}

main() {
  require_cmd gh
  require_cmd git
  require_cmd awk
  require_cmd sort
  require_cmd tar

  local repo=""
  local branch=""
  local display_name=""
  local devcontainer_path=""
  local machine=""
  local location=""
  local idle_timeout=""
  local retention_period=""
  local out_root="/tmp"
  local delete_after="false"

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
    if ! repo="$(infer_repo_from_git)"; then
      repo=""
    fi
  fi
  if [[ -z "$repo" ]]; then
    echo "ERROR: unable to infer repo; pass --repo OWNER/REPO" >&2
    exit 1
  fi

  if [[ -z "$branch" ]]; then
    branch="$(infer_branch_from_git)"
  fi

  if [[ -z "$machine" ]]; then
    if ! machine="$(resolve_machine "$repo")"; then
      machine=""
    fi
  fi
  if [[ -z "$machine" ]]; then
    echo "ERROR: unable to resolve machine non-interactively for ${repo}" >&2
    echo "Pass --machine <name> to avoid interactive machine selection prompts." >&2
    return 1
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

  create_codespace "$repo" "$branch" "$display_name" "$devcontainer_path" "$machine" "$location" "$idle_timeout" "$retention_period" "$create_log"

  local codespace_name
  codespace_name="$(resolve_codespace_name "$repo" "$display_name")"

  if [[ -z "$codespace_name" ]]; then
    echo "ERROR: unable to resolve created codespace name from display name '$display_name'" >&2
    exit 1
  fi

  echo "Resolved codespace name: $codespace_name"

  wait_for_codespace_state "$codespace_name" "Available" 900

  local capture_dir="$run_root/decomk-capture"
  local capture_method
  capture_method="$(capture_var_decomk "$codespace_name" "$capture_dir")"

  local remote_info_file="$run_root/remote-info.txt"
  local remote_info_rc=0
  if ! capture_remote_info "$codespace_name" "$remote_info_file"; then
    remote_info_rc=$?
  fi

  local codespace_logs_file="$run_root/codespace.log"
  local codespace_logs_err_file="$run_root/codespace.log.err"
  local codespace_logs_rc=0
  if ! capture_codespace_logs "$codespace_name" "$codespace_logs_file" "$codespace_logs_err_file"; then
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
  if evaluate_capture "$capture_dir" "$remote_info_file" "$codespace_logs_rc" "$remote_info_rc" >"$result_reasons_file"; then
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
    gh codespace delete --codespace "$codespace_name" --force
  else
    echo "Keeping codespace: $codespace_name"
  fi
}

main "$@"
