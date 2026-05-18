#!/bin/bash
set -euo pipefail

# Intent: Validate GUI runtime health from inside a Codespace after decomk has
# selected the GUI selftest context and run both updateContent and postCreate.
# This checks the actual service/process/network contract that TODO 011 protects.
# Source: DI-013-20260518-054020 (TODO/013)

fail() {
  echo "GUI health check failed: $*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "required command is missing: $command_name"
  fi
}

has_word() {
  local list="$1"
  local word="$2"

  case " $list " in
    *" $word "*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

require_word() {
  local value_name="$1"
  local list="$2"
  local word="$3"

  if ! has_word "$list" "$word"; then
    fail "$value_name does not contain expected token '$word' (value: $list)"
  fi
}

load_decomk_env() {
  if [[ ! -f /var/decomk/env.sh ]]; then
    fail "/var/decomk/env.sh is missing"
  fi

  # shellcheck source=/dev/null
  source /var/decomk/env.sh
}

require_decomk_gui_context() {
  local update_targets
  local post_create_targets

  if [[ "${DEVCONTAINER_GUI:-}" != "1" ]]; then
    fail "DEVCONTAINER_GUI is '${DEVCONTAINER_GUI:-<unset>}', expected 1"
  fi

  require_word "DECOMK_CONTEXTS" "${DECOMK_CONTEXTS:-}" "DEFAULT"
  require_word "DECOMK_CONTEXTS" "${DECOMK_CONTEXTS:-}" "GUI_SELFTEST_1"

  # shellcheck disable=SC2154
  update_targets="${updateContent:-}"
  # shellcheck disable=SC2154
  post_create_targets="${postCreate:-}"

  require_word "updateContent" "$update_targets" "Block10"
  require_word "updateContent" "$update_targets" "GUIDesktop_1"
  require_word "postCreate" "$post_create_targets" "Block10"
  require_word "postCreate" "$post_create_targets" "GUIDesktop_1"
  require_word "postCreate" "$post_create_targets" "postCreateGUIDesktopNote"
}

service_status_is_healthy() {
  local service="$1"
  local status=""

  if ! status="$(sudo sv status "/etc/service/$service" 2>&1)"; then
    echo "service $service status command failed: $status" >&2
    return 1
  fi

  echo "service $service status: $status"
  case "$status" in
    run:*)
      ;;
    *)
      echo "service $service is not running" >&2
      return 1
      ;;
  esac

  if [[ "$status" == *'down:'* ]]; then
    echo "service $service reports a down component" >&2
    return 1
  fi
}

process_list_has() {
  local process_list="$1"
  local description="$2"
  local pattern="$3"

  case "$process_list" in
    *"$pattern"*)
      printf 'found %s with pattern %q\n' "$description" "$pattern"
      ;;
    *)
      printf 'missing %s with pattern %q\n' "$description" "$pattern" >&2
      return 1
      ;;
  esac
}

probe_gui_daemons() {
  local remote_user="${DECOMK_REMOTE_USER:-vscode}"
  local pid1=""
  local process_list=""
  local service=""

  pid1="$(ps -p 1 -o comm= | tr -d '[:space:]')"
  if [[ "$pid1" != "runsvdir" ]]; then
    printf 'PID 1 is %q, expected runsvdir\n' "$pid1" >&2
    return 1
  fi

  for service in xvfb openbox x11vnc novnc; do
    service_status_is_healthy "$service"
  done

  if ! process_list="$(ps -u "$remote_user" -o args= 2>&1)"; then
    printf 'could not list processes for %s: %s\n' "$remote_user" "$process_list" >&2
    return 1
  fi

  process_list_has "$process_list" "Xvfb" "Xvfb :0"
  process_list_has "$process_list" "Openbox" "openbox"
  process_list_has "$process_list" "x11vnc" "x11vnc -display :0"
  process_list_has "$process_list" "websockify" "websockify"
  process_list_has "$process_list" "websockify-port" "6080 127.0.0.1:5900"
}

wait_for_gui_daemons() {
  local deadline="$((SECONDS + GUI_HEALTH_READY_TIMEOUT_SECONDS))"
  local output=""
  local rc=0

  while ((SECONDS < deadline)); do
    set +e
    output="$(probe_gui_daemons 2>&1)"
    rc=$?
    set -e
    if ((rc == 0)); then
      printf '%s\n' "$output"
      return 0
    fi
    printf 'waiting for GUI daemons: %s\n' "$output" >&2
    sleep "$GUI_HEALTH_POLL_SECONDS"
  done

  printf '%s\n' "$output" >&2
  fail "GUI daemons did not become healthy within ${GUI_HEALTH_READY_TIMEOUT_SECONDS}s"
}

require_novnc_web_page() {
  local path html

  for path in /vnc.html /; do
    if html="$(curl -fsS --max-time 10 "http://127.0.0.1:6080${path}" 2>&1)"; then
      case "$html" in
        *noVNC*|*vnc.html*)
          printf 'noVNC web page is reachable at %s\n' "$path"
          return 0
          ;;
      esac
    fi
  done

  fail "noVNC web page is not reachable on port 6080"
}

