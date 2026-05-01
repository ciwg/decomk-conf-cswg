SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c
.RECIPEPREFIX := >

# - decomk expands tuples from decomk.conf, then calls `make` in a stamp
#   directory (`DECOMK_STAMPDIR`), not in this repo root.
# - Because of that, scripts in this repo should be referenced with an absolute
#   path derived from `DECOMK_HOME` (which points at the decomk state root).
# - Targets should normally end with `touch $@` so repeated runs are
#   idempotent.  Exceptions include those cases where you definitely want
#   to run the stanza every time, e.g. to update content, or any
#   "parent" targets that just call other targets.

# Intent: Keep shared setup in checkpointable Block* targets and keep repo-specific
# targets separate so context tuples can compose baseline vs special behavior.
# Source: DI-002-20260423-182418 (TODO/002)

CONF_BIN_DIR := $(DECOMK_HOME)/conf/bin
DEVCONTAINER_GUI ?= 0
DECOMK_MAKE_USER ?= $(shell id -un)
GUI_DISPLAY := :0
GUI_VNC_PORT := 5900
GUI_NOVNC_PORT := 6080

# Intent: Keep the main target graph root-run under decomk while still allowing
# explicit user-owned artifacts such as Desktop notes to be written correctly.
# Source: DI-004-20260430-182956 (TODO/004)
AS_DEV :=
ifneq ($(strip $(DECOMK_REMOTE_USER)),)
ifneq ($(DECOMK_MAKE_USER),$(DECOMK_REMOTE_USER))
AS_DEV = runuser -u $(DECOMK_REMOTE_USER) --
endif
endif

.PHONY: all updateContent postCreate GUIDesktop gui_runit_sync postCreateGUIDesktopNote postCreateUserDemo

# `all` is for manual updates and testing
all: updateContent
>@echo "decomk conf repo all-target completed"

# Intent: Action target names match decomk stage-0 lifecycle actions directly
# (`updateContent` and `postCreate`) without extra phase-prefixed wrappers.
# Source: DI-002-20260423-182418 (TODO/002)
# Intent: Do not hard-gate action targets on `DECOMK_STAGE0_PHASE`; decomk
# selects the action target itself, and direct make target runs should remain
# useful for troubleshooting.
# Source: DI-002-20260423-183647 (TODO/002)
updateContent: Block10
>@echo "Running updateContent actions"

# postCreate intentionally runs the same shared baseline targets as updateContent,
# then runs any per-user actions
postCreate: Block10 postCreateUserDemo
>@echo "Running postCreate actions"

# -----------------------------------------------------------------------------
# Shared baseline block layering (checkpoint-friendly)
# -----------------------------------------------------------------------------

# Block00 is a mostly-vanilla ubuntu image with minimal customization.
Block00: hello-test

# Intent: Keep pinned apt packages in one-stanza-per-version targets so
# version history is append-only and each upgrade is an additive Block10 prereq.
# Source: DI-002-20260423-184207 (TODO/002)
Block10: Block00 \
  vim_2_9_1_0016_1ubuntu7_12 \
  neovim_0_9_5_6ubuntu2 \
  openssh_client_e1_9_6p1_3ubuntu13_15 \
  curl_8_5_0_2ubuntu10_8 \
  wget_1_21_4_1ubuntu4_1 \
  git_e1_2_43_0_1ubuntu7_3 \
  jq_1_7_1_3ubuntu0_24_04_1 \
  make_4_3_4_1build2 \
  golang_go_e2_1_22_2build1 

dubious-delete-me: Block10 \
  python3_pip_24_0_dfsg_1ubuntu1_3 \
  build_essential_12_10ubuntu1 \
  libssl_dev_3_0_13_0ubuntu3_9 \
  zlib1g_dev_e1_1_3_dfsg_3_1ubuntu2_1 \
  libbz2_dev_1_0_8_5_1build0_1 \
  libreadline_dev_8_2_4build1 \
  libsqlite3_dev_3_45_1_1ubuntu2_5 \
  libffi_dev_3_4_6_1build1 \
  liblzma_dev_5_6_1_really5_4_5_1ubuntu0_2 \
  python3_3_12_3_0ubuntu2_1



