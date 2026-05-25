#!/bin/bash
# =====================================================================
# extensions/install/claude.sh — Install Claude Agent
# =====================================================================
# Usage: bash actions.sh install claude [--user <username>] [--force-fresh]

set -euo pipefail

# Use SCRIPT_DIR from parent if passed (via actions.sh dispatch), otherwise calculate
if [ -n "${SCRIPT_DIR:-}" ]; then
    PROJECT_DIR="$SCRIPT_DIR"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
GLOBAL_BASE="/usr/local/share/agents-manager"

source "${PROJECT_DIR}/extensions/install/_common.sh"

# =====================================================================
# Arguments
# =====================================================================
FORCE_FRESH=false
IS_USER_MODE=false
WORKSPACE_USER=""
for arg in "$@"; do
    case "$arg" in
        --force-fresh) FORCE_FRESH=true ;;
        --user) IS_USER_MODE=true ;;
    esac
done

# Get username if provided as last arg
if [ "$IS_USER_MODE" = true ] && [ $# -ge 1 ]; then
    for arg in "$@"; do
        [[ "$arg" == --* ]] && continue
        WORKSPACE_USER="$arg"
        break
    done
fi

export_env_for_agents

# =====================================================================
# Install state detection
# =====================================================================
ROOT_CLAUDE_DIR="/root/.claude"
if [ -n "$WORKSPACE_USER" ]; then
    USER_CLAUDE_DIR="/workspaces/$WORKSPACE_USER/.claude"
else
    USER_CLAUDE_DIR="/home/user/.claude"
fi
INSTALL_MARKER="$ROOT_CLAUDE_DIR/.install_state"
INSTALLED_VERSION=""

if [ "$FORCE_FRESH" = true ]; then
    INSTALL_MODE="FORCE_FRESH"
    log_info "Mode: FORCE_FRESH"
elif [ -f "$INSTALL_MARKER" ]; then
    INSTALLED_VERSION=$(cat "$INSTALL_MARKER" 2>/dev/null || echo "")
    if [ -n "$INSTALLED_VERSION" ]; then
        INSTALL_MODE="DETECTED_EXISTING"
        log_info "Mode: DETECTED_EXISTING (v$INSTALLED_VERSION installed)"
    else
        INSTALL_MODE="DETECTED_NEW"
    fi
else
    INSTALL_MODE="DETECTED_NEW"
fi

# =====================================================================
# System packages
# =====================================================================
if [ "$IS_USER_MODE" = false ]; then
    log_step "Installing system packages..."
    apt-get update -qq && apt-get install -y -qq sqlite3 git curl unzip rsync
fi

# =====================================================================
# User account (skip in workspace/user mode)
# =====================================================================
if [ "$IS_USER_MODE" = false ]; then
    if ! id "user" &>/dev/null 2>/dev/null; then
        useradd -m -s /bin/bash user
        log_ok "User account created"
    fi
    echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user
    chmod 440 /etc/sudoers.d/user
fi

INSTALL_USER="user"
if [ "$IS_USER_MODE" = true ] && [ -n "$WORKSPACE_USER" ]; then
    INSTALL_USER="$WORKSPACE_USER"
fi

# =====================================================================
# Bun runtime
# =====================================================================
log_step "Bun runtime..."
if ! command -v bun >/dev/null 2>&1; then
    log_info "Installing bun..."
    curl -fsSL https://bun.sh/install | BUN_VERSION=1.3.10 bash
fi
export BUN_INSTALL_DIR="$HOME/.bun"
export PATH="$BUN_INSTALL_DIR/bin:$HOME/.local/bin:$PATH"

# =====================================================================
# pnpm
# =====================================================================
log_step "pnpm..."
export PNPM_HOME="${PNPM_HOME:-/config/.local/share/pnpm}"
if ! command -v pnpm >/dev/null 2>&1; then
    log_info "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh -
fi
export PATH="$BUN_INSTALL_DIR/bin:$PNPM_HOME/bin:$HOME/.local/bin:$PATH"

# =====================================================================
# Claude CLI — root
# =====================================================================
log_step "Claude CLI (root)..."
mkdir -p "$ROOT_CLAUDE_DIR/settings"

if ! command -v claude >/dev/null 2>&1; then
    log_info "Installing Claude CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    log_ok "Claude CLI already installed"
fi

# Configure — sub env vars into presets
PRESETS_DIR="$GLOBAL_BASE/presets/claude"
if [ -f "$PRESETS_DIR/settings.json" ]; then
    log_step "Syncing settings.json..."
    sub_env_vars "$PRESETS_DIR/settings.json" "$ROOT_CLAUDE_DIR/settings.json" "settings.json (root)"
fi
if [ -f "$PRESETS_DIR/onboarding.json" ]; then
    log_step "Syncing .claude.json..."
    sub_env_vars "$PRESETS_DIR/onboarding.json" "$ROOT_CLAUDE_DIR/.claude.json" ".claude.json (root)"
fi

write_install_marker "$ROOT_CLAUDE_DIR"

# =====================================================================
# Claude CLI — user
# =====================================================================
log_step "Claude CLI ($INSTALL_USER)..."
if [ "$IS_USER_MODE" = true ]; then
    mkdir -p "$USER_CLAUDE_DIR/settings"
    if [ ! -f "$USER_CLAUDE_DIR/.claude.json" ]; then
        log_info "Installing Claude CLI for $INSTALL_USER..."
        su - "$INSTALL_USER" -c "curl -fsSL https://claude.ai/install.sh | bash" 2>&1 || log_warn "Claude install for $INSTALL_USER failed"
    else
        log_ok "Claude CLI already installed for $INSTALL_USER"
    fi
else
    su - user -c "mkdir -p ~/.claude/settings"
    if ! su - user -c "command -v claude" >/dev/null 2>&1; then
        log_info "Installing Claude CLI for user..."
        su - user -c "curl -fsSL https://claude.ai/install.sh | bash"
    else
        log_ok "Claude CLI already installed for user"
    fi
fi

CP_PRESETS_DIR="/tmp/.agents-manager-presets"
mkdir -p "$CP_PRESETS_DIR"
cp -R "$GLOBAL_BASE/presets/claude" "$CP_PRESETS_DIR/" 2>/dev/null || true
chmod -R o+rx "$CP_PRESETS_DIR" 2>/dev/null || true

if [ -f "$CP_PRESETS_DIR/claude/settings.json" ]; then
    log_step "Syncing settings.json ($INSTALL_USER)..."
    su - "$INSTALL_USER" -c "export PNPM_HOME='/config/.local/share/pnpm' BUN_INSTALL_DIR='$HOME/.bun'; \
        sed 's|\${MINIMAX_ANTHROPIC_BASE_URL}|${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}|g; \
            s|\${LLM_MODEL}|${LLM_MODEL:-MiniMax-M2.7}|g; \
            s|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY}|g' \
        $CP_PRESETS_DIR/claude/settings.json > ~/.claude/settings/settings.json && \
        echo '  settings.json: OK' || echo '  settings.json: failed'"
fi

write_install_marker "$USER_CLAUDE_DIR"

# =====================================================================
# Sync skills
# =====================================================================
log_step "Syncing skills..."
SKILLS_SRC="$GLOBAL_BASE/skills/claude"
SKILLS_DST_ROOT="$ROOT_CLAUDE_DIR/skills"
SKILLS_DST_USER="$USER_CLAUDE_DIR/skills"

mkdir -p "$SKILLS_DST_ROOT" "$SKILLS_DST_USER"

CLAUDE_SKILLS="gstack ruflo"

for skill_name in $CLAUDE_SKILLS; do
    skill_dir="$SKILLS_SRC/$skill_name"

    if [ ! -d "$skill_dir" ]; then
        log_warn "skill: $skill_name not found in source"
        continue
    fi

    log_step "Syncing skill: $skill_name"

    # Sync subdirectories
    for src_item in "$skill_dir"/*/; do
        [ -d "$src_item" ] || continue
        item_name=$(basename "$src_item")
        [[ "$item_name" == .* ]] && continue

        dst_item="$SKILLS_DST_ROOT/$item_name"
        if [ -d "$dst_item" ]; then
            rsync -a --delete "$src_item/" "$dst_item/" 2>/dev/null && \
                log_ok "  $item_name — synced" || log_warn "  $item_name — sync failed"
        else
            cp -r "$src_item" "$dst_item"
            log_ok "  $item_name — NEW"
        fi
    done

    # Sync top-level files
    for src_file in "$skill_dir"/*; do
        [ -f "$src_file" ] || continue
        item_name=$(basename "$src_file")
        [[ "$item_name" == .* ]] && continue
        dst_file="$SKILLS_DST_ROOT/$item_name"
        if [ ! -f "$dst_file" ]; then
            cp -p "$src_file" "$dst_file"
            log_ok "  $item_name — NEW (file)"
        fi
    done

    # Run setup if exists
    if [ -x "$skill_dir/setup" ]; then
        log_step "Running setup for $skill_name..."
        (cd "$SKILLS_DST_ROOT/$skill_name" && ./setup 2>&1) || log_warn "  setup failed for root"
        su - user -c "cd ~/.claude/skills/$skill_name && ./setup 2>&1" || log_warn "  setup failed for user"
    fi

    # Install deps
    if [ -f "$skill_dir/pnpm-lock.yaml" ]; then
        log_step "Running pnpm install for $skill_name..."
        (cd "$SKILLS_DST_ROOT/$skill_name" && /config/.local/share/pnpm/bin/pnpm install --frozen-lockfile 2>&1) || \
        (cd "$SKILLS_DST_ROOT/$skill_name" && /config/.local/share/pnpm/bin/pnpm install 2>&1) || \
            { log_warn "  pnpm install completed with warnings (non-fatal)"; }
        su - user -c 'cd ~/.claude/skills/'"$skill_name"' && /config/.local/share/pnpm/bin/pnpm install --frozen-lockfile 2>&1' || \
        su - user -c 'cd ~/.claude/skills/'"$skill_name"' && /config/.local/share/pnpm/bin/pnpm install 2>&1' || \
            { log_warn "  pnpm install completed with warnings for user (non-fatal)"; }
    fi

    # Verify
    if [ -f "$SKILLS_DST_ROOT/$skill_name/SKILL.md" ] || \
       [ -f "$SKILLS_DST_ROOT/$skill_name/CLAUDE.md" ]; then
        log_ok "skill: $skill_name — OK (root)"
    else
        log_warn "skill: $skill_name — WARNING: missing SKILL/CLAUDE.md"
    fi
done

# =====================================================================
# Final status
# =====================================================================
log_step "Final status..."
echo ""
log_ok "Claude Agent Install/Update Complete"
echo "  Mode:       $INSTALL_MODE"
echo "  Root:       $ROOT_CLAUDE_DIR"
echo "  User:       $USER_CLAUDE_DIR"
echo "  Installed:  $(cat $INSTALL_MARKER 2>/dev/null || echo 'unknown')"
echo ""
echo "Quick commands:"
echo "  claude --version  — check CLI"
echo "  claude login      — authenticate"