require_direct_vnc_banner() {
  python3 - <<'PY'
import socket
import sys

try:
    with socket.create_connection(("127.0.0.1", 5900), timeout=10) as sock:
        sock.settimeout(10)
        banner = sock.recv(12)
except Exception as exc:
    print(f"direct VNC probe failed: {exc}", file=sys.stderr)
    sys.exit(1)

if not banner.startswith(b"RFB "):
    print(f"direct VNC probe returned non-RFB banner: {banner!r}", file=sys.stderr)
    sys.exit(1)

print(f"direct VNC probe returned {banner.decode('ascii', errors='replace').strip()}")
PY
}

require_novnc_websocket_to_vnc() {
  python3 - <<'PY'
import base64
import os
import socket
import struct
import sys


def recv_exact(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise RuntimeError("connection closed before receiving enough data")
        data += chunk
    return data


def read_ws_payload(sock):
    header = recv_exact(sock, 2)
    length = header[1] & 0x7F
    if length == 126:
        length = struct.unpack("!H", recv_exact(sock, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", recv_exact(sock, 8))[0]

    mask = b""
    if header[1] & 0x80:
        mask = recv_exact(sock, 4)

    payload = recv_exact(sock, length)
    if mask:
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    return payload


def try_path(path):
    key = base64.b64encode(os.urandom(16)).decode("ascii")
    request = (
        f"GET {path} HTTP/1.1\r\n"
        "Host: 127.0.0.1:6080\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "\r\n"
    )

    with socket.create_connection(("127.0.0.1", 6080), timeout=10) as sock:
        sock.settimeout(10)
        sock.sendall(request.encode("ascii"))
        response = sock.recv(4096)
        status_line = response.split(b"\r\n", 1)[0]
        if b" 101 " not in status_line:
            raise RuntimeError(f"{path} did not upgrade to websocket: {status_line!r}")
        payload = read_ws_payload(sock)
        if not payload.startswith(b"RFB "):
            raise RuntimeError(f"{path} upgraded, but first payload was not VNC RFB: {payload[:32]!r}")


errors = []
for candidate_path in ("/websockify", "/"):
    try:
        try_path(candidate_path)
    except Exception as exc:  # noqa: BLE001 - diagnostics need the exact failure.
        errors.append(f"{candidate_path}: {exc}")
    else:
        print(f"noVNC websocket reaches VNC desktop through {candidate_path}")
        sys.exit(0)

for error in errors:
    print(error, file=sys.stderr)
sys.exit(1)
PY
}

require_desktop_note() {
  local remote_user="${DECOMK_REMOTE_USER:-vscode}"
  local passwd_entry=""
  local user_home=""
  local note_path=""
  local owner=""

  if ! passwd_entry="$(getent passwd "$remote_user")"; then
    fail "unable to resolve passwd entry for $remote_user"
  fi

  IFS=: read -r _passwd_name _passwd_password _passwd_uid _passwd_gid _passwd_gecos user_home _passwd_shell <<<"$passwd_entry"
  if [[ -z "$user_home" ]]; then
    fail "unable to resolve home directory for $remote_user"
  fi

  note_path="$user_home/Desktop/clipboard-help.md"
  if [[ ! -f "$note_path" ]]; then
    fail "desktop note is missing: $note_path"
  fi

  if ! grep -q '^# noVNC Clipboard Help$' "$note_path"; then
    fail "desktop note does not contain expected title: $note_path"
  fi

  owner="$(stat -c '%U:%G' "$note_path")"
  if [[ "$owner" != "$remote_user:$remote_user" ]]; then
    fail "desktop note owner is $owner, expected $remote_user:$remote_user"
  fi

  echo "desktop note exists: $note_path"
}

require_no_todo011_error_in_logs() {
  local log_root=""
  local output=""
  local rc=0

  for log_root in "${DECOMK_LOG_DIR:-/var/log/decomk}" "${RUNIT_LOG_DIR:-/var/log/runit}"; do
    if [[ ! -d "$log_root" ]]; then
      continue
    fi

    set +e
    output="$(sudo grep -R -n -F 'unsupported GUI runit service: .' "$log_root" 2>&1)"
    rc=$?
    set -e

    case "$rc" in
      0)
        printf '%s\n' "$output" >&2
        fail "TODO 011 runit dispatch error appears in logs under $log_root"
        ;;
      1)
        echo "no TODO 011 runit dispatch error found under $log_root"
        ;;
      *)
        printf '%s\n' "$output" >&2
        fail "unable to scan logs under $log_root (grep rc=$rc)"
        ;;
    esac
  done
}

main() {
  GUI_HEALTH_READY_TIMEOUT_SECONDS="${GUI_HEALTH_READY_TIMEOUT_SECONDS:-180}"
  GUI_HEALTH_STABLE_SECONDS="${GUI_HEALTH_STABLE_SECONDS:-15}"
  GUI_HEALTH_POLL_SECONDS="${GUI_HEALTH_POLL_SECONDS:-2}"

  require_command curl
  require_command getent
  require_command grep
  require_command ps
  require_command python3
  require_command stat
  require_command sudo
  require_command sv

  load_decomk_env
  require_decomk_gui_context
  wait_for_gui_daemons
  sleep "$GUI_HEALTH_STABLE_SECONDS"
  probe_gui_daemons
  require_novnc_web_page
  require_direct_vnc_banner
  require_novnc_websocket_to_vnc
  require_desktop_note
  require_no_todo011_error_in_logs

  echo "GUI health check passed"
}

main "$@"
