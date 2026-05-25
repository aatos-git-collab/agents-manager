#!/bin/bash
# =====================================================================
# extensions/install/hermes.sh — Install Hermes Agent
# =====================================================================
# Usage: bash actions.sh install hermes [--user] [--force-fresh]
#
# Modes:
#   --user         User mode: use global skills/presets, only create
#                  own ~/.hermes/.env for private keys.
#   --force-fresh  Skip install detection, treat as fresh install

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
for arg in "$@"; do
    case "$arg" in
        --force-fresh) FORCE_FRESH=true ;;
        --user) IS_USER_MODE=true ;;
    esac
done

export_env_for_agents

# =====================================================================
# Install state detection
# =====================================================================
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
INSTALL_MARKER="$HERMES_HOME/.install_state"
INSTALLED_VERSION=""

[ -f "$INSTALL_MARKER" ] && INSTALLED_VERSION=$(cat "$INSTALL_MARKER" 2>/dev/null || echo "")

if [ "$FORCE_FRESH" = true ]; then
    INSTALL_MODE="FORCE_FRESH"
    log_info "Mode: FORCE_FRESH"
elif [ -d "$HERMES_HOME" ] && [ -n "$INSTALLED_VERSION" ]; then
    INSTALL_MODE="DETECTED_EXISTING"
    log_info "Mode: DETECTED_EXISTING (v$INSTALLED_VERSION installed)"
else
    INSTALL_MODE="DETECTED_NEW"
    log_info "Mode: DETECTED_NEW"
fi

# =====================================================================
# System packages (skip in user mode)
# =====================================================================
if [ "$IS_USER_MODE" = false ]; then
    log_step "Installing system packages..."
    apt-get update -qq && apt-get install -y -qq sqlite3 xz-utils curl git rsync
fi

# =====================================================================
# User account setup (skip in container/user mode)
# =====================================================================
if [ "$IS_USER_MODE" = false ] && [ -d /run/systemd/system ]; then
    if ! id "user" &>/dev/null; then
        useradd -m -s /bin/bash user
        log_ok "User account created"
    fi
    echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user
    chmod 440 /etc/sudoers.d/user
fi

# =====================================================================
# Hermes CLI
# =====================================================================
log_step "Hermes CLI..."
mkdir -p "$HERMES_HOME"/{memories,sessions,tasks,skills,logs}

if ! command -v hermes >/dev/null 2>&1; then
    log_info "Installing Hermes binary..."
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
else
    log_ok "Hermes CLI already installed"
    if [ "$INSTALL_MODE" = "DETECTED_EXISTING" ]; then
        hermes version 2>/dev/null | grep -q "Up to date" && log_ok "Hermes up to date" || {
            log_info "Update available, reinstalling..."
            curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
        }
    fi
fi

# =====================================================================
# Configure model
# =====================================================================
log_step "Configuring model..."
hermes config set model.provider anthropic 2>/dev/null || true
hermes config set model.default MiniMax-M2.7 2>/dev/null || true
hermes config set model.base_url "${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}" 2>/dev/null || true
hermes config set model.api_key "${MINIMAX_API_KEY:-}" 2>/dev/null || true
hermes config set gateway.host 127.0.0.1 2>/dev/null || true
hermes config set gateway.port 18789 2>/dev/null || true

# =====================================================================
# Sync .env (user mode: copy from /config/.hermes/.env first)
# =====================================================================
if [ "$IS_USER_MODE" = true ]; then
    env_src=$(get_env_source)
    if [ -n "$env_src" ]; then
        mkdir -p "$HERMES_HOME"
        copy_if_different "$env_src" "$HERMES_HOME/.env" ".env"
    fi

    # Sync keys from .env.global to workspace .env
    sync_hermes_env "$HERMES_HOME"
fi

# =====================================================================
# Sync config.yaml from presets
# =====================================================================
PRESETS_DIR="$GLOBAL_BASE/presets/hermes"
if [ -f "$PRESETS_DIR/config.yaml" ]; then
    log_step "Syncing config.yaml..."
    local tmp_cfg="/tmp/hermes-config-$$.yaml"
    load_env
    sed -e "s|\${MINIMAX_ANTHROPIC_BASE_URL}|${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}|g" \
        -e "s|\${MINIMAX_API_KEY}|${MINIMAX_API_KEY:-}|g" \
        -e "s|\${ANTHROPIC_API_KEY}|${ANTHROPIC_API_KEY:-}|g" \
        "$PRESETS_DIR/config.yaml" > "$tmp_cfg"
    copy_if_different "$tmp_cfg" "$HERMES_HOME/config.yaml" "config.yaml"
    rm -f "$tmp_cfg"
fi

# =====================================================================
# Apply Mattermost config
# =====================================================================
if [ "$IS_USER_MODE" = true ]; then
    apply_mattermost_config "$HERMES_HOME"
fi

# =====================================================================
# Skills (shared globally, symlinked to workspace)
# =====================================================================
if [ "$IS_USER_MODE" = true ]; then
    log_step "Syncing skills..."
    chmod -R a+rwX "$GLOBAL_BASE/skills" 2>/dev/null || true

    HERMES_SKILLS_SRC="$GLOBAL_BASE/skills/hermes"
    mkdir -p "$HERMES_HOME/skills"

    for skill_dir in "$HERMES_SKILLS_SRC"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        [[ "$skill_name" == .* ]] && continue

        user_skill_dir="$HERMES_HOME/skills/$skill_name"
        if [ ! -L "$user_skill_dir" ] && [ ! -d "$user_skill_dir" ]; then
            ln -sf "$GLOBAL_BASE/skills/hermes/$skill_name" "$user_skill_dir" 2>/dev/null || \
                cp -r "$skill_dir" "$user_skill_dir"
            log_ok "skill: $skill_name — linked"
        fi
    done
fi

# =====================================================================
# Write install marker
# =====================================================================
echo "v0.14.0-$(date +%Y%m%d-%H%M%S)" > "$HERMES_HOME/.install_state"
log_ok "Install marker written"

# =====================================================================
# Gateway (manual in container/user mode)
# =====================================================================
if [ "$IS_USER_MODE" = false ] && [ -d /run/systemd/system ]; then
    ensure_gateway_systemd
    systemctl daemon-reload
    systemctl enable hermes-gateway.service 2>/dev/null || true
    systemctl start hermes-gateway.service
    sleep 3
    log_ok "Gateway started via systemd"
else
    mkdir -p "$HERMES_HOME/logs"
    if ! pgrep -f "hermes.*gateway.*run" > /dev/null 2>&1; then
        nohup hermes gateway run > "$HERMES_HOME/logs/gateway.log" 2>&1 &
        sleep 2
        log_ok "Gateway started manually"
    else
        log_ok "Gateway already running"
    fi
fi

# =====================================================================
# Final status
# =====================================================================
log_step "Final status..."
echo ""
log_ok "Hermes Install/Update Complete"
echo "  Mode:       $INSTALL_MODE"
echo "  Hermes:     $HERMES_HOME"
echo "  Installed:  $(cat $HERMES_HOME/.install_state 2>/dev/null || echo 'unknown')"
echo ""
echo "Quick commands:"
echo "  hermes status        — check status"
echo "  hermes gateway run   — start gateway"
echo "  hermes config show   — view config"