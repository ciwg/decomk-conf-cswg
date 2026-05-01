# This Dockerfile is intended for genesis image bootstrap only.
# Keep it minimal: install only prerequisites needed for decomk stage-0
# (`bash`, `git`, `go`, `make`, `sudo`), the runit supervisor substrate,
# plus one configured non-root identity and writable decomk state directories.
#
# After your genesis image is stable, stop using this Dockerfile and switch
# `.devcontainer/devcontainer.json` to an `image:` stanza that points at your
# stable channel tag (for example `ghcr.io/<org>/<repo>:stable`).

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Package install names and version pinning vary across distro families. Keep
# this list aligned with your chosen base image and mirror/retention policy,
# and pin versions where your platform policy requires deterministic builds.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      bash=5.2.21-2ubuntu4 \
      ca-certificates=20240203 \
      git=1:2.43.0-1ubuntu7.3 \
      golang-go=2:1.22~2build1 \
      make=4.3-4.1build2 \
      runit=2.1.2-59ubuntu1 \
      sudo=1.9.15p5-3ubuntu5.24.04.2 \
      openssh-server=1:9.6p1-3ubuntu13.16

# Intent: Keep local producer-image bootstrap reproducible as Ubuntu noble
# security updates advance without changing the producer image's minimal,
# GUI-neutral bootstrap contract.
# Source: DI-004-20260430-194224 (TODO/004)

#
# Intent: Before changing identity values, inspect the base image identities first.
# Example: docker run --rm -it mcr.microsoft.com/devcontainers/base:ubuntu-24.04 cat /etc/passwd
# Source: DI-001-20260425-113454 (decomk/TODO/001)
#
# stevegt: The above base image already includes a non-root user named
# `vscode` with UID 1000, so we can skip the useradd step. 
#
# RUN useradd --create-home --shell /bin/bash --uid 1000 vscode \
#  && echo 'vscode ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vscode \
# && chmod 0440 /etc/sudoers.d/vscode

# stevegt: We do need these environment variables for decomk to know
# which user to use when running commands in the container, but we
# don't need to create the user since it already exists in the base
# image.
ENV DECOMK_REMOTE_USER=vscode
ENV DECOMK_REMOTE_UID=1000
ENV DECOMK_HOME=/var/decomk
ENV DECOMK_LOG_DIR=/var/log/decomk
ENV RUNIT_SV_DIR=/etc/sv
ENV RUNIT_SERVICE_DIR=/etc/service
ENV RUNIT_LOG_DIR=/var/log/runit

# Intent: Keep decomk state and runit system paths in image-owned environment
# variables so later stages consume one path contract instead of re-declaring
# literals in multiple files.
# Source: DI-004-20260501-182529 (TODO/004)
RUN mkdir -p ${RUNIT_SV_DIR} ${RUNIT_SERVICE_DIR} ${RUNIT_LOG_DIR} /workspaces ${DECOMK_HOME} ${DECOMK_LOG_DIR} \
 && chown -R ${DECOMK_REMOTE_USER}:${DECOMK_REMOTE_USER} /workspaces ${DECOMK_HOME} ${DECOMK_LOG_DIR}

# Intent: Run runit as the image's long-lived PID 1 contract so consumer repos
# inherit a stable supervisor substrate while decomk later populates /etc/service
# contextually.
# Source: DI-004-20260430-182956 (TODO/004)
ENTRYPOINT ["/usr/bin/runsvdir", "-P", "/etc/service"]
