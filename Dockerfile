FROM ubuntu:24.04

ARG USER
ARG TARGETARCH

RUN echo User is: $USER
RUN echo Target Architecture is: $TARGETARCH

# Install packages
RUN apt update && export DEBIAN_FRONTEND=noninteractive && export TZ=America/Montreal && \
  apt install -y software-properties-common zsh python3-pip rsync bind9-dnsutils ruby-full \
                 jq exuberant-ctags sudo \
                 curl golang git iftop mtr telnet wget language-pack-en language-pack-fr \
                 iputils-ping xclip tzdata

# Compile neovim & install nvim (requires 0.10.0+ for CopilotChat)
RUN apt install -y build-essential cmake gettext ninja-build unzip
RUN git clone https://github.com/neovim/neovim.git && \
  cd neovim && \
  git checkout stable && \
  make CMAKE_BUILD_TYPE=Release && \
  make install && \
  cd .. && \
  rm -rf neovim

# Install docker
RUN apt -y install curl
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt update
RUN apt -y install docker-ce-cli

# Ensure docker group exists (docker-ce-cli should create it)
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

# Remove default ubuntu user if it exists (Ubuntu 24.04 cloud images create this)
RUN userdel -r ubuntu 2>/dev/null || true

# Create user
RUN useradd -rm -d /home/$USER -s /usr/bin/zsh -G docker -u 1000 -p "$(openssl passwd -1 ubuntu)" $USER
RUN groupmod -g 1000 $USER
RUN chown -R $USER: /home/$USER
RUN gpasswd -a $USER sudo

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
RUN apt update && apt install -y tmux

# Install tmuxinator
RUN apt install tmuxinator -y

RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ludorl82/.shell-scripts/master/scripts/install_ssh.sh)"

# Install OpenSSH server
RUN mkdir /run/sshd
RUN ssh-keygen -A

# Install kubectl using new repository format
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates curl gnupg && \
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list && \
  apt-get update && \
  apt-get install -y kubectl

# Install AWS CLI with architecture detection
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "arm64" ]; then \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
  else \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
  fi && \
  unzip awscliv2.zip && \
  ./aws/install && \
  rm -f awscliv2.zip && \
  rm -rf aws

CMD ["/usr/sbin/sshd", "-D", "-o", "ListenAddress=0.0.0.0"]
