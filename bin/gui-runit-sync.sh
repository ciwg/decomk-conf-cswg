#!/bin/bash
set -euo pipefail

# Intent: Keep the Makefile as a dependency graph and keep the operational
# shell logic here, where it can be linted and read as a normal script. This
# script also acts as the runit service runner when symlinked as
# `/etc/sv/<service>/run` or `/etc/sv/<service>/log/run`, avoiding generated
# shell scripts as runtime artifacts.
# Source: DI-dadak (TODO-rifol)

resolve_remote_user() {
  GUI_REMOTE_USER="${DECOMK_REMOTE_USER:-}"
  if [[ -z "$GUI_REMOTE_USER" ]]; then
    echo "ERROR: DECOMK_REMOTE_USER must be set by the container/stage-0 environment" >&2
    exit 1
  fi

  if ! GUI_REMOTE_UID="$(id -u "$GUI_REMOTE_USER" 2>/dev/null)"; then
    echo "ERROR: unable to resolve uid for $GUI_REMOTE_USER" >&2
    exit 1
  fi

  local passwd_entry
  if ! passwd_entry="$(getent passwd "$GUI_REMOTE_USER")"; then
    echo "ERROR: unable to resolve passwd entry for $GUI_REMOTE_USER" >&2
    exit 1
  fi

  IFS=: read -r _passwd_name _passwd_password _passwd_uid _passwd_gid _passwd_gecos GUI_USER_HOME _passwd_shell <<<"$passwd_entry"
  if [[ -z "$GUI_USER_HOME" ]]; then
    echo "ERROR: unable to resolve home directory for $GUI_REMOTE_USER" >&2
    exit 1
  fi

  GUI_XDG_RUNTIME_DIR="/run/user/$GUI_REMOTE_UID"
}

load_gui_defaults() {
  GUI_DISPLAY="${GUI_DISPLAY:-:0}"
  GUI_VNC_PORT="${GUI_VNC_PORT:-5900}"
  GUI_NOVNC_PORT="${GUI_NOVNC_PORT:-6080}"
}

run_as_gui_user() {
  exec chpst -u "$GUI_REMOTE_USER:$GUI_REMOTE_USER" env "$@"
}

wait_for_x() {
  while ! chpst -u "$GUI_REMOTE_USER:$GUI_REMOTE_USER" env DISPLAY="$GUI_DISPLAY" HOME="$GUI_USER_HOME" XDG_RUNTIME_DIR="$GUI_XDG_RUNTIME_DIR" xdpyinfo >/dev/null 2>&1; do
    sleep 1
  done
}

wait_for_vnc() {
  while ! bash -lc "exec 3<>/dev/tcp/127.0.0.1/$GUI_VNC_PORT" >/dev/null 2>&1; do
    sleep 1
  done
}

service_from_run_path() {
  local run_dir service_dir

  # Intent: Runit changes into each service directory and executes `./run`, so
  # `$0` does not always include `/etc/service/<name>/run`. Use the current
  # directory for the production runit path while preserving absolute-path
  # manual invocation for debugging. Source: DI-jitav
  case "$0" in
    ./run|run)
      run_dir="$PWD"
      ;;
    *)
      run_dir="$(dirname "$0")"
      ;;
  esac

  if [[ "$(basename "$run_dir")" == "log" ]]; then
    service_dir="$(dirname "$run_dir")"
  else
    service_dir="$run_dir"
  fi
  basename "$service_dir"
}

run_log_service() {
  local service runit_log_dir
  service="$(service_from_run_path)"
  runit_log_dir="${RUNIT_LOG_DIR:-}"
  if [[ -z "$runit_log_dir" ]]; then
    echo "ERROR: RUNIT_LOG_DIR must be set by the container environment" >&2
    exit 1
  fi

  exec svlogd -tt "$runit_log_dir/$service"
}

