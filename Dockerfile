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

# copy local files (includes agents-manager at root/config/agents-manager)
COPY /root /

# create user with passwordless sudo
RUN if ! id "user" &>/dev/null; then \
      useradd -m -s /bin/bash user; \
    fi && \
    echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user && \
    chmod 440 /etc/sudoers.d/user && \
    usermod -aG sudo user

# install claude for root
RUN curl -fsSL https://claude.ai/install.sh | bash

# write root settings.json via python (avoids heredoc parsing issues)
RUN python3 -c "
import os
settings = {
  'skipDangerousModePermissionPrompt': True,
  'env': {
    'ANTHROPIC_BASE_URL': os.environ.get('MINIMAX_ANTHROPIC_BASE_URL', ''),
    'ANTHROPIC_MODEL': os.environ.get('LLM_MODEL', ''),
    'ANTHROPIC_DEFAULT_SONNET_MODEL': os.environ.get('LLM_MODEL', ''),
    'ANTHROPIC_DEFAULT_OPUS_MODEL': os.environ.get('LLM_MODEL', ''),
    'ANTHROPIC_DEFAULT_HAIKU_MODEL': os.environ.get('LLM_MODEL', ''),
    'CLAUDE_CODE_SUBAGENT_MODEL': os.environ.get('LLM_MODEL', ''),
    'ANTHROPIC_AUTH_TOKEN': os.environ.get('ANTHROPIC_API_KEY', ''),
    'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS': '10',
    'teammateMode': 'tmux'
  },
  'dangerouslyAlwaysAllow': True,
  'allow': ['Edit', 'Write', 'Bash', 'Read', 'Glob', 'Grep', 'WebFetch', 'WebSearch', 'TodoRead', 'TodoWrite']
}
os.makedirs('/root/.claude/settings', exist_ok=True)
import json
with open('/root/.claude/settings.json', 'w') as f:
    json.dump(settings, f, indent=2)
"

# add PATH to root bashrc
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /root/.bashrc

# create .claude.json for root (skip onboarding)
RUN echo '{"hasCompletedOnboarding": true}' > /root/.claude.json

# install claude for user
RUN su - user -c "curl -fsSL https://claude.ai/install.sh | bash"

# write user settings.json via python3 -c
RUN su - user -c "python3 -c \"import os, json; settings = {
  'skipDangerousModePermissionPrompt': True,
  'env': {
    'ANTHROPIC_BASE_URL': os.environ.get('MINIMAX_ANTHROPIC_BASE_URL', ''),
    'ANTHROPIC_MODEL': os.environ.get('LLM_MODEL', ''),
    'ANTHROPIC_DEFAULT_SONNET_MODEL': os.environ.get('LLM_MODEL', ''),
    'ANTHROPIC_DEFAULT_OPUS_MODEL': os.environ.get('LLM_MODEL', ''),
    'ANTHROPIC_DEFAULT_HAIKU_MODEL': os.environ.get('LLM_MODEL', ''),
    'CLAUDE_CODE_SUBAGENT_MODEL': os.environ.get('LLM_MODEL', ''),
    'ANTHROPIC_AUTH_TOKEN': os.environ.get('ANTHROPIC_API_KEY', ''),
    'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS': '10',
    'teammateMode': 'tmux'
  },
  'dangerouslyAlwaysAllow': True,
  'allow': ['Edit', 'Write', 'Bash', 'Read', 'Glob', 'Grep', 'WebFetch', 'WebSearch', 'TodoRead', 'TodoWrite']
}; os.makedirs(os.path.expanduser('~/.claude/settings'), exist_ok=True); open(os.path.expanduser('~/.claude/settings.json'), 'w').write(json.dumps(settings, indent=2))\""

# add PATH to user bashrc and create .claude.json
RUN su - user -c "echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc" && \
    su - user -c "echo '{\"hasCompletedOnboarding\": true}' > ~/.claude.json"

# ports and volumes
EXPOSE 8443
