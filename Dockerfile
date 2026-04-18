FROM ubuntu:24.04

ARG TARGETOS
ARG TARGETARCH

ENV LANG="C.UTF-8"
ENV DEBIAN_FRONTEND=noninteractive

# Install sudo and create developer user with sudo privileges
RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo \
    && sudo rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash developer \
    && echo "developer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer \
    && chmod 440 /etc/sudoers.d/developer

ENV HOME=/home/developer
USER developer

### BASE###

RUN sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends \
        binutils \
        sudo \
        build-essential \
        curl \
        default-libmysqlclient-dev \
        dnsutils \
        fd-find \
        gettext \
        git \
        git-lfs \
        gnupg \
        inotify-tools \
        iputils-ping \
        jq \
        libbz2-dev \
        libc6 \
        libc6-dev \
        libcurl4-openssl-dev \
        libdb-dev \
        libedit2 \
        libffi-dev \
        libgcc-13-dev \
        libgssapi-krb5-2 \
        liblzma-dev \
        libncurses-dev \
        libnss3-dev \
        libpq-dev \
        libpsl-dev \
        libpython3.12-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        libstdc++-13-dev \
        libunwind8 \
        libuuid1 \
        libxml2-dev \
        libz3-dev \
        make \
        moreutils \
        netcat-openbsd \
        openssh-client \
        pkg-config \
        protobuf-compiler \
        ripgrep \
        rsync \
        software-properties-common \
        sqlite3 \
        swig3.0 \
        tk-dev \
        tzdata \
        universal-ctags \
        unixodbc-dev \
        unzip \
        uuid-dev \
        wget \
        xz-utils \
        zip \
        zlib1g \
        zlib1g-dev \
    && sudo rm -rf /var/lib/apt/lists/*

### MISE ###

RUN sudo install -dm 0755 /etc/apt/keyrings \
    && curl -fsSL https://mise.jdx.dev/gpg-key.pub | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg \
    && sudo chmod 0644 /etc/apt/keyrings/mise-archive-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list \
    && sudo apt-get update \
    && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends mise/stable \
    && sudo rm -rf /var/lib/apt/lists/* \
    && echo 'eval "$(mise activate bash)"' | sudo tee -a /etc/profile \
    && mise settings set experimental true \
    && mise settings set override_tool_versions_filenames none \
    && mise settings add idiomatic_version_file_enable_tools "[]"

# Fix: Put real tool paths BEFORE mise shims to avoid PTY hanging issue
# Mise binary shims can hang in PTY environments (e.g., xterm.js web terminals)
ENV PATH=$HOME/.local/share/mise/installs/java/21/bin:$HOME/.local/share/mise/installs/java/17/bin:$HOME/.local/bin:$PATH
ENV PATH=$HOME/.local/share/mise/shims:$PATH

### PYTHON ###

ARG PYENV_VERSION=v2.6.10
ARG PYTHON_VERSIONS="3.11.12 3.10 3.12 3.13 3.14.0"

# Install pyenv
ENV PYENV_ROOT=$HOME/.pyenv
ENV PATH=$PYENV_ROOT/bin:$PATH
RUN git -c advice.detachedHead=0 clone --branch "$PYENV_VERSION" --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT" \
    && echo 'export PYENV_ROOT="$HOME/.pyenv"' | sudo tee -a /etc/profile \
    && echo 'export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"' | sudo tee -a /etc/profile \
    && echo 'if [ -f "$PYENV_ROOT/bin/pyenv" ]; then eval "$(pyenv init - bash)"; fi' | sudo tee -a /etc/profile \
    && cd "$PYENV_ROOT" \
    && src/configure \
    && make -C src \
    && pyenv install $PYTHON_VERSIONS \
    && pyenv global "${PYTHON_VERSIONS%% *}" \
    && rm -rf "$PYENV_ROOT/cache"

# Install pipx for common global package managers (e.g. poetry)
ENV PIPX_BIN_DIR=$HOME/.local/bin
ENV PATH=$PIPX_BIN_DIR:$PATH
RUN sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends pipx \
    && sudo rm -rf /var/lib/apt/lists/* \
    && pipx install --pip-args="--no-cache-dir --no-compile" poetry==2.1.* uv==0.7.* \
    && for pyv in "${PYENV_ROOT}/versions/"*; do \
         "$pyv/bin/python" -m pip install --no-cache-dir --no-compile --upgrade pip && \
         "$pyv/bin/pip" install --no-cache-dir --no-compile ruff black mypy pyright isort pytest; \
       done \
    && rm -rf "$HOME/.cache/pip" "$HOME/.cache/pipx"

# Reduce the verbosity of uv - impacts performance of stdout buffering
ENV UV_NO_PROGRESS=1

### NODE ###

ARG NVM_VERSION=v0.40.2
ARG NODE_VERSION=22

ENV NVM_DIR=$HOME/.nvm
# Corepack tries to do too much - disable some of its features:
# https://github.com/nodejs/corepack/blob/main/README.md
ENV COREPACK_DEFAULT_TO_LATEST=0
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
ENV COREPACK_ENABLE_AUTO_PIN=0
ENV COREPACK_ENABLE_STRICT=0

RUN git -c advice.detachedHead=0 clone --branch "$NVM_VERSION" --depth 1 https://github.com/nvm-sh/nvm.git "$NVM_DIR" \
    && echo '[ -f "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"' | sudo tee -a /etc/profile \
    && echo "prettier\neslint\ntypescript" > $NVM_DIR/default-packages \
    && . $NVM_DIR/nvm.sh \
    # The latest versions of npm aren't supported on node 18, so we install each set differently
    && nvm install 18 && nvm use 18 && npm install -g npm@10.9 pnpm@10.12 && corepack enable && corepack install -g yarn \
    && nvm install 20 && nvm use 20 && npm install -g npm@11.4 pnpm@10.12 && corepack enable && corepack install -g yarn \
    && nvm install 22 && nvm use 22 && npm install -g npm@11.4 pnpm@10.12 && corepack enable && corepack install -g yarn \
    && nvm install 24 && nvm use 24 && npm install -g npm@11.4 pnpm@10.12 && corepack enable && corepack install -g yarn \
    && nvm alias default "$NODE_VERSION" \
    && nvm cache clear \
    && npm cache clean --force || true \
    && pnpm store prune || true \
    && yarn cache clean || true

### JAVA ###

ARG GRADLE_VERSION=8.14
ARG MAVEN_VERSION=3.9.10
# OpenJDK 11 is not available for arm64. Codex Web only uses amd64 which
# does support 11.
ARG AMD_JAVA_VERSIONS="21 17 11 8"
ARG ARM_JAVA_VERSIONS="21 17 8"

RUN JAVA_VERSIONS="$( [ "$TARGETARCH" = "arm64" ] && echo "21 17" || echo "21 17 11" )" \
    && for v in $JAVA_VERSIONS; do mise install "java@${v}"; done \
    && mise use --global "java@${JAVA_VERSIONS%% *}" \
    && mise use --global "gradle@${GRADLE_VERSION}" \
    && mise use --global "maven@${MAVEN_VERSION}" \
    && mise cache clear || true \
    && rm -rf "$HOME/.cache/mise" "$HOME/.local/share/mise/downloads"
# Install Java 8 via apt for amd64 only (mise doesn't support Java 8)
RUN if [ "$TARGETARCH" != "arm64" ]; then \
        sudo apt-get update && \
        if apt-cache show openjdk-8-jdk >/dev/null 2>&1; then \
            sudo apt-get install -y --no-install-recommends openjdk-8-jdk && \
            sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-8-openjdk-amd64/bin/java 1 && \
            sudo update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac 1; \
        else \
            echo "openjdk-8-jdk not available on this base image, skipping"; \
        fi && \
        sudo rm -rf /var/lib/apt/lists/*; \
    fi

### SETUP SCRIPTS ###

COPY setup_universal.sh /opt/codex/setup_universal.sh
RUN sudo chmod +x /opt/codex/setup_universal.sh

### VERIFICATION SCRIPT ###

COPY verify.sh /opt/verify.sh
RUN sudo sed -i 's/\r$//' /opt/verify.sh && sudo chmod +x /opt/verify.sh && bash -c "source $HOME/.nvm/nvm.sh && eval \"\$(pyenv init -)\" && eval \"\$(mise activate bash)\" && /opt/verify.sh"

### ENTRYPOINT ###

COPY entrypoint.sh /opt/entrypoint.sh
RUN sudo chmod +x /opt/entrypoint.sh

ENTRYPOINT  ["/opt/entrypoint.sh"]