# -----------------------------------------------------------------------------
# Repo-special feature targets
# -----------------------------------------------------------------------------

FPGA: OSS I2C COCOTB

# Intent: Keep GUI packages isolated from Block10 and reconcile GUI services in
# the standard runit system paths on every GUI update so repo context controls
# desktop behavior without moving init configuration into /var/decomk.
# Source: DI-004-20260430-182956 (TODO/004)
GUIDesktop: \
  epiphany_browser_46_5_0ubuntu1 \
  novnc_e1_1_3_0_2 \
  openbox_3_6_1_12build5 \
  websockify_0_10_0_dfsg1_5build2 \
  x11_apps_7_7_11build3 \
  x11_utils_7_7_6build2 \
  x11vnc_0_9_16_10 \
  xvfb_e2_21_1_12_1ubuntu1_5 \
  gui_runit_sync
>@echo "GUI desktop mode reconciled for $(DECOMK_REMOTE_USER)"

# Intent: Reconcile the GUI services into /etc/sv and /etc/service on every
# GUI update so the producer image can stay GUI-neutral while mob-sandbox gains
# the needed desktop daemons through decomk context policy.
# Source: DI-004-20260430-182956 (TODO/004)
gui_runit_sync:
>@remote_user="$(DECOMK_REMOTE_USER)"; \
>runit_sv_dir="$(RUNIT_SV_DIR)"; \
>runit_service_dir="$(RUNIT_SERVICE_DIR)"; \
>runit_log_dir="$(RUNIT_LOG_DIR)"; \
>if [[ -z "$$remote_user" ]]; then \
>  echo "ERROR: DECOMK_REMOTE_USER must be set by the container/stage-0 environment"; \
>  exit 1; \
>fi; \
>if [[ -z "$$runit_sv_dir" || -z "$$runit_service_dir" || -z "$$runit_log_dir" ]]; then \
>  echo "ERROR: RUNIT_SV_DIR, RUNIT_SERVICE_DIR, and RUNIT_LOG_DIR must be set by the container environment"; \
>  exit 1; \
>fi; \
>remote_uid="$$(id -u "$$remote_user" 2>/dev/null || true)"; \
>user_home="$$(getent passwd "$$remote_user" | cut -d: -f6)"; \
>if [[ -z "$$remote_uid" ]]; then \
>  echo "ERROR: unable to resolve uid for $$remote_user"; \
>  exit 1; \
>fi; \
>if [[ -z "$$user_home" ]]; then \
>  echo "ERROR: unable to resolve home directory for $$remote_user"; \
>  exit 1; \
>fi; \
>if ! command -v sv >/dev/null 2>&1 || ! command -v chpst >/dev/null 2>&1 || ! command -v svlogd >/dev/null 2>&1; then \
>  echo "ERROR: runit tools are missing; rebuild and republish the producer image before running GUIDesktop"; \
>  exit 1; \
>fi; \
>pid1="$$(ps -p 1 -o comm= | tr -d '[:space:]')"; \
>if [[ "$$pid1" != "runsvdir" ]]; then \
>  echo "ERROR: PID 1 is '$$pid1'; rebuild and republish the producer image so runsvdir is the entrypoint before running GUIDesktop"; \
>  exit 1; \
>fi; \
>runtime_dir="/run/user/$$remote_uid"; \
>install -d -m 0755 "$$runit_sv_dir" "$$runit_service_dir" "$$runit_log_dir"; \
>install -d -o "$$remote_user" -g "$$remote_user" -m 0700 "$$runtime_dir"; \
># Intent: Make the packaged noVNC web root land on the actual client page at
># `/` because Ubuntu's `novnc` package ships `vnc.html` but not `index.html`.
># Source: DI-004-20260430-194224 (TODO/004)
>if [[ -d /usr/share/novnc ]] && [[ -e /usr/share/novnc/vnc.html ]] && [[ ! -e /usr/share/novnc/index.html ]]; then \
>  ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html; \
>fi; \
>for service in xvfb openbox x11vnc novnc; do \
>  install -d -m 0755 "$$runit_sv_dir/$$service/log"; \
>  install -d -m 0755 "$$runit_log_dir/$$service"; \
>done; \
>cat > "$$runit_sv_dir/xvfb/run" <<EOF
>#!/bin/bash
>set -euo pipefail
>exec chpst -u $$remote_user:$$remote_user env DISPLAY=$(GUI_DISPLAY) HOME=$$user_home XDG_RUNTIME_DIR=$$runtime_dir Xvfb $(GUI_DISPLAY) -screen 0 1920x1080x24 -ac -nolisten tcp
>EOF
>chmod 0755 "$$runit_sv_dir/xvfb/run"; \
>cat > "$$runit_sv_dir/xvfb/log/run" <<EOF
>#!/bin/bash
>set -euo pipefail
>exec svlogd -tt "$$runit_log_dir/xvfb"
>EOF
>chmod 0755 "$$runit_sv_dir/xvfb/log/run"; \
>cat > "$$runit_sv_dir/openbox/run" <<EOF
>#!/bin/bash
>set -euo pipefail
>while ! chpst -u $$remote_user:$$remote_user env DISPLAY=$(GUI_DISPLAY) HOME=$$user_home XDG_RUNTIME_DIR=$$runtime_dir xdpyinfo >/dev/null 2>&1; do
>  sleep 1
>done
>exec chpst -u $$remote_user:$$remote_user env DISPLAY=$(GUI_DISPLAY) HOME=$$user_home XDG_RUNTIME_DIR=$$runtime_dir openbox-session
>EOF
>chmod 0755 "$$runit_sv_dir/openbox/run"; \
>cat > "$$runit_sv_dir/openbox/log/run" <<EOF
>#!/bin/bash
>set -euo pipefail
>exec svlogd -tt "$$runit_log_dir/openbox"
>EOF
>chmod 0755 "$$runit_sv_dir/openbox/log/run"; \
>cat > "$$runit_sv_dir/x11vnc/run" <<EOF
>#!/bin/bash
>set -euo pipefail
>while ! chpst -u $$remote_user:$$remote_user env DISPLAY=$(GUI_DISPLAY) HOME=$$user_home XDG_RUNTIME_DIR=$$runtime_dir xdpyinfo >/dev/null 2>&1; do
>  sleep 1
>done
>exec chpst -u $$remote_user:$$remote_user env DISPLAY=$(GUI_DISPLAY) HOME=$$user_home XDG_RUNTIME_DIR=$$runtime_dir x11vnc -display $(GUI_DISPLAY) -forever -shared -rfbport $(GUI_VNC_PORT) -nopw -localhost
>EOF
>chmod 0755 "$$runit_sv_dir/x11vnc/run"; \
>cat > "$$runit_sv_dir/x11vnc/log/run" <<EOF
>#!/bin/bash
>set -euo pipefail
>exec svlogd -tt "$$runit_log_dir/x11vnc"
>EOF
>chmod 0755 "$$runit_sv_dir/x11vnc/log/run"; \
>cat > "$$runit_sv_dir/novnc/run" <<EOF
>#!/bin/bash
>set -euo pipefail
>while ! bash -lc 'exec 3<>/dev/tcp/127.0.0.1/$(GUI_VNC_PORT)' >/dev/null 2>&1; do
>  sleep 1
>done
>exec chpst -u $$remote_user:$$remote_user env HOME=$$user_home XDG_RUNTIME_DIR=$$runtime_dir websockify --web=/usr/share/novnc/ $(GUI_NOVNC_PORT) 127.0.0.1:$(GUI_VNC_PORT)
>EOF
>chmod 0755 "$$runit_sv_dir/novnc/run"; \
>cat > "$$runit_sv_dir/novnc/log/run" <<EOF
>#!/bin/bash
>set -euo pipefail
>exec svlogd -tt "$$runit_log_dir/novnc"
>EOF
>chmod 0755 "$$runit_sv_dir/novnc/log/run"; \
>for service in xvfb openbox x11vnc novnc; do \
>  svc_link="$$runit_service_dir/$$service"; \
>  if [[ -L "$$svc_link" ]]; then \
>    rm -f "$$svc_link"; \
>  elif [[ -e "$$svc_link" ]]; then \
>    echo "ERROR: $$svc_link exists and is not a symlink"; \
>    exit 1; \
>  fi; \
>  ln -s "$$runit_sv_dir/$$service" "$$svc_link"; \
>done; \
>for service in xvfb openbox x11vnc novnc; do \
>  supervise_ok="$$runit_service_dir/$$service/supervise/ok"; \
>  for _ in {1..20}; do \
>    if [[ -e "$$supervise_ok" ]]; then \
>      break; \
>    fi; \
>    sleep 1; \
>  done; \
>  if [[ ! -e "$$supervise_ok" ]]; then \
>    echo "ERROR: runit did not start supervising $$service"; \
>    exit 1; \
>  fi; \
>done; \
>for service in xvfb openbox x11vnc novnc; do \
>  svc_link="$$runit_service_dir/$$service"; \
>  if sv status "$$svc_link" >/dev/null 2>&1; then \
>    if ! sv restart "$$svc_link"; then \
>      rc="$$?"; \
>      echo "ERROR: failed to restart $$service (rc=$$rc)"; \
>      exit "$$rc"; \
>    fi; \
>  else \
>    if ! sv up "$$svc_link"; then \
>      rc="$$?"; \
>      echo "ERROR: failed to start $$service (rc=$$rc)"; \
>      exit "$$rc"; \
>    fi; \
>  fi; \
>  sv status "$$svc_link"; \
>done

