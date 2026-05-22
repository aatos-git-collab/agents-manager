#!/bin/bash
# =====================================================================
# Claude Agent Install Script — Smart Install/Update
# =====================================================================
# Usage: bash claude-install.sh [--force-fresh]
#   --force-fresh  : skip install detection, treat as fresh install
#
# Modes:
#   DETECTED_NEW      — first time install, full setup
#   DETECTED_EXISTING — re-run, smart update only what's changed
#   FORCE_FRESH       — --force-fresh flag, full reinstall
# =====================================================================
set -euo pipefail

export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_INSTALLS_DIR="$(dirname "$SCRIPT_DIR")"
PRESETS_DIR="$AGENT_INSTALLS_DIR/presets/claude"
ENV_FILE="$AGENT_INSTALLS_DIR/.env"

# Copy presets to temp location accessible by user
CP_PRESETS_DIR="/tmp/.agents-manager-presets"
mkdir -p "$CP_PRESETS_DIR"
cp -R "$AGENT_INSTALLS_DIR/presets/claude" "$CP_PRESETS_DIR/"
chmod -R o+rx "$CP_PRESETS_DIR"

# Fix permissions so user account can read everything
chmod -R o+rx "$AGENT_INSTALLS_DIR" 2>/dev/null || true

# Load env from central .env file
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# =====================================================================
# Arguments
# =====================================================================
FORCE_FRESH=false
for arg in "$@"; do
    case "$arg" in
        --force-fresh) FORCE_FRESH=true ;;
    esac
done

# =====================================================================
# Detect container environment
# =====================================================================
IS_CONTAINER=false
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null || [ ! -d /proc/1 ]; then
    IS_CONTAINER=true
fi

# =====================================================================
# Install state detection
# =====================================================================
ROOT_CLAUDE_DIR="/root/.claude"
USER_CLAUDE_DIR="/home/user/.claude"
INSTALL_MARKER_ROOT="$ROOT_CLAUDE_DIR/.install_state"
INSTALL_MARKER_USER="$USER_CLAUDE_DIR/.install_state"
INSTALLED_VERSION=""
INSTALL_MODE="DETECTED_NEW"

if [ "$FORCE_FRESH" = true ]; then
    INSTALL_MODE="FORCE_FRESH"
    echo "Mode: FORCE_FRESH (--force-fresh set)"
elif [ -f "$INSTALL_MARKER_ROOT" ]; then
    INSTALLED_VERSION=$(cat "$INSTALL_MARKER_ROOT" 2>/dev/null || echo "")
    if [ -n "$INSTALLED_VERSION" ]; then
        INSTALL_MODE="DETECTED_EXISTING"
        echo "Mode: DETECTED_EXISTING (v$INSTALLED_VERSION installed)"
    else
        echo "Mode: DETECTED_NEW (first install)"
    fi
else
    echo "Mode: DETECTED_NEW (first install)"
fi

# =====================================================================
# Helper: Copy file only if different (preserves existing)
# =====================================================================
copy_if_different() {
    local src="$1"
    local dst="$2"
    local label="${3:-file}"

    if [ ! -f "$src" ]; then
        echo "  $label: SOURCE NOT FOUND ($src)"
        return 1
    fi

    if [ -f "$dst" ]; then
        if cmp -s "$src" "$dst" 2>/dev/null; then
            echo "  $label: unchanged — skipping"
            return 0
        fi
        echo "  $label: updating (backing up existing)"
        cp -p "$dst" "${dst}.bak.$(date +%s)" 2>/dev/null || true
    else
        echo "  $label: new — copying"
    fi

    cp -p "$src" "$dst"
    echo "  $label: OK"
    return 0
}

