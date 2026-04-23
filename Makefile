SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c
.RECIPEPREFIX := >

# decomk expands tuples from decomk.conf, then runs make in a stamp directory
# (`DECOMK_STAMPDIR`), not in this repo root.
#
# Intent: Keep shared setup in checkpointable Block* targets and keep repo-specific
# targets separate so context tuples can compose baseline vs special behavior.
# Source: DI-002-20260423-182418 (TODO/002)

CONF_BIN_DIR := $(DECOMK_HOME)/conf/bin
DEVCONTAINER_GUI ?= 0
DECOMK_STAGE0_PHASE ?= postCreate

.PHONY: all updateContent postCreate postCreateUserDemo

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

# Block00 would normally be the build for a baseline custom image at
# GHCR -- for now we're just using a hello demo as a placeholder
Block00: hello-demo

# Intent: Keep pinned apt packages in one-stanza-per-version targets so
# version history is append-only and each upgrade is an additive Block10 prereq.
# Source: DI-002-20260423-184207 (TODO/002)
Block10: Block00 \
  vim_2_9_1_0016_1ubuntu7_11 \
  neovim_0_9_5_6ubuntu2 \
  openssh_client_e1_9_6p1_3ubuntu13_15 \
  curl_8_5_0_2ubuntu10_8 \
  wget_1_21_4_1ubuntu4_1 \
  git_e1_2_43_0_1ubuntu7_3 \
  jq_1_7_1_3ubuntu0_24_04_1 \
  make_4_3_4_1build2 \
  python3_pip_24_0_dfsg_1ubuntu1_3 \
  build_essential_12_10ubuntu1 \
  libssl_dev_3_0_13_0ubuntu3_9 \
  zlib1g_dev_e1_1_3_dfsg_3_1ubuntu2_1 \
  libbz2_dev_1_0_8_5_1build0_1 \
  libreadline_dev_8_2_4build1 \
  libsqlite3_dev_3_45_1_1ubuntu2_5 \
  libffi_dev_3_4_6_1build1 \
  liblzma_dev_5_6_1_really5_4_5_1ubuntu0_2 \
  golang_go_e2_1_22_2build1 \
  python3_3_12_3_0ubuntu1

# -----------------------------------------------------------------------------
# Repo-special feature targets
# -----------------------------------------------------------------------------

FPGA: OSS I2C COCOTB

# XXX replace this with an actual GUI desktop config
GUIDesktop:
>@if [[ "$(DEVCONTAINER_GUI)" == "1" ]]; then \
>  echo "GUI desktop mode enabled by tuple/env policy"; \
>else \
>  echo "GUIDesktop target requested with DEVCONTAINER_GUI=$(DEVCONTAINER_GUI)"; \
>fi

hello-demo:
>bash $(CONF_BIN_DIR)/hello-world.sh "hello-common" "$(HELLO_TEXT)" "$(DECOMK_STAGE0_PHASE)" "$(DEVCONTAINER_GUI)"
>@touch $@

# -----------------------------------------------------------------------------
# Base tools and language runtimes
# -----------------------------------------------------------------------------
# Versions pinned to Ubuntu 24.04 (noble) as of the base image
# mcr.microsoft.com/devcontainers/base:ubuntu-24.04

apt_index_noble_2026_04_23:
>apt-get update -qq
>@touch $@

vim_2_9_1_0016_1ubuntu7_11: apt_index_noble_2026_04_23
>apt-get install -y -qq vim=2:9.1.0016-1ubuntu7.11
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

python3_3_12_3_0ubuntu1: apt_index_noble_2026_04_23
>apt-get install -y -qq python3=3.12.3-0ubuntu1
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

COCOTB: python3_3_12_3_0ubuntu1 python3_pip_24_0_dfsg_1ubuntu1_3
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