# Intent: Replace the legacy popup reminder with a deterministic Desktop note so
# GUI users still get clipboard guidance without notifier/autostart complexity.
# Source: DI-004-20260430-182956 (TODO/004)
postCreateGUIDesktopNote:
>@remote_user="$(DECOMK_REMOTE_USER)"; \
>if [[ -z "$$remote_user" ]]; then \
>  echo "ERROR: DECOMK_REMOTE_USER must be set by the container/stage-0 environment"; \
>  exit 1; \
>fi; \
>user_home="$$(getent passwd "$$remote_user" | cut -d: -f6)"; \
>if [[ -z "$$user_home" ]]; then \
>  echo "ERROR: unable to resolve home directory for $$remote_user"; \
>  exit 1; \
>fi; \
>desktop_dir="$$user_home/Desktop"; \
>note_path="$$desktop_dir/clipboard-help.md"; \
>install -d -o "$$remote_user" -g "$$remote_user" -m 0755 "$$desktop_dir"; \
>$(AS_DEV) tee "$$note_path" >/dev/null <<'EOF'
># noVNC Clipboard Help
>
>* Clipboard integration in browser-based desktops can be inconsistent.
>* If paste fails, use the browser's paste controls or your terminal/context-menu paste.
>* Plain-text paste is the safest option for commands and code snippets.
>EOF
>chmod 0644 "$$note_path"; \
>echo "Wrote $$note_path"