# =====================================================================
# Helper: Sync skills directory (rsync — preserves existing extras)
# =====================================================================
sync_skills() {
    local src_dir="$1"
    local dst_dir="$2"
    local label="${3:-skill}"

    if [ ! -d "$src_dir" ]; then
        echo "  $label: source dir not found — skip"
        return 0
    fi

    mkdir -p "$dst_dir"

    for src_item in "$src_dir"/*/; do
        [ -d "$src_item" ] || continue
        item_name=$(basename "$src_item")
        [[ "$item_name" == .* ]] && continue

        dst_item="$dst_dir/$item_name"

        if [ -d "$dst_item" ]; then
            # Exists — rsync only changed files (preserves custom files in dest)
            rsync -a --delete "$src_item/" "$dst_item/" 2>/dev/null && \
                echo "  $label: $item_name — unchanged" || \
                echo "  $label: $item_name — synced"
        else
            # New — copy whole directory
            cp -r "$src_item" "$dst_item"
            echo "  $label: $item_name — NEW"
        fi
    done
}

# =====================================================================
# Helper: Sub with env substitution
# =====================================================================
sub_preset() {
    local src="$1"
    local dst="$2"
    local label="${3:-preset}"

    if [ ! -f "$src" ]; then
        echo "  $label: SOURCE NOT FOUND ($src)"
        return 1
    fi

    if [ -f "$dst" ] && cmp -s "$src" "$dst" 2>/dev/null; then
        echo "  $label: unchanged — skipping"
        return 0
    fi

    local tmp_sub="/tmp/.preset-sub-$$.tmp"
    sed "s|\${MINIMAX_ANTHROPIC_BASE_URL}|${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}|g;
        s|\${LLM_MODEL}|${LLM_MODEL:-MiniMax-M2.7}|g;
        s|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY}|g" \
        "$src" > "$tmp_sub"
    chmod 644 "$tmp_sub"
    copy_if_different "$tmp_sub" "$dst" "$label"
    rm -f "$tmp_sub"
}

# =====================================================================
# Helper: Write install marker
# =====================================================================
write_install_marker() {
    local home="$1"
    echo "v0.14.0-$(date +%Y%m%d-%H%M%S)" > "$home/.install_state"
    echo "  Install marker written"
}

# =====================================================================
# System packages
# =====================================================================
echo ""
echo ">>> Installing system packages..."
apt-get update -qq && apt-get install -y -qq sqlite3 git curl unzip rsync

# =====================================================================
# User account setup
# =====================================================================
if ! id "user" &>/dev/null 2>/dev/null; then
    echo ""
    echo ">>> Setting up user account..."
    useradd -m -s /bin/bash user
    echo "  user account created"
else
    echo ""
    echo ">>> User account exists — skip"
fi

echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user
chmod 440 /etc/sudoers.d/user
usermod -aG sudo user 2>/dev/null || true

# =====================================================================
# Install Bun (required for gstack)
# =====================================================================
echo ""
echo ">>> Bun runtime..."
if ! command -v bun >/dev/null 2>&1; then
    echo "  Installing bun..."
    curl -fsSL https://bun.sh/install | BUN_VERSION=1.3.10 bash
else
    echo "  Bun already installed — skip"
fi
export BUN_INSTALL_DIR="$HOME/.bun"
export PATH="$BUN_INSTALL_DIR/bin:$HOME/.local/bin:$PATH"

# =====================================================================
# Install pnpm (required for ruflo)
# =====================================================================
echo ""
echo ">>> pnpm..."
if ! command -v pnpm >/dev/null 2>&1; then
    echo "  Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh -
else
    echo "  pnpm already installed — skip"
fi
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

# =====================================================================
# Install Claude CLI — root
# =====================================================================
echo ""
echo ">>> Claude CLI (root)..."

mkdir -p "$ROOT_CLAUDE_DIR/settings"

if ! command -v claude >/dev/null 2>&1; then
    echo "  Installing Claude CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    echo "  Claude CLI already installed — skip binary install"
fi

# Configure — sub env vars into presets
if [ -f "$PRESETS_DIR/settings.json" ]; then
    echo "  Syncing settings.json..."
    sub_preset "$PRESETS_DIR/settings.json" "$ROOT_CLAUDE_DIR/settings.json" "settings.json (root)"
fi
if [ -f "$PRESETS_DIR/onboarding.json" ]; then
    echo "  Syncing .claude.json..."
    sub_preset "$PRESETS_DIR/onboarding.json" "$ROOT_CLAUDE_DIR/.claude.json" ".claude.json (root)"
fi

write_install_marker "$ROOT_CLAUDE_DIR"

# =====================================================================
# Install Claude CLI — user
# =====================================================================
echo ""
echo ">>> Claude CLI (user)..."

su - user -c "mkdir -p ~/.claude/settings"

if ! su - user -c "command -v claude" >/dev/null 2>&1; then
    echo "  Installing Claude CLI for user..."
    su - user -c "curl -fsSL https://claude.ai/install.sh | bash"
else
    echo "  Claude CLI already installed for user — skip"
fi

if [ -f "$CP_PRESETS_DIR/claude/settings.json" ]; then
    echo "  Syncing settings.json..."
    su - user -c "HERMES_HOME=~/.claude; export HERMES_HOME; \
        $(declare -f sub_preset); \
        sed 's|\${MINIMAX_ANTHROPIC_BASE_URL}|${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}|g; \
            s|\${LLM_MODEL}|${LLM_MODEL:-MiniMax-M2.7}|g; \
            s|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY}|g' \
        $CP_PRESETS_DIR/claude/settings.json > ~/.claude/settings/settings.json && \
        echo '  settings.json: OK' || echo '  settings.json: failed'"
fi

if [ -f "$CP_PRESETS_DIR/claude/onboarding.json" ]; then
    echo "  Syncing .claude.json..."
    su - user -c "HERMES_HOME=~/.claude; export HERMES_HOME; \
        $(declare -f sub_preset); \
        sed 's|\${MINIMAX_ANTHROPIC_BASE_URL}|${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}|g; \
            s|\${LLM_MODEL}|${LLM_MODEL:-MiniMax-M2.7}|g; \
            s|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY}|g' \
        $CP_PRESETS_DIR/claude/onboarding.json > ~/.claude/.claude.json && \
        echo '  .claude.json: OK' || echo '  .claude.json: failed'"
fi

write_install_marker "$USER_CLAUDE_DIR"

# =====================================================================
# Sync skills — root & user (rsync, preserves extras)
# =====================================================================
echo ""
echo ">>> Syncing skills..."

SKILLS_SRC="$AGENT_INSTALLS_DIR/skills/claude"
SKILLS_DST_ROOT="$ROOT_CLAUDE_DIR/skills"
SKILLS_DST_USER="$USER_CLAUDE_DIR/skills"

mkdir -p "$SKILLS_DST_ROOT"
mkdir -p "$SKILLS_DST_USER"

CLAUDE_SKILLS="gstack ruflo"

for skill_name in $CLAUDE_SKILLS; do
    skill_dir="$SKILLS_SRC/$skill_name"

    if [ ! -d "$skill_dir" ]; then
        echo "  skill: $skill_name not found in source — skip"
        continue
    fi

    echo "  Syncing skill: $skill_name"

    # Git update if it's a repo
    if [ -d "$skill_dir/.git" ]; then
        echo "  Pulling latest from git..."
        (cd "$skill_dir" && git fetch origin && git checkout --force . 2>/dev/null && \
            git pull --ff-only origin 2>/dev/null) || \
            echo "  Git update failed — using existing"
    fi

    # rsync to root (not rm -rf)
    sync_skills "$skill_dir" "$SKILLS_DST_ROOT/$skill_name" "skill:$skill_name (root)"
    # rsync to user
    if [ -d "$SKILLS_DST_USER" ]; then
        sync_skills "$skill_dir" "$SKILLS_DST_USER/$skill_name" "skill:$skill_name (user)"
    fi

    # Run setup if it exists
    if [ -x "$skill_dir/setup" ]; then
        echo "  Running setup for $skill_name..."
        (cd "$SKILLS_DST_ROOT/$skill_name" && ./setup 2>&1) || \
            echo "  setup failed for root — continuing"
        su - user -c "cd ~/.claude/skills/$skill_name && ./setup 2>&1" || \
            echo "  setup failed for user — continuing"
    fi

    # Install deps if lock file exists
    if [ -f "$skill_dir/pnpm-lock.yaml" ]; then
        echo "  Running pnpm install for $skill_name..."
        (cd "$SKILLS_DST_ROOT/$skill_name" && pnpm install --frozen-lockfile 2>&1) || \
        (cd "$SKILLS_DST_ROOT/$skill_name" && pnpm install 2>&1) || \
            echo "  pnpm install failed for root"
        su - user -c "cd ~/.claude/skills/$skill_name && pnpm install --frozen-lockfile 2>&1" || \
        su - user -c "cd ~/.claude/skills/$skill_name && pnpm install 2>&1" || \
            echo "  pnpm install failed for user"
    elif [ -f "$skill_dir/package-lock.json" ]; then
        echo "  Running npm install for $skill_name..."
        (cd "$SKILLS_DST_ROOT/$skill_name" && npm install --legacy-peer-deps 2>&1) || \
            echo "  npm install failed for root"
        su - user -c "cd ~/.claude/skills/$skill_name && npm install --legacy-peer-deps 2>&1" || \
            echo "  npm install failed for user"
    fi

    # Verify
    if [ -f "$SKILLS_DST_ROOT/$skill_name/SKILL.md" ] || \
       [ -f "$SKILLS_DST_ROOT/$skill_name/CLAUDE.md" ]; then
        echo "  skill: $skill_name — OK (root)"
    else
        echo "  skill: $skill_name — WARNING: missing SKILL/CLAUDE.md (root)"
    fi
done

# =====================================================================
# Final status
# =====================================================================
echo ""
echo "========================================"
echo "Claude Agent Install/Update Complete"
echo "========================================"
echo "Mode:       $INSTALL_MODE"
echo "Root:       $ROOT_CLAUDE_DIR"
echo "User:       $USER_CLAUDE_DIR"
echo "Installed:  $(cat $INSTALL_MARKER_ROOT 2>/dev/null || echo 'unknown')"
echo ""
echo "Quick commands:"
echo "  claude --version  — check CLI"
echo "  claude login      — authenticate"
echo "========================================"