#!/usr/bin/env bash
set -euo pipefail

# Intent: Provide one auditable operator path for decomk checkpoint releases
# while keeping the operator-supplied immutable tag exact. The script publishes
# `${IMAGE}:${IMMUTABLE_TAG}` as typed and does not synthesize candidate,
# timestamped immutable, or block-alias release tags.
# Source: DI-006-20260510-141252

usage() {
  cat <<'USAGE'
Build, tag, and publish decomk checkpoint images.

Usage:
  tools/release-image.sh --immutable-tag TAG --channel CHANNEL [--channel CHANNEL...]
  tools/release-image.sh --source IMAGE:TAG --immutable-tag TAG --channel CHANNEL [--channel CHANNEL...]

Options:
  --image IMAGE              Image repository, e.g. ghcr.io/ciwg/decomk-conf-cswg.
                             Default: infer from --source, else from .decomk/channels.json.
  --immutable-tag TAG        Required immutable release tag, e.g. block00 or block00-rc3.
  --channel CHANNEL          Required moving channel alias; repeatable.
  --source IMAGE:TAG         Promote this existing source instead of building.
  --stamp STAMP              Artifact/local-source stamp. Default: UTC YYYYMMDD-HHMMSS.
  --workspace-folder PATH    Workspace folder for checkpoint build. Default: .
  --config PATH              Devcontainer config path. Default: .devcontainer/devcontainer.json.
  --out-dir DIR              Artifact directory. Default: /tmp/decomk-conf-cswg-release-image-<STAMP>.
  --decomk PATH              decomk command or path. Default: decomk.
  --keep-container           Keep the checkpoint build container for diagnostics.
  -q, --quiet                Pass quiet mode to checkpoint build.
  --dry-run                  Print planned checkpoint commands without building or pushing.
  --allow-dirty              Allow a dirty git worktree.
  --skip-render-check        Skip decomk branch render freshness check.
  -h, --help                 Show help.

Examples:
  tools/release-image.sh --immutable-tag block00-rc3 --channel main --channel testing
  tools/release-image.sh --source ghcr.io/ciwg/decomk-conf-cswg:block00-rc3 --immutable-tag block00-rc3 --channel stable
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"

  if [[ "$cmd" == */* ]]; then
    if [[ -x "$cmd" ]]; then
      return 0
    fi
    die "required command is not executable: $cmd"
  fi

  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi

  die "required command not found: $cmd"
}

run_logged() {
  local step="$1"
  local stdout_file="$2"
  shift 2

  local log_file="$OUT_DIR/${step}.log"
  local command_display=""
  printf -v command_display '%q ' "$@"
  command_display="${command_display% }"

  {
    echo "### command"
    echo "$command_display"
    echo
    echo "### timestamp_utc"
    date -u +%Y-%m-%dT%H:%M:%SZ
  } >"$log_file"

  if [[ "$DRY_RUN" == "true" ]]; then
    jq -n \
      --arg step "$step" \
      --arg command "$command_display" \
      '{dryRun: true, step: $step, command: $command}' >"$stdout_file"
    echo "DRY RUN: $command_display"
    echo "DRY RUN output: $stdout_file"
    echo "DRY RUN log:    $log_file"
    return 0
  fi

  echo "Running: $command_display"
  if "$@" >"$stdout_file" 2>>"$log_file"; then
    echo "Wrote output: $stdout_file"
    echo "Wrote log:    $log_file"
    return 0
  fi

  local rc="$?"
  echo "ERROR: command failed with rc=$rc: $command_display" >&2
  echo "ERROR: see log: $log_file" >&2
  return "$rc"
}

infer_image() {
  local ref=""

  if [[ -n "$SOURCE" ]]; then
    ref="$SOURCE"
  else
    local registry_file="${WORKSPACE_FOLDER%/}/.decomk/channels.json"
    if [[ ! -f "$registry_file" ]]; then
      die "cannot infer --image; registry file not found: $registry_file"
    fi
    if ! ref="$(jq -er 'first(.channels | to_entries[] | .value.image? // empty)' "$registry_file" 2>/dev/null)"; then
      die "cannot infer --image; no channel image found in $registry_file"
    fi
  fi

  if [[ "$ref" == *@* ]]; then
    printf '%s\n' "${ref%@*}"
    return 0
  fi

  if [[ "${ref##*/}" == *:* ]]; then
    printf '%s\n' "${ref%:*}"
    return 0
  fi

  die "cannot infer image repository from untagged reference: $ref"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --image)
        [[ $# -ge 2 ]] || die "--image requires a value"
        IMAGE="$2"
        shift 2
        ;;
      --image=*)
        IMAGE="${1#--image=}"
        shift
        ;;
      --immutable-tag)
        [[ $# -ge 2 ]] || die "--immutable-tag requires a value"
        IMMUTABLE_TAG="$2"
        shift 2
        ;;
      --immutable-tag=*)
        IMMUTABLE_TAG="${1#--immutable-tag=}"
        shift
        ;;
      --channel)
        [[ $# -ge 2 ]] || die "--channel requires a value"
        CHANNELS+=("$2")
        shift 2
        ;;
      --channel=*)
        CHANNELS+=("${1#--channel=}")
        shift
        ;;
      --source)
        [[ $# -ge 2 ]] || die "--source requires a value"
        SOURCE="$2"
        shift 2
        ;;
      --source=*)
        SOURCE="${1#--source=}"
        shift
        ;;
      --stamp)
        [[ $# -ge 2 ]] || die "--stamp requires a value"
        STAMP="$2"
        shift 2
        ;;
      --stamp=*)
        STAMP="${1#--stamp=}"
        shift
        ;;
      --workspace-folder)
        [[ $# -ge 2 ]] || die "--workspace-folder requires a value"
        WORKSPACE_FOLDER="$2"
        shift 2
        ;;
      --workspace-folder=*)
        WORKSPACE_FOLDER="${1#--workspace-folder=}"
        shift
        ;;
      --config)
        [[ $# -ge 2 ]] || die "--config requires a value"
        CONFIG_PATH="$2"
        shift 2
        ;;
      --config=*)
        CONFIG_PATH="${1#--config=}"
        shift
        ;;
      --out-dir)
        [[ $# -ge 2 ]] || die "--out-dir requires a value"
        OUT_DIR="$2"
        shift 2
        ;;
      --out-dir=*)
        OUT_DIR="${1#--out-dir=}"
        shift
        ;;
      --decomk)
        [[ $# -ge 2 ]] || die "--decomk requires a value"
        DECOMK_BIN="$2"
        shift 2
        ;;
      --decomk=*)
        DECOMK_BIN="${1#--decomk=}"
        shift
        ;;
      --keep-container)
        KEEP_CONTAINER="true"
        shift
        ;;
      -q|--quiet)
        QUIET="true"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      --allow-dirty)
        ALLOW_DIRTY="true"
        shift
        ;;
      --skip-render-check)
        SKIP_RENDER_CHECK="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

