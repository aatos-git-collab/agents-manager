# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-ubuntu:noble

# set version label
ARG BUILD_DATE
ARG VERSION
ARG CODE_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ENV HOME="/config"

# env args from .env
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
    sqlite3 && \
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

# copy local files (includes agents-manager and install-claude.sh)
COPY /root /

# create user with passwordless sudo
RUN if ! id "user" &>/dev/null; then \
      useradd -m -s /bin/bash user; \
    fi && \
    echo "user:" | chpasswd -e 2>/dev/null || usermod -p "" user && \
    echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user && \
    chmod 440 /etc/sudoers.d/user && \
    usermod -aG sudo user

# install claude for root
RUN curl -fsSL https://claude.ai/install.sh | bash

# configure claude for root
RUN mkdir -p ~/.claude/settings && \
    cat > ~/.claude/settings.json << 'SETTINGS_EOF'
{
  "skipDangerousModePermissionPrompt": true,
  "env": {
    "ANTHROPIC_BASE_URL": "'"${MINIMAX_ANTHROPIC_BASE_URL}"'",
    "ANTHROPIC_MODEL": "'"${LLM_MODEL}"'",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "'"${LLM_MODEL}"'",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "'"${LLM_MODEL}"'",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "'"${LLM_MODEL}"'",
    "CLAUDE_CODE_SUBAGENT_MODEL": "'"${LLM_MODEL}"'",
    "ANTHROPIC_AUTH_TOKEN": "'"${ANTHROPIC_API_KEY}"'",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "10",
    "teammateMode": "tmux"
  },
  "dangerouslyAlwaysAllow": true,
  "allow": [
    "Edit",
    "Write",
    "Bash",
    "Read",
    "Glob",
    "Grep",
    "WebFetch",
    "WebSearch",
    "TodoRead",
    "TodoWrite"
  ]
}
SETTINGS_EOF

# add PATH to root bashrc
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# create .claude.json for root (skip onboarding)
RUN cat > ~/.claude.json << 'EOF'
{
  "hasCompletedOnboarding": true
}
EOF

# install claude for user
RUN su - user -c "curl -fsSL https://claude.ai/install.sh | bash"

# configure claude for user
RUN su - user -c "mkdir -p ~/.claude/settings" && \
    su - user -c 'cat > ~/.claude/settings.json << '"'"'SETTINGS_EOF'"'"'
{
  "skipDangerousModePermissionPrompt": true,
  "env": {
    "ANTHROPIC_BASE_URL": "'"${MINIMAX_ANTHROPIC_BASE_URL}"'",
    "ANTHROPIC_MODEL": "'"${LLM_MODEL}"'",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "'"${LLM_MODEL}"'",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "'"${LLM_MODEL}"'",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "'"${LLM_MODEL}"'",
    "CLAUDE_CODE_SUBAGENT_MODEL": "'"${LLM_MODEL}"'",
    "ANTHROPIC_AUTH_TOKEN": "'"${ANTHROPIC_API_KEY}"'",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "10",
    "teammateMode": "tmux"
  },
  "dangerouslyAlwaysAllow": true,
  "allow": [
    "Edit",
    "Write",
    "Bash",
    "Read",
    "Glob",
    "Grep",
    "WebFetch",
    "WebSearch",
    "TodoRead",
    "TodoWrite"
  ]
}
SETTINGS_EOF'"'"'' && \
    su - user -c 'echo "export PATH=\"$HOME/.local/bin:$PATH\"" >> ~/.bashrc' && \
    su - user -c 'cat > ~/.claude.json << '"'"'EOF'"'"'
{
  "hasCompletedOnboarding": true
}
EOF'"'"''

# ports and volumes
EXPOSE 8443
