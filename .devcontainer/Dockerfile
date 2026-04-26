# This Dockerfile is intended for genesis image bootstrap only.
# Keep it minimal: install only prerequisites needed for decomk stage-0
# (`bash`, `git`, `go`, `make`, `sudo`) plus one configured non-root identity
# and writable decomk state directories.
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
      sudo=1.9.15p5-3ubuntu5.24.04.2 \
      openssh-server=1:9.6p1-3ubuntu13.15

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

# Ensure that the necessary directories are owned by this user.
RUN mkdir -p /workspaces /var/decomk /var/log/decomk \
 && chown -R ${DECOMK_REMOTE_USER}:${DECOMK_REMOTE_USER} /workspaces /var/decomk /var/log/decomk