run_gui_service() {
  local service
  service="$(service_from_run_path)"
  resolve_remote_user
  load_gui_defaults

  case "$service" in
    xvfb)
      run_as_gui_user DISPLAY="$GUI_DISPLAY" HOME="$GUI_USER_HOME" XDG_RUNTIME_DIR="$GUI_XDG_RUNTIME_DIR" Xvfb "$GUI_DISPLAY" -screen 0 1920x1080x24 -ac -nolisten tcp
      ;;
    openbox)
      wait_for_x
      # Intent: Preserve the legacy mob-sandbox WebKitGTK workaround at the
      # desktop session boundary so terminals and GUI apps launched from
      # Openbox inherit it. The WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
      # variable is needed until WebKitGTK 2.56.4+ and 2.62.0+ are widely
      # available in distros, which will have the fix for CVE-2024-3177 that
      # does not require sandbox disabling.
      # Source: DI-samat (TODO-fogup)
      run_as_gui_user DISPLAY="$GUI_DISPLAY" HOME="$GUI_USER_HOME" XDG_RUNTIME_DIR="$GUI_XDG_RUNTIME_DIR" WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 dbus-run-session -- openbox-session
      ;;
    x11vnc)
      wait_for_x
      run_as_gui_user DISPLAY="$GUI_DISPLAY" HOME="$GUI_USER_HOME" XDG_RUNTIME_DIR="$GUI_XDG_RUNTIME_DIR" x11vnc -display "$GUI_DISPLAY" -forever -shared -rfbport "$GUI_VNC_PORT" -nopw -localhost
      ;;
    novnc)
      wait_for_vnc
      run_as_gui_user HOME="$GUI_USER_HOME" XDG_RUNTIME_DIR="$GUI_XDG_RUNTIME_DIR" websockify --web=/usr/share/novnc/ "$GUI_NOVNC_PORT" "127.0.0.1:$GUI_VNC_PORT"
      ;;
    *)
      echo "ERROR: unsupported GUI runit service: $service" >&2
      exit 1
      ;;
  esac
}

require_sync_environment() {
  RUNIT_SYNC_SV_DIR="${RUNIT_SV_DIR:-}"
  RUNIT_SYNC_SERVICE_DIR="${RUNIT_SERVICE_DIR:-}"
  RUNIT_SYNC_LOG_DIR="${RUNIT_LOG_DIR:-}"

  if [[ -z "$RUNIT_SYNC_SV_DIR" || -z "$RUNIT_SYNC_SERVICE_DIR" || -z "$RUNIT_SYNC_LOG_DIR" ]]; then
    echo "ERROR: RUNIT_SV_DIR, RUNIT_SERVICE_DIR, and RUNIT_LOG_DIR must be set by the container environment" >&2
    exit 1
  fi

  for required_cmd in sv chpst svlogd dbus-run-session; do
    if ! command -v "$required_cmd" >/dev/null 2>&1; then
      echo "ERROR: required GUI runtime command is missing: $required_cmd" >&2
      echo "ERROR: rebuild and republish the producer image before running GUIDesktop" >&2
      exit 1
    fi
  done

  local pid1
  pid1="$(ps -p 1 -o comm= | tr -d '[:space:]')"
  if [[ "$pid1" != "runsvdir" ]]; then
    echo "ERROR: PID 1 is '$pid1'; rebuild and republish the producer image so runsvdir is the entrypoint before running GUIDesktop" >&2
    exit 1
  fi
}

install_service_symlink() {
  local link_path script_path
  link_path="$1"
  script_path="$2"

  if [[ -L "$link_path" || -f "$link_path" ]]; then
    rm -f "$link_path"
  elif [[ -e "$link_path" ]]; then
    echo "ERROR: $link_path exists and is not a file or symlink" >&2
    exit 1
  fi

  ln -s "$script_path" "$link_path"
}

