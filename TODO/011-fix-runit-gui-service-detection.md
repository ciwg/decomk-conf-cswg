# 011 - Fix runit GUI service-name detection

## Decision Intent Log

ID: DI-011-20260517-212822
Date: 2026-05-17 21:28:22 UTC
Status: active
Decision: Fix the decomk GUI runit service runner so symlinked `./run` invocations derive the service name from the current service directory instead of only from `$0`.
Intent: Keep the existing single-script runit design for `xvfb`, `openbox`, `x11vnc`, and `novnc`, while preventing runit-managed services from exiting immediately with `ERROR: unsupported GUI runit service: .`.
Constraints: Preserve existing service names and commands; keep manual absolute-path debugging of `/etc/sv/<service>/run` working; do not add generated per-service wrapper scripts unless a thought experiment proves the single-script approach is untenable.
Affects: `bin/gui-runit-sync.sh`, `TODO/011-fix-runit-gui-service-detection.md`, `TODO/TODO.md`, and the `mob-sandbox` Codespaces GUI pull test.

## Handoff Context

The `mob-sandbox` Codespaces GUI build can finish with green devcontainer logs while the GUI daemons are not actually alive. The build log shows `sv restart` briefly seeing runit child processes, but later inspection shows only `runsv` supervisors remain and no long-lived `Xvfb`, `openbox`, `x11vnc`, or `websockify` processes.

A `mob-sandbox` pull-test update now SSHes into the new Codespace and fails unless:

- `xvfb`, `openbox`, `x11vnc`, and `novnc` stay healthy under `sv status`.
- The expected GUI daemons are present in the `vscode` process list.
- `http://127.0.0.1:6080/` serves the noVNC page.
- A WebSocket upgrade through noVNC reaches the VNC/RFB banner from `x11vnc`.

That enhanced test correctly fails against the current published `ghcr.io/ciwg/decomk-conf-cswg:main` image/config. Example failed Codespace from the mob-sandbox run:

- Display name: `pull-test-mob-sandbox-20260517-210453`
- Codespace name: `pull-test-mob-sandbox-20260517-210453-q54x6w4j9cwr`
- Captured log: `/tmp/cs-pull-test-mob-sandbox.log` on the mob-sandbox host

## Observed Failure

Inside the failed Codespace:

```sh
ps -p 1 -o pid,ppid,comm,args
sudo sv status /etc/service/xvfb
sudo sv status /etc/service/openbox
sudo sv status /etc/service/x11vnc
sudo sv status /etc/service/novnc
ps -ef | egrep 'runsv|Xvfb|openbox|x11vnc|websockify|novnc'
```

The result is that PID 1 is `runsvdir`, the `runsv` supervisors exist, but the actual GUI daemons are missing or constantly flapping. The `sv status` output includes patterns like:

```text
run: /etc/service/xvfb: (pid 9059) 0s; down: log: 0s, normally up, want up
```

The production invocation path can be reproduced directly:

```sh
for service in xvfb openbox x11vnc novnc; do
  sudo sh -c "cd /etc/service/$service && timeout 2 ./run" || echo "service $service failed"
  sudo sh -c "cd /etc/service/$service/log && timeout 2 ./run" || echo "log service $service failed"
done
```

Current output includes:

```text
ERROR: unsupported GUI runit service: .
```

## Root Cause

`bin/gui-runit-sync.sh` has one script that acts both as the setup/sync command and as every runit `run`/`log/run` script. The runit service files are symlinks to that one script.

The current `service_from_run_path()` infers the service name from `dirname "$0"`. That works for manual calls like `/etc/sv/xvfb/run`, where `$0` contains the service directory. It fails under real runit because runit changes into the service directory and executes the script as `./run`. In that case:

- `$0` is `./run`.
- `dirname "$0"` is `.`.
- `basename "$service_dir"` becomes `.`.
- `run_gui_service()` rejects `.` as an unsupported GUI service.

The same problem affects `log/run`, which is why the runit log files stay empty.

## Recommended Fix

Keep the single-script design, but make `service_from_run_path()` handle both invocation styles:

```sh
service_from_run_path() {
  local run_dir service_dir

  # Intent: Runit changes into each service directory and executes `./run`, so
  # `$0` does not always include `/etc/service/<name>/run`. Use the current
  # directory for the production runit path while preserving absolute-path
  # manual invocation for debugging. Source: DI-011-20260517-212822
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
```

If the implementing Codex sees multiple plausible designs beyond this minimal path fix, it should first run a Thought Experiment under `docs/thought-experiments/` per repo policy. At handoff time, this appears to be a single-root-cause bug with a minimal compatible fix, not a design fork.

## Validation Plan

- [ ] 011.1 Add or update a DI entry in this TODO if the implementation differs from the recommended fix.
- [ ] 011.2 Patch `bin/gui-runit-sync.sh` so `service_from_run_path()` supports runit `./run` and manual absolute-path invocations.
- [ ] 011.3 Run `bash -n bin/gui-runit-sync.sh`.
- [ ] 011.4 In a container or Codespace with GUI packages installed, confirm direct production-style invocation no longer reports service `.`:
  - `cd /etc/service/xvfb && timeout 2 ./run`
  - `cd /etc/service/xvfb/log && timeout 2 ./run`
- [ ] 011.5 Republish or otherwise test an image/config path that `mob-sandbox` can consume from `ghcr.io/ciwg/decomk-conf-cswg:main` or a chosen test channel.
- [ ] 011.6 From `~/lab/mob-sandbox`, rerun `GUI_HEALTH_READY_TIMEOUT_SECONDS=60 GUI_HEALTH_STABLE_SECONDS=5 ./scripts/pull-test.sh` and confirm it passes the GUI health check.
- [ ] 011.7 Inspect the passing Codespace to verify these are present as long-lived `vscode` processes: `Xvfb`, `openbox`, `x11vnc`, and `websockify`.

## Acceptance Criteria

- Runit-managed GUI services stay up for longer than the mob-sandbox health-check stability window.
- `sv status` for each GUI service does not include a `down:` component.
- noVNC on port `6080` serves the client page and its WebSocket path reaches the VNC/RFB banner.
- The fix preserves manual debugging via absolute service paths such as `/etc/sv/xvfb/run`.
- The mob-sandbox pull test fails on the old behavior and passes after the fixed conf image/config is consumed.
