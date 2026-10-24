FROM ubuntu:24.04

ARG DEV_PASSWORD=dev

# ---------- locale ----------
RUN apt-get update && apt-get install -y locales \
    && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen \
    && locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ---------- system packages ----------
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    zsh git cmake ninja-build gdb clang clangd \
    openssh-server curl wget unzip ripgrep fd-find \
    build-essential python3 python3-venv \
    tmux sudo \
    fontconfig ncurses-term \
    && rm -rf /var/lib/apt/lists/*

# ---------- Node.js 22.x LTS ----------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---------- Codex CLI ----------
RUN npm install -g @openai/codex

# ---------- Pi coding agent ----------
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# ---------- Neovim (latest stable from GitHub) ----------
RUN curl -fsSL -o /tmp/nvim-linux-x86_64.tar.gz \
       "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" \
    && tar -xzf /tmp/nvim-linux-x86_64.tar.gz -C /opt \
    && ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim \
    && rm /tmp/nvim-linux-x86_64.tar.gz

# ---------- GitHub CLI ----------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# ---------- Nerd Font (JetBrainsMono) ----------
RUN mkdir -p /usr/share/fonts/nerd-fonts \
    && curl -fsSL -o /tmp/JetBrainsMono.zip \
       "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" \
    && unzip -o /tmp/JetBrainsMono.zip -d /usr/share/fonts/nerd-fonts \
    && rm /tmp/JetBrainsMono.zip \
    && fc-cache -fv

# ---------- Kitty terminfo ----------
COPY config/xterm-kitty /usr/share/terminfo/x/xterm-kitty

# ---------- Starship prompt ----------
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

# ---------- uv, ruff, ty ----------
ENV UV_INSTALL_DIR=/usr/local/bin UV_TOOL_BIN_DIR=/usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && uv tool install ruff \
    && uv tool install ty

# ---------- Claude Code ----------
RUN npm install -g @anthropic-ai/claude-code

# ---------- user setup ----------
RUN useradd -m -s /usr/bin/zsh -G sudo dev \
    && echo "dev:${DEV_PASSWORD}" | chpasswd \
    && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

# ---------- SSH server ----------
RUN mkdir -p /run/sshd /etc/ssh/host_keys \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && printf '\nHostKey /etc/ssh/host_keys/ssh_host_ed25519_key\nHostKey /etc/ssh/host_keys/ssh_host_rsa_key\n' >> /etc/ssh/sshd_config

# ---------- config skeleton (copied to volume on first boot) ----------
ARG DOTFILES_REPO=https://github.com/ywattenberg/dotfiles
RUN mkdir -p /etc/skel.dev/.config \
    && git clone ${DOTFILES_REPO} /tmp/dotfiles \
    && cp -a /tmp/dotfiles/nvim           /etc/skel.dev/.config/nvim \
    && cp -a /tmp/dotfiles/zsh            /etc/skel.dev/.config/zsh \
    && cp -a /tmp/dotfiles/tmux           /etc/skel.dev/.config/tmux \
    && cp -a /tmp/dotfiles/starship.toml  /etc/skel.dev/.config/starship.toml \
    && rm -rf /tmp/dotfiles \
    && printf '# Source config\nsource ~/.config/zsh/zshrc\n' > /etc/skel.dev/.zshrc \
    && chown -R dev:dev /etc/skel.dev
RUN [ ! -d /etc/skel.dev/.config/tmux/plugins/tpm ] \
    && git clone https://github.com/tmux-plugins/tpm /etc/skel.dev/.config/tmux/plugins/tpm \
    || true

# ---------- Pi configuration and packages ----------
COPY --chown=dev:dev config/pi/ /etc/skel.dev/.pi/agent/

ARG PI_PACKAGES="pi-subagents pi-mcp-adapter pi-web-access pi-intercom @firstpick/pi-package-webui @firstpick/pi-package-remote-webui pi-btw"
RUN mkdir -p /etc/skel.dev/.pi/agent \
    && chown -R dev:dev /etc/skel.dev/.pi \
    && for package in ${PI_PACKAGES}; do \
         sudo -u dev env HOME=/etc/skel.dev PI_CODING_AGENT_DIR=/etc/skel.dev/.pi/agent \
           pi install "npm:${package}"; \
       done

EXPOSE 22

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
