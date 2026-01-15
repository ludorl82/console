FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=America/Montreal
ARG USER=ubuntu
ARG PASS=ubuntu
ARG UID=1000
ARG GID=1000

# Base setup: packages, timezone, locale
RUN set -eux; \
    apt-get update; \
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

# Build dependencies for Neovim, then compile and install
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends build-essential cmake gettext ninja-build unzip git; \
    git clone https://github.com/neovim/neovim.git; \
    cd neovim; \
    git checkout stable; \
    make CMAKE_BUILD_TYPE=Release; \
    make install; \
    cd ..; \
    rm -rf neovim; \
    apt-get purge -y build-essential cmake gettext ninja-build unzip; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*

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
    chown -R "$USER":"$USER" /home/"$USER"; \
    echo "$USER:$PASS" | chpasswd

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
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ludorl82/.shell-scripts/master/scripts/install_ssh.sh)"

# OpenSSH server setup
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends openssh-server; \
    mkdir -p /run/sshd; \
    ssh-keygen -A; \
    rm -rf /var/lib/apt/lists/*

# Default command
CMD ["/usr/sbin/sshd", "-D", "-o", "ListenAddress=0.0.0.0"]