hello-test:
>bash $(CONF_BIN_DIR)/hello-world.sh "hello-common" "$(HELLO_TEXT)" "$(DECOMK_STAGE0_PHASE)" "$(DEVCONTAINER_GUI)"

# -----------------------------------------------------------------------------
# Base tools and language runtimes
# -----------------------------------------------------------------------------
# Versions pinned to Ubuntu 24.04 (noble) as of the base image
# mcr.microsoft.com/devcontainers/base:ubuntu-24.04

apt_index_noble_2026_04_23:
>apt-get update -qq
>@touch $@

vim_2_9_1_0016_1ubuntu7_12: apt_index_noble_2026_04_23
>apt-get install -y -qq vim=2:9.1.0016-1ubuntu7.12
>@touch $@

neovim_0_9_5_6ubuntu2: apt_index_noble_2026_04_23
>apt-get install -y -qq neovim=0.9.5-6ubuntu2
>@touch $@

openssh_client_e1_9_6p1_3ubuntu13_15: apt_index_noble_2026_04_23
>apt-get install -y -qq openssh-client=1:9.6p1-3ubuntu13.15
>@touch $@

curl_8_5_0_2ubuntu10_8: apt_index_noble_2026_04_23
>apt-get install -y -qq curl=8.5.0-2ubuntu10.8
>@touch $@

