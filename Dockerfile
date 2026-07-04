FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=America/Montreal
ARG USER=ubuntu
ARG UID=1000
ARG GID=1000

# Base setup: packages, timezone, locale
# apt-get upgrade here (not just install) so already-present base-image
# packages pick up any security fixes published since ubuntu:24.04 was
# last built, not just the packages we explicitly add below.
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
      software-properties-common zsh python3-pip rsync bind9-dnsutils ruby-full \
      jq exuberant-ctags sudo curl language-pack-en language-pack-fr iputils-ping xclip \
      golang git iftop mtr telnet wget tzdata ca-certificates gnupg; \
    ln -fs /usr/share/zoneinfo/"$TZ" /etc/localtime; \
    echo "$TZ" > /etc/timezone; \
    dpkg-reconfigure -f noninteractive tzdata; \
    locale-gen en_US en_US.UTF-8 fr_FR fr_FR.UTF-8; \
    update-locale LANG=fr_FR.UTF-8; \
    rm -rf /var/lib/apt/lists/*

# Neovim: install the official prebuilt release tarball (arch-aware) instead
# of compiling from source -- avoids a lengthy build-essential/cmake/ninja
# compile on every image rebuild, especially costly for linux/arm64 under
# QEMU emulation in the weekly no-cache scheduled rebuild.
RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    case "$ARCH" in \
      amd64) NVIM_ARCH=x86_64 ;; \
      arm64) NVIM_ARCH=arm64 ;; \
      *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" -o /tmp/nvim.tar.gz; \
    mkdir -p /opt/nvim; \
    tar -xzf /tmp/nvim.tar.gz -C /opt/nvim --strip-components=1; \
    ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim; \
    rm -f /tmp/nvim.tar.gz

# Docker engine (from Ubuntu repo)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends docker.io; \
    rm -rf /var/lib/apt/lists/*

# Ensure docker group exists
RUN set -eux; \
    getent group docker || groupadd docker

# Create or modify user and group
# - Create group with GID if missing
# - Create user if missing; otherwise modify existing
# - Set shell, home, UID/GID, add to docker & sudo, set password
RUN set -eux; \
    if ! getent group "$USER" >/dev/null; then groupadd -g "$GID" "$USER"; fi; \
    if getent passwd "$USER" >/dev/null; then \
      usermod -d /home/"$USER" -s /usr/bin/zsh -u "$UID" -g "$GID" -a -G docker,sudo "$USER"; \
    else \
      useradd -m -d /home/"$USER" -s /usr/bin/zsh -u "$UID" -g "$GID" -G docker,sudo "$USER"; \
    fi; \
    mkdir -p /home/"$USER"; \
    chown -R "$USER":"$USER" /home/"$USER"

# Retain USER at runtime (ARGs aren't available in the running container) so
# entrypoint.sh knows which account to set the password for.
ENV CONSOLE_USER=${USER}

# Node.js 22.x (Nodesource)
RUN set -eux; \
    apt-get update; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list; \
    apt-get -qy update; \
    apt-get -qy install --no-install-recommends nodejs; \
    rm -rf /var/lib/apt/lists/*

# Global npm tools
RUN set -eux; \
    npm i -g bash-language-server yarn

# tmux and tmuxinator
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends tmux tmuxinator; \
    rm -rf /var/lib/apt/lists/*

# Optional: install SSH helper script (external)
# Consider pinning or verifying this script before running in production
#
# Downloaded to a real file (not piped into `bash -c`) because install_ssh.sh
# sources a sibling script via `dirname "${BASH_SOURCE[0]}"`, which requires
# an actual file path to resolve.
RUN set -eux; \
    mkdir -p /tmp/shell-scripts; \
    curl -fsSL -o /tmp/shell-scripts/install_ssh.sh https://raw.githubusercontent.com/ludorl82/.shell-scripts/master/scripts/install_ssh.sh; \
    curl -fsSL -o /tmp/shell-scripts/upgrade_shell_functions.sh https://raw.githubusercontent.com/ludorl82/.shell-scripts/master/scripts/upgrade_shell_functions.sh; \
    bash /tmp/shell-scripts/install_ssh.sh; \
    rm -rf /tmp/shell-scripts

# OpenSSH server setup
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends openssh-server; \
    mkdir -p /run/sshd; \
    ssh-keygen -A; \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command
CMD ["/usr/sbin/sshd", "-D", "-o", "ListenAddress=0.0.0.0"]
