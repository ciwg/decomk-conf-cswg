# This Dockerfile is intended for genesis image bootstrap only.
# Keep it minimal: install only prerequisites needed for decomk stage-0
# (`bash`, `git`, `go`, `make`, `sudo`) and writable decomk state directories.
#
# After your genesis image is stable, stop using this Dockerfile and switch
# `.devcontainer/devcontainer.json` to an `image:` stanza that points at your
# stable channel tag (for example `ghcr.io/<org>/<repo>:stable`).

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      bash=5.2.21-2ubuntu4 \
      ca-certificates=20240203 \
      git=1:2.43.0-1ubuntu7.3 \
      golang-go=2:1.22~2build1 \
      make=4.3-4.1build2 \
      sudo=1.9.15p5-3ubuntu5.24.04.2 \
      openssh-server=1:9.6p1-3ubuntu13.15

RUN mkdir -p /var/decomk /var/log/decomk \
 && chown -R vscode:vscode /var/decomk /var/log/decomk