wget_1_21_4_1ubuntu4_1: apt_index_noble_2026_04_23
>apt-get install -y -qq wget=1.21.4-1ubuntu4.1
>@touch $@

git_e1_2_43_0_1ubuntu7_3: apt_index_noble_2026_04_23
>apt-get install -y -qq git=1:2.43.0-1ubuntu7.3
>@touch $@

jq_1_7_1_3ubuntu0_24_04_1: apt_index_noble_2026_04_23
>apt-get install -y -qq jq=1.7.1-3ubuntu0.24.04.1
>@touch $@

make_4_3_4_1build2: apt_index_noble_2026_04_23
>apt-get install -y -qq make=4.3-4.1build2
>@touch $@

python3_pip_24_0_dfsg_1ubuntu1_3: apt_index_noble_2026_04_23
>apt-get install -y -qq python3-pip=24.0+dfsg-1ubuntu1.3
>@touch $@

build_essential_12_10ubuntu1: apt_index_noble_2026_04_23
>apt-get install -y -qq build-essential=12.10ubuntu1
>@touch $@

libssl_dev_3_0_13_0ubuntu3_9: apt_index_noble_2026_04_23
>apt-get install -y -qq libssl-dev=3.0.13-0ubuntu3.9
>@touch $@

zlib1g_dev_e1_1_3_dfsg_3_1ubuntu2_1: apt_index_noble_2026_04_23
>apt-get install -y -qq zlib1g-dev=1:1.3.dfsg-3.1ubuntu2.1
>@touch $@

libbz2_dev_1_0_8_5_1build0_1: apt_index_noble_2026_04_23
>apt-get install -y -qq libbz2-dev=1.0.8-5.1build0.1
>@touch $@

libreadline_dev_8_2_4build1: apt_index_noble_2026_04_23
>apt-get install -y -qq libreadline-dev=8.2-4build1
>@touch $@

libsqlite3_dev_3_45_1_1ubuntu2_5: apt_index_noble_2026_04_23
>apt-get install -y -qq libsqlite3-dev=3.45.1-1ubuntu2.5
>@touch $@

libffi_dev_3_4_6_1build1: apt_index_noble_2026_04_23
>apt-get install -y -qq libffi-dev=3.4.6-1build1
>@touch $@

liblzma_dev_5_6_1_really5_4_5_1ubuntu0_2: apt_index_noble_2026_04_23
>apt-get install -y -qq liblzma-dev=5.6.1+really5.4.5-1ubuntu0.2
>@touch $@

# Intent: Keep language runtimes on distro-managed packages for this container
# flow; versioning stays append-only by using versioned target names.
# Source: DI-002-20260423-192405 (TODO/002)
golang_go_e2_1_22_2build1: apt_index_noble_2026_04_23
>apt-get install -y -qq golang-go=2:1.22~2build1
>@touch $@

python3_3_12_3_0ubuntu2_1: apt_index_noble_2026_04_23
>apt-get install -y -qq python3=3.12.3-0ubuntu2.1
>@touch $@

# -----------------------------------------------------------------------------
# GUI desktop packages and runtime
# -----------------------------------------------------------------------------

openbox_3_6_1_12build5: apt_index_noble_2026_04_23
>apt-get install -y -qq openbox=3.6.1-12build5
>@touch $@

x11vnc_0_9_16_10: apt_index_noble_2026_04_23
>apt-get install -y -qq x11vnc=0.9.16-10
>@touch $@

xvfb_e2_21_1_12_1ubuntu1_5: apt_index_noble_2026_04_23
>apt-get install -y -qq xvfb=2:21.1.12-1ubuntu1.5
>@touch $@

