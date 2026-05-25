# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-ubuntu:noble

# set version label
ARG BUILD_DATE
ARG VERSION="v1.2.0-codex"
ARG CODE_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"
LABEL org.label-schema.build="codex-branch"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV HOME="/config"

# env args from .env (Coolify passes these in)
ARG GITHUB_TOKEN
ARG LLM_MODEL
ARG MINIMAX_ANTHROPIC_BASE_URL
ARG MINIMAX_OPENAI_BASE_URL
ARG MINIMAX_API_KEY
ARG ANTHROPIC_API_KEY
ARG MATTERMOST_URL
ARG MATTERMOST_TOKEN
ARG MATTERMOST_ALLOWED_USERS
ARG MATTERMOST_REPLY_MODE
ARG MATTERMOST_REQUIRE_MENTION
ARG COOLIFY_API_KEY
ARG COOLIFY_URL

# map all env vars
ENV GITHUB_TOKEN=${GITHUB_TOKEN}
ENV LLM_MODEL=${LLM_MODEL}
ENV MINIMAX_ANTHROPIC_BASE_URL=${MINIMAX_ANTHROPIC_BASE_URL}
ENV MINIMAX_OPENAI_BASE_URL=${MINIMAX_OPENAI_BASE_URL}
ENV MINIMAX_API_KEY=${MINIMAX_API_KEY}
ENV ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
ENV MATTERMOST_URL=${MATTERMOST_URL}
ENV MATTERMOST_TOKEN=${MATTERMOST_TOKEN}
ENV MATTERMOST_ALLOWED_USERS=${MATTERMOST_ALLOWED_USERS}
ENV MATTERMOST_REPLY_MODE=${MATTERMOST_REPLY_MODE}
ENV MATTERMOST_REQUIRE_MENTION=${MATTERMOST_REQUIRE_MENTION}
ENV COOLIFY_API_KEY=${COOLIFY_API_KEY}
ENV COOLIFY_URL=${COOLIFY_URL}

RUN \
  echo "**** install runtime dependencies ****" && \
  apt-get update && \
  apt-get install -y \
    git \
    libatomic1 \
    nano \
    net-tools \
    sudo \
    sqlite3 \
    python3 && \
  echo "**** install code-server ****" && \
  if [ -z ${CODE_RELEASE+x} ]; then \
    CODE_RELEASE=$(curl -sX GET https://api.github.com/repos/coder/code-server/releases/latest \
      | awk '/tag_name/{print $4;exit}' FS='[""]' | sed 's|^v||'); \
  fi && \
  mkdir -p /app/code-server && \
  curl -o \
    /tmp/code-server.tar.gz -L \
    "https://github.com/coder/code-server/releases/download/v${CODE_RELEASE}/code-server-${CODE_RELEASE}-linux-amd64.tar.gz" && \
  tar xf /tmp/code-server.tar.gz -C \
    /app/code-server --strip-components=1 && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** clean up ****" && \
  apt-get clean && \
  rm -rf \
    /config/* \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# copy local files (includes agents-manager at root/config/agents-manager)
COPY /root /

# create aatos user with passwordless sudo (UID 911 for code-server compatibility)
RUN if ! id "aatos" &>/dev/null; then \
      useradd -m -u 911 -g abc -s /bin/bash aatos; \
    fi && \
    echo "aatos ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/aatos && \
    chmod 440 /etc/sudoers.d/aatos && \
    echo "root ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/root && \
    chmod 440 /etc/sudoers.d/root

# install claude for root
RUN curl -fsSL https://claude.ai/install.sh | bash

# write root settings.json via heredoc (python3 installed after dependencies)
RUN cat > /tmp/write_settings.py << 'PYEOF'
import os, json
settings = {
  "skipDangerousModePermissionPrompt": True,
  "env": {
    "ANTHROPIC_BASE_URL": os.environ.get("MINIMAX_ANTHROPIC_BASE_URL", ""),
    "ANTHROPIC_MODEL": os.environ.get("LLM_MODEL", ""),
    "ANTHROPIC_DEFAULT_SONNET_MODEL": os.environ.get("LLM_MODEL", ""),
    "ANTHROPIC_DEFAULT_OPUS_MODEL": os.environ.get("LLM_MODEL", ""),
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": os.environ.get("LLM_MODEL", ""),
    "CLAUDE_CODE_SUBAGENT_MODEL": os.environ.get("LLM_MODEL", ""),
    "ANTHROPIC_AUTH_TOKEN": os.environ.get("ANTHROPIC_API_KEY", ""),
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "10",
    "teammateMode": "tmux"
  },
  "dangerouslyAlwaysAllow": True,
  "allow": ["Edit", "Write", "Bash", "Read", "Glob", "Grep", "WebFetch", "WebSearch", "TodoRead", "TodoWrite"]
}
os.makedirs("/root/.claude/settings", exist_ok=True)
with open("/root/.claude/settings.json", "w") as f:
    json.dump(settings, f, indent=2)
