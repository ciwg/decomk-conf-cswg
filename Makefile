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
# Source: DI-vusag (TODO-lusaz)
#
# Intent: Use hyphenated Make target names where Make permits them, while
# preserving identifier-style variable names and decomk lifecycle action names.
# Source: DI-ruvop (TODO-fogus)

CONF_BIN_DIR := $(DECOMK_HOME)/conf/bin
DECOMK_MAKE_USER ?= $(shell id -un)
GUI_DISPLAY := :0
GUI_VNC_PORT := 5900
GUI_NOVNC_PORT := 6080

# Intent: Keep the main target graph root-run under decomk while still allowing
# explicit user-owned artifacts such as Desktop notes to be written correctly.
# Source: DI-fiduv (TODO-fogup)
AS_DEV :=
ifneq ($(strip $(DECOMK_REMOTE_USER)),)
ifneq ($(DECOMK_MAKE_USER),$(DECOMK_REMOTE_USER))
AS_DEV = runuser -u $(DECOMK_REMOTE_USER) --
endif
endif

.PHONY: all updateContent postCreate GUIDesktop-1 gui-runit-sync postCreateGUIDesktopNote postCreateUserDemo

# `all` is for manual updates and testing
all: updateContent
>@echo "decomk conf repo all-target completed"

# Intent: Action target names match decomk stage-0 lifecycle actions directly
# (`updateContent` and `postCreate`) without extra phase-prefixed wrappers.
# Source: DI-vusag (TODO-lusaz)
# Intent: Do not hard-gate action targets on `DECOMK_STAGE0_PHASE`; decomk
# selects the action target itself, and direct make target runs should remain
# useful for troubleshooting.
# Source: DI-dudam (TODO-lusaz)
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
# Source: DI-sidat (TODO-lusaz)
Block10: Block00 \
  vim-2-9-1-0016-1ubuntu7-12 \
  neovim-0-9-5-6ubuntu2 \
  openssh-client-e1-9-6p1-3ubuntu13-16 \
  curl-8-5-0-2ubuntu10-8 \
  wget-1-21-4-1ubuntu4-1 \
  git-e1-2-43-0-1ubuntu7-3 \
  jq-1-7-1-3ubuntu0-24-04-1 \
  make-4-3-4-1build2

dubious-delete-me: Block10 \
  python3-pip-24-0-dfsg-1ubuntu1-3 \
  build-essential-12-10ubuntu1 \
  libssl-dev-3-0-13-0ubuntu3-9 \
  zlib1g-dev-e1-1-3-dfsg-3-1ubuntu2-1 \
  libbz2-dev-1-0-8-5-1build0-1 \
  libreadline-dev-8-2-4build1 \
  libsqlite3-dev-3-45-1-1ubuntu2-5 \
  libffi-dev-3-4-6-1build1 \
  liblzma-dev-5-6-1-really5-4-5-1ubuntu0-2 \
  python3-3-12-3-0ubuntu2-1



# -----------------------------------------------------------------------------
# Repo-special feature targets
# -----------------------------------------------------------------------------

FPGA-1: GUIDesktop-1 OSS-20260307 COCOTB-2-0-1

# Intent: Keep GUI packages isolated from Block10 and reconcile GUI services in
# the standard runit system paths on every GUI update so repo context controls
# desktop behavior without moving init configuration into /var/decomk.
# Source: DI-fiduv (TODO-fogup)
GUIDesktop-1: \
  dbus-x11-1-14-10-4ubuntu4-1 \
  epiphany-browser-46-5-0ubuntu1 \
  novnc-e1-1-3-0-2 \
  openbox-3-6-1-12build5 \
  websockify-0-10-0-dfsg1-5build2 \
  x11-apps-7-7-11build3 \
  x11-utils-7-7-6build2 \
  x11vnc-0-9-16-10 \
  xterm-390-1ubuntu3 \
  xvfb-e2-21-1-12-1ubuntu1-5 \
  gui-runit-sync