x11_apps_7_7_11build3: apt_index_noble_2026_04_23
>apt-get install -y -qq x11-apps=7.7+11build3
>@touch $@

x11_utils_7_7_6build2: apt_index_noble_2026_04_23
>apt-get install -y -qq x11-utils=7.7+6build2
>@touch $@

novnc_e1_1_3_0_2: apt_index_noble_2026_04_23
>apt-get install -y -qq novnc=1:1.3.0-2
>@touch $@

websockify_0_10_0_dfsg1_5build2: apt_index_noble_2026_04_23
>apt-get install -y -qq websockify=0.10.0+dfsg1-5build2
>@touch $@

epiphany_browser_46_5_0ubuntu1: apt_index_noble_2026_04_23
>apt-get install -y -qq epiphany-browser=46.5-0ubuntu1
>@touch $@

# -----------------------------------------------------------------------------
# FPGA-specific tools
# -----------------------------------------------------------------------------

OSS: wget_1_21_4_1ubuntu4_1
>if [[ -x "/opt/oss-cad-suite/bin/iverilog" ]]; then \
>  echo "oss-cad-suite already installed, skipping"; \
>else \
>  wget -q "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-03-07/oss-cad-suite-linux-x64-20260307.tgz" -O /tmp/oss-cad-suite.tgz; \
>  mkdir -p /opt; \
>  tar xzf /tmp/oss-cad-suite.tgz -C /opt; \
>  rm -f /tmp/oss-cad-suite.tgz; \
>fi
>echo 'export PATH="/opt/oss-cad-suite/bin:$$PATH"' > /etc/profile.d/oss-cad-suite.sh
>@touch $@

# Intent: Fail explicitly when I2C reference clone fails so setup regressions are
# visible; this target is part of the shared FPGA install graph.
# Source: DI-002-20260423-182418 (TODO/002)
I2C: git_e1_2_43_0_1ubuntu7_3
>if [[ -d "/workspaces/i2cslave/.git" ]]; then \
>  echo "I2C reference already present, skipping clone"; \
>elif [[ -e "/workspaces/i2cslave" ]]; then \
>  echo "ERROR: /workspaces/i2cslave exists but is not a git checkout"; \
>  exit 1; \
>else \
>  mkdir -p /workspaces; \
>  if ! GIT_TERMINAL_PROMPT=0 git clone https://github.com/AdrianSuliga/I2C-Slave-Controller.git /workspaces/i2cslave; then \
>    rc="$$?"; \
>    echo "ERROR: failed to clone I2C reference repo (rc=$$rc)"; \
>    exit "$$rc"; \
>  fi; \
>fi
>@touch $@

COCOTB: python3_3_12_3_0ubuntu2_1 python3_pip_24_0_dfsg_1ubuntu1_3
>if python3 -c 'import cocotb' >/dev/null 2>&1; then \
>  echo "cocotb already installed, skipping"; \
>else \
>  pip3 install cocotb==2.0.1 cocotb-bus==0.3.0; \
>fi
>@touch $@

# Intent: Keep a runtime/user-level evidence hook that appends per-user entries
# on every postCreate run without relying on stamp-skipped file targets.
# Source: DI-002-20260423-182418 (TODO/002)
postCreateUserDemo:
>@user="$${GITHUB_USER:-unknown-user}"; \
>dest_dir="$(DECOMK_HOME)/users"; \
>mkdir -p "$$dest_dir"; \
>timestamp="$$({ date -u +%Y-%m-%dT%H:%M:%SZ; })"; \
>printf '%s phase=%s user=%s repo=%s gui=%s\n' \
>  "$$timestamp" \
>  "$${DECOMK_STAGE0_PHASE:-postCreate}" \
>  "$$user" \
>  "$${GITHUB_REPOSITORY:-<unset>}" \
>  "$(DEVCONTAINER_GUI)" \
>  >> "$$dest_dir/$$user.txt"; \
>echo "Appended postCreate user demo entry to $$dest_dir/$$user.txt"
