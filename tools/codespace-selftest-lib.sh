#!/usr/bin/env bash

# Shared helpers for decomk Codespaces selftests.
# Intent: Keep Codespaces lifecycle behavior consistent across bootstrap capture
# and GUI runtime selftests while leaving each top-level test script responsible
# for its own assertions and artifact layout. Source: DI-013-20260518-054020
# (TODO/013)

# Intent: Keep selftests runnable in unattended contexts when GitHub's machine
# lookup APIs return no result, while preserving --machine as the explicit
# operator override. Source: DI-008-20260515-040231 (TODO/008)
# shellcheck disable=SC2034
CODESPACE_SELFTEST_DEFAULT_MACHINE="basicLinux32gb"

codespace_selftest_require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 1
  fi
}

codespace_selftest_infer_repo_from_git() {
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

codespace_selftest_infer_branch_from_git() {
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

codespace_selftest_infer_machine_from_existing_codespaces() {
  local repo="$1"

  gh codespace list --repo "$repo" --json machineName,lastUsedAt,createdAt \
    --jq '.[] | select(.machineName != null and .machineName != "") | [(.lastUsedAt // ""), (.createdAt // ""), .machineName] | @tsv' \
    | sort -r \
    | head -n1 \
    | awk -F '\t' '{print $3}'
}

codespace_selftest_infer_machine_from_api() {
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

codespace_selftest_resolve_machine() {
  local repo="$1"
  local machine=""

  if ! machine="$(codespace_selftest_infer_machine_from_existing_codespaces "$repo")"; then
    machine=""
  fi
  if [[ -n "$machine" ]]; then
    printf '%s\n' "$machine"
    return 0
  fi

  if ! machine="$(codespace_selftest_infer_machine_from_api "$repo")"; then
    machine=""
  fi
  if [[ -n "$machine" ]]; then
    printf '%s\n' "$machine"
    return 0
  fi

  return 1
}

codespace_selftest_create_codespace() {
  local repo="$1"
  local branch="$2"
  local display_name="$3"
  local devcontainer_path="$4"
  local machine="$5"
  local location="$6"
  local idle_timeout="$7"
  local retention_period="$8"
  local create_log="$9"

  local cmd rc
  cmd=(gh codespace create --repo "$repo" --branch "$branch" --display-name "$display_name" --default-permissions)

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

  # Intent: GitHub CLI can create a Codespace and then fail while polling for
  # status.  Do the creation step once, record its exit code, and let callers
  # discover the new Codespace by display name before polling state themselves.
  # Source: DI-013-20260518-054020 (TODO/013)
  set +e
  "${cmd[@]}" 2>&1 | tee -a "$create_log"
  rc=${PIPESTATUS[0]}
  set -e

  if [[ "$rc" -ne 0 ]]; then
    echo "WARN: gh codespace create exited with rc=$rc; continuing with display-name discovery" | tee -a "$create_log" >&2
  fi
}

codespace_selftest_resolve_codespace_name() {
  local repo="$1"
  local display_name="$2"

  # Find the newest matching codespace because display names can be reused.
  gh codespace list --repo "$repo" --json name,displayName,createdAt --jq ".[] | select(.displayName == \"${display_name}\") | [.createdAt, .name] | @tsv" \
    | sort -r \
    | head -n1 \
    | awk -F '\t' '{print $2}'
}

codespace_selftest_wait_for_codespace_name() {
  local repo="$1"
  local display_name="$2"
  local timeout_seconds="$3"
  local poll_seconds="$4"

  local start now elapsed codespace_name
  start="$(date +%s)"

  # Wait until GitHub's list endpoint shows the newly-created codespace.
  while true; do
    codespace_name=""
    if ! codespace_name="$(codespace_selftest_resolve_codespace_name "$repo" "$display_name")"; then
      codespace_name=""
    fi

    if [[ -n "$codespace_name" ]]; then
      printf '%s\n' "$codespace_name"
      return 0
    fi

    now="$(date +%s)"
    elapsed="$(( now - start ))"
    if (( elapsed >= timeout_seconds )); then
      echo "ERROR: timed out waiting for codespace display name '${display_name}' to appear" >&2
      return 1
    fi

    sleep "$poll_seconds"
  done
}

codespace_selftest_wait_for_codespace_start() {
  local codespace_name="$1"
  local timeout_seconds="$2"
  local poll_seconds="$3"

  local start now elapsed state
  start="$(date +%s)"

  # Poll the Codespaces state ourselves instead of relying on gh create --status.
  while true; do
    state=""
    if ! state="$(gh codespace view --codespace "$codespace_name" --json state --jq .state 2>&1)"; then
      state=""
    fi

    case "$state" in
      Available|Running)
        echo "codespace ${codespace_name} reached state ${state}" >&2
        return 0
        ;;
    esac

    now="$(date +%s)"
    elapsed="$(( now - start ))"
    if (( elapsed >= timeout_seconds )); then
      echo "ERROR: timed out waiting for codespace '${codespace_name}' to start (last state='${state:-<none>}')" >&2
      return 1
    fi

    echo "waiting for ${codespace_name}: ${state:-<none>}" >&2
    sleep "$poll_seconds"
  done
}

codespace_selftest_capture_var_decomk() {
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

codespace_selftest_capture_remote_info() {
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

codespace_selftest_capture_codespace_logs() {
  local codespace_name="$1"
  local out_file="$2"
  local err_file="$3"

  gh codespace logs --codespace "$codespace_name" >"$out_file" 2>"$err_file"
}

codespace_selftest_evaluate_capture() {
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

codespace_selftest_delete_codespace() {
  local codespace_name="$1"

  gh codespace delete --codespace "$codespace_name" --force
}
