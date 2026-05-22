#!/bin/bash
set -e

export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_INSTALLS_DIR="$SCRIPT_DIR"
PRESETS_DIR="$AGENT_INSTALLS_DIR/presets/claude"
ENV_FILE="$AGENT_INSTALLS_DIR/.env"

# Load env from central .env file
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# Install required system packages
echo "Installing system packages..."
apt-get update && apt-get install -y sqlite3 git curl unzip

# ========================================
# Install Bun (required for gstack setup)
# ========================================
if ! command -v bun >/dev/null 2>&1; then
    echo "Installing bun..."
    curl -fsSL https://bun.sh/install | BUN_VERSION=1.3.10 bash
    export BUN_INSTALL_DIR="$HOME/.bun"
    export PATH="$BUN_INSTALL_DIR/bin:$PATH"
fi

# ========================================
# Install pnpm (required for ruflo)
# ========================================
if ! command -v pnpm >/dev/null 2>&1; then
    echo "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh -
fi

export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

# ========================================
# Setup user account for passwordless access
# ========================================
echo "========================================"
echo "Setting up user account..."
echo "========================================"

if ! id "user" &>/dev/null; then
    useradd -m -s /bin/bash user
fi

echo "user:" | chpasswd -e 2>/dev/null || usermod -p "" user
echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user
chmod 440 /etc/sudoers.d/user
usermod -aG sudo user

# ========================================
# Install Claude for root
# ========================================
echo "========================================"
echo "Installing Claude CLI for root..."
echo "========================================"
curl -fsSL https://claude.ai/install.sh | bash

echo "Configuring Claude CLI for root..."

ROOT_CLAUDE_DIR=$(getent passwd root | cut -d: -f6)/.claude
mkdir -p "$ROOT_CLAUDE_DIR/settings"

# Copy and substitute preset files
sed "s|\${MINIMAX_ANTHROPIC_BASE_URL}|${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}|g;
    s|\${LLM_MODEL}|${LLM_MODEL:-MiniMax-M2.7}|g;
    s|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY}|g" \
    "$PRESETS_DIR/settings.json" > "$ROOT_CLAUDE_DIR/settings.json"

# Create onboarding file
sed "s|\${MINIMAX_ANTHROPIC_BASE_URL}|${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}|g;
    s|\${LLM_MODEL}|${LLM_MODEL:-MiniMax-M2.7}|g;
    s|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY}|g" \
    "$PRESETS_DIR/onboarding.json" > "$ROOT_CLAUDE_DIR/.claude.json"

echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> /root/.bashrc

# ========================================
# Install Claude for user
# ========================================
echo "========================================"
echo "Installing Claude CLI for user..."
echo "========================================"

su - user -c "curl -fsSL https://claude.ai/install.sh | bash"

echo "Configuring Claude CLI for user..."

su - user -c "mkdir -p ~/.claude/settings"

# Copy and substitute preset files for user
su - user -c "sed -e 's|\${MINIMAX_ANTHROPIC_BASE_URL}|${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}|g' \
    -e 's|\${LLM_MODEL}|${LLM_MODEL:-MiniMax-M2.7}|g' \
    -e 's|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY}|g' \
    $PRESETS_DIR/settings.json > ~/.claude/settings.json"

su - user -c "sed -e 's|\${MINIMAX_ANTHROPIC_BASE_URL}|${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}|g' \
    -e 's|\${LLM_MODEL}|${LLM_MODEL:-MiniMax-M2.7}|g' \
    -e 's|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY}|g' \
    $PRESETS_DIR/onboarding.json > ~/.claude.json"

su - user -c 'echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc'

# ========================================
# Install Claude Skills (gstack, ruflo only - NOT clawteam)
# ========================================
echo "========================================"
echo "Installing Claude Skills..."
echo "========================================"

SKILLS_SRC="$AGENT_INSTALLS_DIR/skills/claude"
SKILLS_DST_ROOT="/root/.claude/skills"
SKILLS_DST_USER="/home/user/.claude/skills"