PYEOF
RUN python3 /tmp/write_settings.py && rm /tmp/write_settings.py

# add PATH to root bashrc
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /root/.bashrc

# create .claude.json for root (skip onboarding)
RUN echo '{"hasCompletedOnboarding": true}' > /root/.claude.json

# install claude for aatos
RUN su - aatos -c "curl -fsSL https://claude.ai/install.sh | bash"

# write user settings.json via heredoc
RUN cat > /tmp/write_user_settings.py << 'PYEOF'
import os, json
settings = {
  "skipDangerousModePermissionPrompt": True,
  "env": {
    "ANTHROPIC_BASE_URL": os.environ.get("MINIMAX_ANTHROPIC_BASE_URL", ""),
    "ANTHROPIC_MODEL": os.environ.get("LLM_MODEL", ""),
    "ANTHROPIC_DEFAULT_SONNET_MODEL": os.environ.get("LLM_MODEL", ""),
    "ANTHROPIC_DEFAULT_OPUS_MODEL": os.environ.get("LLM_MODEL", ""),
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": os.environ.get("LLM_MODEL", ""),
    "CLAUDE_CODE_SUBAGENT_MODEL": os.environ.get("LLM_MODEL", ""),
    "ANTHROPIC_AUTH_TOKEN": os.environ.get("ANTHROPIC_API_KEY", ""),
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "10",
    "teammateMode": "tmux"
  },
  "dangerouslyAlwaysAllow": True,
  "allow": ["Edit", "Write", "Bash", "Read", "Glob", "Grep", "WebFetch", "WebSearch", "TodoRead", "TodoWrite"]
}
os.makedirs(os.path.expanduser("~/.claude/settings"), exist_ok=True)
with open(os.path.expanduser("~/.claude/settings.json"), "w") as f:
    json.dump(settings, f, indent=2)
PYEOF
RUN su - aatos -c "python3 /tmp/write_user_settings.py" && rm /tmp/write_user_settings.py

# configure VSCode settings for code-server (uses HOME=/config)
# code-server on Linux stores settings at ~/.config/code-server/User/settings.json
RUN mkdir -p /config/.config/code-server/User && \
    chown -R abc:abc /config/.config && \
    cat > /config/.config/code-server/User/settings.json << 'VSCODESETTINGS_EOF'
{
  "workbench.colorTheme": "Default Dark Modern",
  "window.menuBarVisibility": "classic",
  "security.workspace.trust.enabled": false,
  "github.copilot.chat.enabled": false,
  "chat.location": "panel",
  "workbench.panel.defaultChatView": "cline"
}
VSCODESETTINGS_EOF

# also create .local/share as fallback (some versions use this)
RUN mkdir -p /config/.local/share/code-server/User && \
    chown -R abc:abc /config/.local && \
    cat > /config/.local/share/code-server/User/settings.json << 'VSCODESETTINGS_EOF'
{
  "workbench.colorTheme": "Default Dark Modern",
  "window.menuBarVisibility": "classic",
  "security.workspace.trust.enabled": false,
  "github.copilot.chat.enabled": false,
  "chat.location": "panel",
  "workbench.panel.defaultChatView": "cline"
}
VSCODESETTINGS_EOF

# add PATH to aatos bashrc and create .claude.json
RUN su - aatos -c "echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc" && \
    su - aatos -c "echo '{\"hasCompletedOnboarding\": true}' > ~/.claude.json"

# ports and volumes
EXPOSE 8443

# CODEX marker - force rebuild
# TIMESTAMP: 2026-05-25T21:20:00Z
LABEL codex.rebuild="2026-05-25-2120"