sync_gui_services() {
  local script_path
  script_path="$(readlink -f "${BASH_SOURCE[0]}")"

  resolve_remote_user
  load_gui_defaults
  require_sync_environment

  # Intent: Reconcile the GUI services into /etc/sv and /etc/service on every
  # GUI update so the producer image can stay GUI-neutral while GUI consumers
  # gain the needed desktop daemons through decomk context policy.
  # Source: DI-fiduv (TODO-fogup)
  install -d -m 0755 "$RUNIT_SYNC_SV_DIR" "$RUNIT_SYNC_SERVICE_DIR" "$RUNIT_SYNC_LOG_DIR"
  install -d -o "$GUI_REMOTE_USER" -g "$GUI_REMOTE_USER" -m 0700 "$GUI_XDG_RUNTIME_DIR"

  # Intent: Keep browser cache paths writable by the GUI user before Epiphany
  # asks WebKitGTK to add them to its sandbox path list.
  # Source: DI-samat (TODO-fogup)
  install -d -o "$GUI_REMOTE_USER" -g "$GUI_REMOTE_USER" -m 0700 "$GUI_USER_HOME/.cache" "$GUI_USER_HOME/.cache/epiphany" "$GUI_USER_HOME/.cache/mesa_shader_cache"

  # Intent: Make the packaged noVNC web root land on the actual client page at
  # `/` because Ubuntu's `novnc` package ships `vnc.html` but not `index.html`.
  # Source: DI-bonar (TODO-fogup)
  if [[ -d /usr/share/novnc && -e /usr/share/novnc/vnc.html && ! -e /usr/share/novnc/index.html ]]; then
    ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html
  fi

  for service in xvfb openbox x11vnc novnc; do
    install -d -m 0755 "$RUNIT_SYNC_SV_DIR/$service/log"
    install -d -m 0755 "$RUNIT_SYNC_LOG_DIR/$service"
    install_service_symlink "$RUNIT_SYNC_SV_DIR/$service/run" "$script_path"
    install_service_symlink "$RUNIT_SYNC_SV_DIR/$service/log/run" "$script_path"
  done

  for service in xvfb openbox x11vnc novnc; do
    local svc_link
    svc_link="$RUNIT_SYNC_SERVICE_DIR/$service"
    if [[ -L "$svc_link" ]]; then
      rm -f "$svc_link"
    elif [[ -e "$svc_link" ]]; then
      echo "ERROR: $svc_link exists and is not a symlink" >&2
      exit 1
    fi
    ln -s "$RUNIT_SYNC_SV_DIR/$service" "$svc_link"
  done

  for service in xvfb openbox x11vnc novnc; do
    local supervise_ok
    supervise_ok="$RUNIT_SYNC_SERVICE_DIR/$service/supervise/ok"
    for _attempt in {1..20}; do
      if [[ -e "$supervise_ok" ]]; then
        break
      fi
      sleep 1
    done
    if [[ ! -e "$supervise_ok" ]]; then
      echo "ERROR: runit did not start supervising $service" >&2
      exit 1
    fi
  done

  for service in xvfb openbox x11vnc novnc; do
    local svc_link
    svc_link="$RUNIT_SYNC_SERVICE_DIR/$service"
    if sv status "$svc_link" >/dev/null 2>&1; then
      if ! sv restart "$svc_link"; then
        rc="$?"
        echo "ERROR: failed to restart $service (rc=$rc)" >&2
        exit "$rc"
      fi
    else
      if ! sv up "$svc_link"; then
        rc="$?"
        echo "ERROR: failed to start $service (rc=$rc)" >&2
        exit "$rc"
      fi
    fi
    sv status "$svc_link"
  done
}

main() {
  if [[ "$(basename "$0")" == "run" ]]; then
    # Intent: Runit invokes both service `run` and `log/run` symlinks as
    # `./run`, so dispatch must use `$PWD` for the production path and `$0` for
    # absolute-path manual debugging. Source: DI-linod
    case "$0" in
      ./run|run)
        if [[ "$(basename "$PWD")" == "log" ]]; then
          run_log_service
        else
          run_gui_service
        fi
        ;;
      *)
        if [[ "$(basename "$(dirname "$0")")" == "log" ]]; then
          run_log_service
        else
          run_gui_service
        fi
        ;;
    esac
    return
  fi

  sync_gui_services
}

main "$@"