# Intent: Reconcile the GUI services into /etc/sv and /etc/service on every
# GUI update so the producer image can stay GUI-neutral while mob-sandbox gains
# the needed desktop daemons through decomk context policy.
# Source: DI-fiduv (TODO-fogup)
gui-runit-sync:
>GUI_DISPLAY="$(GUI_DISPLAY)" GUI_VNC_PORT="$(GUI_VNC_PORT)" GUI_NOVNC_PORT="$(GUI_NOVNC_PORT)" bash $(CONF_BIN_DIR)/gui-runit-sync.sh

# Intent: Replace the legacy popup reminder with a deterministic Desktop note so
# GUI users still get clipboard guidance without notifier/autostart complexity.
# Source: DI-fiduv (TODO-fogup)
postCreateGUIDesktopNote:
>bash $(CONF_BIN_DIR)/write-gui-desktop-note.sh

hello-test:
>bash $(CONF_BIN_DIR)/hello-world.sh "hello-common" "$(HELLO_TEXT)" "$(DECOMK_STAGE0_PHASE)"

# -----------------------------------------------------------------------------
# Base tools and language runtimes
# -----------------------------------------------------------------------------
# Versions pinned to Ubuntu 24.04 (noble) as of the base image
# mcr.microsoft.com/devcontainers/base:ubuntu-24.04

apt-index-noble-2026-04-23:
>apt-pin update -qq
>@touch $@

vim-2-9-1-0016-1ubuntu7-12: apt-index-noble-2026-04-23
>apt-pin install -y -qq vim=2:9.1.0016-1ubuntu7.12
>@touch $@

neovim-0-9-5-6ubuntu2: apt-index-noble-2026-04-23
>apt-pin install -y -qq neovim=0.9.5-6ubuntu2
>@touch $@

# Intent: Match the producer image's configured Ubuntu snapshot; the older
# 13.15 pin is not present in `20260430T000000Z`, while 13.16 is present and
# already matches the Dockerfile's OpenSSH bootstrap version.
# Source: DI-zakul (TODO-hopun)
openssh-client-e1-9-6p1-3ubuntu13-16: apt-index-noble-2026-04-23
>apt-pin install -y -qq openssh-client=1:9.6p1-3ubuntu13.16
>@touch $@

curl-8-5-0-2ubuntu10-8: apt-index-noble-2026-04-23
>apt-pin install -y -qq curl=8.5.0-2ubuntu10.8
>@touch $@

wget-1-21-4-1ubuntu4-1: apt-index-noble-2026-04-23
>apt-pin install -y -qq wget=1.21.4-1ubuntu4.1
>@touch $@

git-e1-2-43-0-1ubuntu7-3: apt-index-noble-2026-04-23
>apt-pin install -y -qq git=1:2.43.0-1ubuntu7.3
>@touch $@

jq-1-7-1-3ubuntu0-24-04-1: apt-index-noble-2026-04-23
>apt-pin install -y -qq jq=1.7.1-3ubuntu0.24.04.1
>@touch $@

make-4-3-4-1build2: apt-index-noble-2026-04-23
>apt-pin install -y -qq make=4.3-4.1build2
>@touch $@

python3-pip-24-0-dfsg-1ubuntu1-3: apt-index-noble-2026-04-23
>apt-pin install -y -qq python3-pip=24.0+dfsg-1ubuntu1.3
>@touch $@

build-essential-12-10ubuntu1: apt-index-noble-2026-04-23
>apt-pin install -y -qq build-essential=12.10ubuntu1
>@touch $@

libssl-dev-3-0-13-0ubuntu3-9: apt-index-noble-2026-04-23
>apt-pin install -y -qq libssl-dev=3.0.13-0ubuntu3.9
>@touch $@

zlib1g-dev-e1-1-3-dfsg-3-1ubuntu2-1: apt-index-noble-2026-04-23
>apt-pin install -y -qq zlib1g-dev=1:1.3.dfsg-3.1ubuntu2.1
>@touch $@

libbz2-dev-1-0-8-5-1build0-1: apt-index-noble-2026-04-23
>apt-pin install -y -qq libbz2-dev=1.0.8-5.1build0.1
>@touch $@