# Create skills directories
mkdir -p "$SKILLS_DST_ROOT"
mkdir -p "$SKILLS_DST_USER"

# Skills to install (excludes clawteam which is for hermes)
CLAUDE_SKILLS="gstack ruflo"

for skill_name in $CLAUDE_SKILLS; do
    skill_dir="$SKILLS_SRC/$skill_name"

    if [ ! -d "$skill_dir" ]; then
        echo "  SKIP: $skill_name not found in source"
        continue
    fi

    echo "  Installing skill: $skill_name"

    # Check if it's a git repo and update from remote
    if [ -d "$skill_dir/.git" ]; then
        echo "    -> Pulling latest from git..."
        (cd "$skill_dir" && git pull --ff-only) || echo "    -> Git pull failed or no remote, using existing"
    fi

    # Install for root
    rm -rf "$SKILLS_DST_ROOT/$skill_name"
    cp -r "$skill_dir" "$SKILLS_DST_ROOT/$skill_name"

    # Install for user
    rm -rf "$SKILLS_DST_USER/$skill_name"
    cp -r "$skill_dir" "$SKILLS_DST_USER/$skill_name"

    # Run setup if it exists (e.g., gstack/setup builds the browser binary)
    if [ -x "$skill_dir/setup" ]; then
        echo "    -> Running setup for $skill_name..."
        # Run setup for root
        (cd "$SKILLS_DST_ROOT/$skill_name" && ./setup 2>&1) || echo "    -> Setup failed for root, continuing..."
        # Run setup for user
        su - user -c "cd ~/.claude/skills/$skill_name && ./setup 2>&1" || echo "    -> Setup failed for user, continuing..."
    fi

    # For ruflo, run pnpm install if pnpm-lock.yaml exists
    if [ -f "$skill_dir/pnpm-lock.yaml" ]; then
        echo "    -> Installing dependencies with pnpm for $skill_name..."
        # For root
        (cd "$SKILLS_DST_ROOT/$skill_name" && pnpm install --frozen-lockfile 2>&1) || \
        (cd "$SKILLS_DST_ROOT/$skill_name" && pnpm install 2>&1) || echo "    -> pnpm install failed for root"
        # For user
        su - user -c "cd ~/.claude/skills/$skill_name && pnpm install --frozen-lockfile 2>&1" || \
        su - user -c "cd ~/.claude/skills/$skill_name && pnpm install 2>&1" || echo "    -> pnpm install failed for user"
    # For npm-based skills
    elif [ -f "$skill_dir/package-lock.json" ]; then
        echo "    -> Installing dependencies with npm for $skill_name..."
        (cd "$SKILLS_DST_ROOT/$skill_name" && npm install --legacy-peer-deps 2>&1) || echo "    -> npm install failed for root"
        su - user -c "cd ~/.claude/skills/$skill_name && npm install --legacy-peer-deps 2>&1" || echo "    -> npm install failed for user"
    fi

    # Verify skill was installed correctly (check for SKILL.md or CLAUDE.md)
    if [ -f "$SKILLS_DST_ROOT/$skill_name/SKILL.md" ] || [ -f "$SKILLS_DST_ROOT/$skill_name/CLAUDE.md" ]; then
        echo "    -> $skill_name: OK (root)"
    else
        echo "    -> $skill_name: MISSING skill file (root)"
    fi
    if [ -f "$SKILLS_DST_USER/$skill_name/SKILL.md" ] || [ -f "$SKILLS_DST_USER/$skill_name/CLAUDE.md" ]; then
        echo "    -> $skill_name: OK (user)"
    else
        echo "    -> $skill_name: MISSING skill file (user)"
    fi
done

echo "========================================"
echo "Done!"
echo "  - claude: claude (root and user)"
echo "  - skills: $CLAUDE_SKILLS"
echo "  - su user: no password required"
echo "========================================"