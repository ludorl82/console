#!/bin/bash
set -euo pipefail

# Set the account password from a runtime env var (not a build arg), so it
# never ends up baked into the image's build history. If PASS isn't
# supplied, the account keeps whatever password it already has (empty on
# first boot) -- fine since SSH here is key-only.
if [ -n "${PASS:-}" ]; then
    echo "${CONSOLE_USER}:${PASS}" | chpasswd
fi

exec "$@"
