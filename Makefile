SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c

TOOLS:
	apt-get update -qq
	apt-get install -y -qq curl wget git jq make python3-pip
	touch $@

OSS: TOOLS
	if [ -x "/opt/oss-cad-suite/bin/iverilog" ]; then \
	  echo "oss-cad-suite already installed, skipping"; \
	else \
	  wget -q "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-03-07/oss-cad-suite-linux-x64-20260307.tgz" -O /tmp/oss-cad-suite.tgz; \
	  mkdir -p /opt; \
	  tar xzf /tmp/oss-cad-suite.tgz -C /opt; \
	  rm -f /tmp/oss-cad-suite.tgz; \
	fi
	echo 'export PATH="/opt/oss-cad-suite/bin:$$PATH"' > /etc/profile.d/oss-cad-suite.sh
	touch $@

I2C: TOOLS
	if [ ! -d "/workspaces/i2cslave" ]; then \
	  git clone https://github.com/AdrianSuliga/I2C-Slave-Controller.git /workspaces/i2cslave 2>/dev/null || \
	    echo "WARNING: Could not clone I2C reference"; \
	fi
	touch $@

COCOTB: TOOLS
	if python3 -c "import cocotb" >/dev/null 2>&1; then \
	  echo "cocotb already installed, skipping"; \
	else \
	  pip install cocotb==2.0.1 cocotb-bus==0.3.0 --break-system-packages; \
	fi
	touch $@
