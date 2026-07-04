#!/bin/bash
set -euo pipefail

# Set the account password from a runtime env var (not a build arg), so it
# never ends up baked into the image's build history. If PASS isn't
# supplied, the account keeps whatever password it already has (empty on
# first boot) -- fine since SSH here is key-only.
if [ -n "${PASS:-}" ]; then
    echo "${CONSOLE_USER}:${PASS}" | chpasswd
fi

# docker-init.sh (installed by the docker-outside-of-docker devcontainer
# Feature) reconciles the container's docker group GID with the mounted
# host socket's actual GID before exec-ing into "$@" itself. Only present
# when the image was built via the devcontainer CLI (see Dockerfile).
if [ -x /usr/local/share/docker-init.sh ]; then
    exec /usr/local/share/docker-init.sh "$@"
else
    exec "$@"
fi
