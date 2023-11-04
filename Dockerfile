FROM ubuntu:22.04

ARG USER

RUN echo User is: $USER

# Install packages
RUN apt update && export DEBIAN_FRONTEND=noninteractive && export TZ=America/Montreal && \
  apt install -y software-properties-common zsh python3-pip rsync bind9-dnsutils ruby-full \
                 open-vm-tools libnss-ldap libpam-ldap ldap-utils jq exuberant-ctags sudo \
                 curl golang git iftop mtr telnet wget language-pack-en language-pack-fr && \
                 iputils-ping

# Compile neovim & install nvim
RUN git clone https://github.com/neovim/neovim.git && \
  cd neovim && \
  git checkout stable && \
  make CMAKE_BUILD_TYPE=Release && \
  make install

# Install docker
RUN apt -y install curl
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt update
RUN apt -y install docker-ce-cli
RUN groupadd -g 998 docker

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
RUN useradd -rm -d /home/$USER -s /usr/bin/zsh -G docker -u 1000 -p "$(openssl passwd -1 ubuntu)" $USER
RUN groupmod -g 1000 $USER
RUN chown -R $USER: /home/$USER
RUN gpasswd -a $USER sudo

# Install node and npm
RUN curl -sL https://deb.nodesource.com/setup_17.x -o nodesource_setup.sh && \
  bash nodesource_setup.sh && \
  apt install nodejs && \
  apt install build-essential && \
  npm i -g bash-language-server && \
  npm install -g yarn

# Install tmux
RUN apt update && apt install -y git automake build-essential pkg-config \
                                      libevent-dev libncurses5-dev byacc bison zsh
RUN rm -fr /tmp/tmux && \
  git clone https://github.com/tmux/tmux.git /tmp/tmux
WORKDIR /tmp/tmux
RUN git checkout 3.0
RUN sh autogen.sh
RUN ./configure && make
RUN make install
WORKDIR /home/$USER
RUN rm -fr /tmp/tmux

# Install tmuxinator
RUN gem install tmuxinator

RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ludorl82/.shell-scripts/master/scripts/install_ssh.sh)"

# Install OpenSSH server
RUN mkdir /run/sshd
RUN ssh-keygen -A

RUN apt-get update && apt-get install -y apt-transport-https && \
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | \
  tee -a /etc/apt/sources.list.d/kubernetes.list
RUN apt-get update && \
  apt-get install -y kubectl

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip

RUN ./aws/install

RUN rm -f awscliv2.zip
RUN rm -rf aws

CMD ["/usr/sbin/sshd", "-D", "-o", "ListenAddress=0.0.0.0"]