libreadline-dev-8-2-4build1: apt-index-noble-2026-04-23
>apt-pin install -y -qq libreadline-dev=8.2-4build1
>@touch $@

libsqlite3-dev-3-45-1-1ubuntu2-5: apt-index-noble-2026-04-23
>apt-pin install -y -qq libsqlite3-dev=3.45.1-1ubuntu2.5
>@touch $@

libffi-dev-3-4-6-1build1: apt-index-noble-2026-04-23
>apt-pin install -y -qq libffi-dev=3.4.6-1build1
>@touch $@

liblzma-dev-5-6-1-really5-4-5-1ubuntu0-2: apt-index-noble-2026-04-23
>apt-pin install -y -qq liblzma-dev=5.6.1+really5.4.5-1ubuntu0.2
>@touch $@

python3-3-12-3-0ubuntu2-1: apt-index-noble-2026-04-23
>apt-pin install -y -qq python3=3.12.3-0ubuntu2.1
>@touch $@

# -----------------------------------------------------------------------------
# GUI desktop packages and runtime
# -----------------------------------------------------------------------------

openbox-3-6-1-12build5: apt-index-noble-2026-04-23
>apt-pin install -y -qq openbox=3.6.1-12build5
>@touch $@

# Intent: Provide a D-Bus session launcher for the Openbox service so Epiphany,
# libportal, and other desktop applications inherit a coherent user session bus
# instead of aborting or depending on fragile per-command autolaunch behavior.
# Source: DI-dobot (TODO-fogup)
dbus-x11-1-14-10-4ubuntu4-1: apt-index-noble-2026-04-23
>apt-pin install -y -qq dbus-x11=1.14.10-4ubuntu4.1
>@touch $@

x11vnc-0-9-16-10: apt-index-noble-2026-04-23
>apt-pin install -y -qq x11vnc=0.9.16-10
>@touch $@

xvfb-e2-21-1-12-1ubuntu1-5: apt-index-noble-2026-04-23
>apt-pin install -y -qq xvfb=2:21.1.12-1ubuntu1.5
>@touch $@

x11-apps-7-7-11build3: apt-index-noble-2026-04-23
>apt-pin install -y -qq x11-apps=7.7+11build3
>@touch $@

x11-utils-7-7-6build2: apt-index-noble-2026-04-23
>apt-pin install -y -qq x11-utils=7.7+6build2
>@touch $@

# Intent: Make the shared noVNC/Openbox desktop usable from inside a consumer
# repo by providing the standard Debian `x-terminal-emulator` command without
# pulling in a heavier desktop terminal stack.
# Source: DI-gipuk (TODO-fogup)
xterm-390-1ubuntu3: apt-index-noble-2026-04-23
>apt-pin install -y -qq xterm=390-1ubuntu3
>@touch $@

novnc-e1-1-3-0-2: apt-index-noble-2026-04-23
>apt-pin install -y -qq novnc=1:1.3.0-2
>@touch $@

websockify-0-10-0-dfsg1-5build2: apt-index-noble-2026-04-23
>apt-pin install -y -qq websockify=0.10.0+dfsg1-5build2
>@touch $@

epiphany-browser-46-5-0ubuntu1: apt-index-noble-2026-04-23
>apt-pin install -y -qq epiphany-browser=46.5-0ubuntu1
>@touch $@

# -----------------------------------------------------------------------------
# FPGA-specific tools
# -----------------------------------------------------------------------------

OSS-20260307: wget-1-21-4-1ubuntu4-1
>bash $(CONF_BIN_DIR)/install-oss-cad-suite.sh
>@touch $@

COCOTB-2-0-1: python3-3-12-3-0ubuntu2-1 python3-pip-24-0-dfsg-1ubuntu1-3
>bash $(CONF_BIN_DIR)/install-cocotb.sh
>@touch $@

# Intent: Keep a runtime/user-level evidence hook that appends per-user entries
# on every postCreate run without relying on stamp-skipped file targets.
# Source: DI-vusag (TODO-lusaz)
postCreateUserDemo:
>bash $(CONF_BIN_DIR)/post-create-user-demo.sh
