# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-ubuntu:noble

# set version label
ARG BUILD_DATE
ARG VERSION="1.0.0-codex"
ARG CODE_RELEASE
LABEL build_version="Codex version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aatos"

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

# Install runtime dependencies and all agents
RUN \
  echo "**** install runtime dependencies ****" && \
  apt-get update && \
  apt-get install -y \
    git \
    curl \
    libatomic1 \
    nano \
    net-tools \
    sudo \
    sqlite3 \
    python3 && \
  echo "**** install claude ****" && \
  curl -fsSL https://claude.ai/install.sh | bash && \
  echo "**** install codex ****" && \
  curl -fsSL https://chatgpt.com/codex/install.sh | sh && \
  echo "**** install hermes ****" && \
  curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash && \
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
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# Copy local files (includes agents-manager at /config/agents-manager)
COPY /root/ /

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Add PATH to bashrc
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /root/.bashrc || true

# Create .claude.json for root (skip onboarding)
RUN echo '{"hasCompletedOnboarding": true}' > /root/.claude.json || true

# Set working directory
WORKDIR /config

# Expose port
EXPOSE 8443

# Entry point - runs setup then starts code-server
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/app/code-server/bin/code-server", "--bind-addr", "0.0.0.0:8443", "--auth", "none", "--user-data-dir", "/config/data"]