preflight() {
  require_cmd bash
  require_cmd "$DECOMK_BIN"
  require_cmd docker
  require_cmd devcontainer
  require_cmd git
  require_cmd jq
  require_cmd date
  require_cmd awk

  if [[ ! -d "$WORKSPACE_FOLDER" ]]; then
    die "workspace folder not found: $WORKSPACE_FOLDER"
  fi

  local registry_file="${WORKSPACE_FOLDER%/}/.decomk/channels.json"
  if [[ ! -f "$registry_file" ]]; then
    die "channel registry not found: $registry_file"
  fi

  if [[ "$ALLOW_DIRTY" != "true" ]]; then
    local porcelain=""
    if ! porcelain="$(git -C "$WORKSPACE_FOLDER" status --porcelain)"; then
      die "failed to inspect git status under $WORKSPACE_FOLDER"
    fi
    if [[ -n "$porcelain" ]]; then
      echo "$porcelain" >&2
      die "git worktree is dirty; commit, stash, or pass --allow-dirty"
    fi
  fi

  if [[ "$SKIP_RENDER_CHECK" != "true" ]]; then
    local render_stdout="$OUT_DIR/render-check.out"
    local render_stderr="$OUT_DIR/render-check.err"
    if "$DECOMK_BIN" branch render -repo-root "$WORKSPACE_FOLDER" -channel auto -check >"$render_stdout" 2>"$render_stderr"; then
      :
    else
      local rc="$?"
      echo "ERROR: rendered devcontainer check failed with rc=$rc" >&2
      echo "ERROR: stdout: $render_stdout" >&2
      echo "ERROR: stderr: $render_stderr" >&2
      if [[ -s "$render_stderr" ]]; then
        echo "ERROR: render-check stderr follows:" >&2
        awk '{ print "ERROR:   " $0 }' "$render_stderr" >&2
      fi
      if [[ -s "$render_stdout" ]]; then
        echo "ERROR: render-check stdout follows:" >&2
        awk '{ print "ERROR:   " $0 }' "$render_stdout" >&2
      fi
      echo "ERROR: pass --skip-render-check only when you have intentionally accepted stale-render risk" >&2
      return "$rc"
    fi
  fi

  local channel=""
  for channel in "${CHANNELS[@]}"; do
    if [[ -z "$channel" ]]; then
      die "--channel cannot be empty"
    fi
    if [[ "$channel" == *:* || "$channel" == */* ]]; then
      die "--channel must be an image tag name, not a reference: $channel"
    fi
    if jq -e --arg channel "$channel" '.channels[$channel] != null' "$registry_file" >/dev/null; then
      :
    else
      die "channel '$channel' is not defined in $registry_file"
    fi
  done
}

main() {
  IMAGE=""
  IMMUTABLE_TAG=""
  SOURCE=""
  STAMP=""
  WORKSPACE_FOLDER="."
  CONFIG_PATH=".devcontainer/devcontainer.json"
  OUT_DIR=""
  DECOMK_BIN="decomk"
  KEEP_CONTAINER="false"
  QUIET="false"
  DRY_RUN="false"
  ALLOW_DIRTY="false"
  SKIP_RENDER_CHECK="false"
  CHANNELS=()

  parse_args "$@"

  if [[ -z "$STAMP" ]]; then
    STAMP="$(date -u +%Y%m%d-%H%M%S)"
  fi
  if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="/tmp/decomk-conf-cswg-release-image-${STAMP}"
  fi

  mkdir -p "$OUT_DIR"

  if [[ -z "$IMMUTABLE_TAG" ]]; then
    die "--immutable-tag is required"
  fi
  if [[ "$IMMUTABLE_TAG" == *:* || "$IMMUTABLE_TAG" == */* ]]; then
    die "--immutable-tag must be an image tag name, not a reference: $IMMUTABLE_TAG"
  fi
  if [[ "${#CHANNELS[@]}" -eq 0 ]]; then
    die "at least one --channel value is required"
  fi

  preflight

  if [[ -z "$IMAGE" ]]; then
    IMAGE="$(infer_image)"
  fi
  if [[ -z "$IMAGE" ]]; then
    die "--image resolved to an empty value"
  fi

  local local_source_ref="decomk-release:${IMMUTABLE_TAG}-${STAMP}"
  local release_ref="${IMAGE}:${IMMUTABLE_TAG}"
  local promote_source="$release_ref"

  if [[ -n "$SOURCE" ]]; then
    promote_source="$SOURCE"
  fi

  local channel_tags=()
  local channel=""
  for channel in "${CHANNELS[@]}"; do
    channel_tags+=("${IMAGE}:${channel}")
  done

  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "image=$IMAGE"
    echo "release_tag=$IMMUTABLE_TAG"
    echo "stamp=$STAMP"
    echo "source=${SOURCE:-}"
    echo "local_source_ref=$local_source_ref"
    echo "release_ref=$release_ref"
    echo "channels=${CHANNELS[*]}"
    echo "out_dir=$OUT_DIR"
    echo "dry_run=$DRY_RUN"
  } >"$OUT_DIR/metadata.env"

  echo "Release image plan"
  echo "- image:        $IMAGE"
  echo "- immutable:    $IMMUTABLE_TAG"
  echo "- channels:     ${CHANNELS[*]}"
  echo "- artifacts:    $OUT_DIR"
  if [[ -n "$SOURCE" ]]; then
    echo "- mode:         promote"
    echo "- source:       $SOURCE"
  else
    echo "- mode:         build"
    echo "- local source: $local_source_ref"
  fi
  echo "- release ref:  $release_ref"

  if [[ -z "$SOURCE" ]]; then
    local build_cmd=("$DECOMK_BIN" checkpoint build -workspace-folder "$WORKSPACE_FOLDER" -config "$CONFIG_PATH" -tag "$local_source_ref")
    if [[ "$KEEP_CONTAINER" == "true" ]]; then
      build_cmd+=(-keep-container)
    fi
    if [[ "$QUIET" == "true" ]]; then
      build_cmd+=(-q)
    fi

    run_logged checkpoint-build "$OUT_DIR/checkpoint-build.json" "${build_cmd[@]}"
    run_logged checkpoint-push-release "$OUT_DIR/checkpoint-push-release.json" "$DECOMK_BIN" checkpoint push "$local_source_ref" "$release_ref"
    promote_source="$release_ref"
  elif [[ "$SOURCE" != "$release_ref" ]]; then
    run_logged checkpoint-push-release "$OUT_DIR/checkpoint-push-release.json" "$DECOMK_BIN" checkpoint push "$SOURCE" "$release_ref"
    promote_source="$release_ref"
  fi

  run_logged checkpoint-tag-channels "$OUT_DIR/checkpoint-tag-channels.json" "$DECOMK_BIN" checkpoint tag -m "$promote_source" "${channel_tags[@]}"

  echo
  echo "Release image complete"
  echo "- source promoted: $promote_source"
  echo "- channels moved:  ${channel_tags[*]}"
  echo "- artifacts:       $OUT_DIR"
}

main "$@"
