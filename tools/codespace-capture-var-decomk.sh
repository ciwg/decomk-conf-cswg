#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Create a codespace, capture /var/decomk, and store results under /tmp.

Usage:
  tools/codespace-capture-var-decomk.sh [options]

Options:
  --repo OWNER/REPO          Repository to create codespace from.
                             Default: inferred from git remote origin.
  --branch BRANCH            Branch to use. Default: current git branch, else main.
  --display-name NAME        Codespace display name.
                             Default: decomk-capture-<UTC timestamp>
  --devcontainer-path PATH   devcontainer.json path for codespace create.
  --machine NAME             Machine type for codespace create.
  --location NAME            Codespace region (EastUs, WestEurope, etc).
  --idle-timeout DURATION    e.g. 30m, 1h.
  --retention-period DUR     e.g. 1h, 72h.
  --out-root DIR             Local output root. Default: /tmp
  --delete-after             Delete created codespace after capture.
  --keep                     Keep created codespace after capture (default).
  -h, --help                 Show help.

Examples:
  tools/codespace-capture-var-decomk.sh
  tools/codespace-capture-var-decomk.sh --repo ciwg/decomk-conf-cswg --branch main --delete-after
USAGE
}

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
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "$branch" && "$branch" != "HEAD" ]]; then
    printf '%s\n' "$branch"
  else
    printf '%s\n' "main"
  fi
}

wait_for_codespace_state() {
  local codespace_name="$1"
  local desired_state="$2"
  local timeout_seconds="$3"

  local start now elapsed state
  start="$(date +%s)"

  while true; do
    state="$({ gh codespace list --json name,state --jq ".[] | select(.name == \"${codespace_name}\") | .state" || true; } | head -n1)"

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

  if gh codespace cp --codespace "$codespace_name" --recursive "remote:/var/decomk" "$capture_dir/"; then
    echo "cp"
    return 0
  fi

  local tarball="$capture_dir/decomk.tgz"
  gh codespace ssh --codespace "$codespace_name" -- 'set -euo pipefail; test -d /var/decomk; sudo tar -C /var -czf - decomk' >"$tarball"
  tar -xzf "$tarball" -C "$capture_dir"
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
    repo="$(infer_repo_from_git || true)"
  fi
  if [[ -z "$repo" ]]; then
    echo "ERROR: unable to infer repo; pass --repo OWNER/REPO" >&2
    exit 1
  fi

  if [[ -z "$branch" ]]; then
    branch="$(infer_branch_from_git)"
  fi

  local ts
  ts="$(date -u +%Y%m%d-%H%M%S)"

  if [[ -z "$display_name" ]]; then
    display_name="decomk-capture-${ts}"
  fi

  local run_root
  run_root="${out_root%/}/codespace-var-decomk-${ts}"
  mkdir -p "$run_root"

  local create_log="$run_root/create.log"

  echo "Creating codespace"
  echo "- repo:         $repo"
  echo "- branch:       $branch"
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

  capture_remote_info "$codespace_name" "$run_root/remote-info.txt" || true

  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "repo=$repo"
    echo "branch=$branch"
    echo "display_name=$display_name"
    echo "codespace_name=$codespace_name"
    echo "capture_method=$capture_method"
    echo "capture_dir=$capture_dir"
  } >"$run_root/metadata.env"

  local artifact_tgz="$run_root/decomk-capture.tgz"
  tar -C "$capture_dir" -czf "$artifact_tgz" .

  echo
  echo "Capture complete"
  echo "- metadata:   $run_root/metadata.env"
  echo "- remote-info:$run_root/remote-info.txt"
  echo "- capture dir:$capture_dir"
  echo "- tarball:    $artifact_tgz"

  if [[ "$delete_after" == "true" ]]; then
    echo "Deleting codespace: $codespace_name"
    gh codespace delete --codespace "$codespace_name" --force
  else
    echo "Keeping codespace: $codespace_name"
  fi
}

main "$@"
