FROM ubuntu:24.04

# Install packages
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && export TZ=America/Montreal && \
  apt-get install -y software-properties-common zsh python3-pip rsync bind9-dnsutils ruby-full \
                 jq exuberant-ctags sudo curl language-pack-en language-pack-fr iputils-ping xclip \
                 curl golang git iftop mtr telnet wget tzdata

# Compile neovim & install nvim
RUN apt-get install -y build-essential cmake gettext ninja-build unzip
RUN git clone https://github.com/neovim/neovim.git && \
  cd neovim && \
  git checkout stable && \
  make CMAKE_BUILD_TYPE=Release && \
  make install && \
  cd .. && \
  rm -rf neovim

# Install docker
RUN apt-get -y install docker.io

# Ensure docker group exists
RUN getent group docker || groupadd docker

# Set timezone
RUN rm -rf /etc/localtime
RUN ln -s /usr/share/zoneinfo/America/Montreal /etc/localtime

# Set locale
RUN locale-gen en_US
RUN locale-gen en_US.UTF-8
RUN locale-gen fr_FR
RUN locale-gen fr_FR.UTF-8
RUN update-locale LANG=fr_FR.UTF-8

# Create user
RUN useradd -rm -d /home/ubuntu -s /usr/bin/zsh -G docker -u 1000 -p "$(openssl passwd -1 ubuntu)" ubuntu
RUN groupmod -g 1000 ubuntu
RUN chown -R ubuntu: /home/ubuntu
RUN gpasswd -a ubuntu sudo

# Install node and npm (version 22)
RUN set -uex; \
    apt-get update; \
    apt-get install -y ca-certificates curl gnupg; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
     | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    NODE_MAJOR=22; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" \
     > /etc/apt/sources.list.d/nodesource.list; \
    apt-get -qy update; \
    apt-get -qy install nodejs;
RUN npm i -g bash-language-server && \
  npm install -g yarn

# Install tmux from Ubuntu repository (Ubuntu 24.04 has tmux 3.4)
RUN apt-get update && apt-get install -y tmux

# Install tmuxinator
RUN apt-get install tmuxinator -y

RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ludorl82/.shell-scripts/master/scripts/install_ssh.sh)"

# Install OpenSSH server
RUN mkdir /run/sshd
RUN ssh-keygen -A

CMD ["/usr/sbin/sshd", "-D", "-o", "ListenAddress=0.0.0.0"]
