#!/bin/bash
# =====================================================================
# agents-manager install.sh — Global Shared Install
# =====================================================================
# All users share the same:
#   - Skills  (/usr/local/share/agents-manager/skills)
#   - Presets (/usr/local/share/agents-manager/presets)
#   - Scripts (/usr/local/share/agents-manager/scripts)
#
# Only per-user (private):
#   - ~/.hermes/.env  — Mattermost token, API keys
#
# Root updates the global base; all users auto-use the new version.
# =====================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_BASE="/usr/local/share/agents-manager"
LAUNCHER_DIR="/usr/local/bin"

usage() {
    cat << 'EOF'
Usage: bash install.sh [OPTIONS]

Options:
  --global        Set up global shared install
                  Copies to /usr/local/share/agents-manager
                  Creates launchers in /usr/local/bin/
                  Run once as root before any user runs agents.
  --user          Per-user setup: create ~/.hermes/.env from template
                  (Mattermost tokens are private to each user)
  --force-fresh   Re-run full install (bypasses smart update detection)
  --help          Show this help

On a fresh server (as root):
  sudo bash install.sh --global

As any Linux user:
  agents-manager          # → user setup (own ~/.hermes/.env)
  hermes-install          # → install/update hermes
EOF
}

MODE=""
FORCE_FRESH=false
for arg in "$@"; do
    case "$arg" in
        --global) MODE="global" ;;
        --user) MODE="user" ;;
        --force-fresh|--force) FORCE_FRESH=true ;;
        --help) usage; exit 0 ;;
    esac
done

# Auto-detect based on user
if [ -z "$MODE" ]; then
    if [ "$(id -u)" = "0" ]; then
        MODE="global"
    else
        MODE="user"
    fi
fi

# =====================================================================
# GLOBAL INSTALL — one-time root setup
# =====================================================================
do_global_install() {
    echo "========================================"
    echo "GLOBAL INSTALL — Setting up shared base"
    echo "========================================"
    echo "Global dir: $GLOBAL_BASE"
    echo "Launchers:  $LAUNCHER_DIR"

    echo ""
    echo ">>> Copying to $GLOBAL_BASE..."
    mkdir -p "$(dirname "$GLOBAL_BASE")"
    if [ -d "$GLOBAL_BASE" ]; then
        rsync -a --delete "$SCRIPT_DIR/" "$GLOBAL_BASE/"
    else
        cp -r "$SCRIPT_DIR" "$GLOBAL_BASE"
    fi

    # Shared read-write — all users can read AND write to shared resources
    chmod -R a+rwX "$GLOBAL_BASE"
    find "$GLOBAL_BASE" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

    # Global .env template (structure only, no secrets)
    mkdir -p "$GLOBAL_BASE/presets/hermes"
    if [ ! -f "$GLOBAL_BASE/presets/hermes/.env.global" ]; then
        cat > "$GLOBAL_BASE/presets/hermes/.env.global" << 'ENVEOF'
# =====================================================================
# Global Hermes config template
# Per-user ~/.hermes/.env overrides these with their private keys.
# =====================================================================
MINIMAX_ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic
LLM_MODEL=MiniMax-M2.7

# Per-user overrides (in ~/.hermes/.env):
# MATTERMOST_URL=https://mm.yourdomain.com
# MATTERMOST_TOKEN=your-token-here
# ANTHROPIC_API_KEY=your-key-here
ENVEOF
        chmod 644 "$GLOBAL_BASE/presets/hermes/.env.global"
        echo "  .env.global template created"
    fi

    echo ""
    echo ">>> Creating launchers..."

    cat > "$LAUNCHER_DIR/agents-manager" << 'LAUNCHER_EOF'
#!/bin/bash
# agents-manager launcher
#   root:  runs global install (update shared base)
#   user:  runs user setup (own ~/.hermes/.env)
set -e
GLOBAL_DIR="/usr/local/share/agents-manager"
if [ "$(id -u)" = "0" ]; then
    exec bash "$GLOBAL_DIR/install.sh" --global "$@"
else
    exec bash "$GLOBAL_DIR/install.sh" --user "$@"
fi
LAUNCHER_EOF
    chmod +x "$LAUNCHER_DIR/agents-manager"

    # Create hermes-install launcher
    cat > "$LAUNCHER_DIR/hermes-install" << 'EOF'
#!/bin/bash
set -e
GLOBAL_DIR="/usr/local/share/agents-manager"
exec bash "$GLOBAL_DIR/scripts/hermes-install.sh" --user "$@"
EOF
    chmod +x "$LAUNCHER_DIR/hermes-install"

    # Create claude-install launcher
    cat > "$LAUNCHER_DIR/claude-install" << 'EOF'
#!/bin/bash
set -e
GLOBAL_DIR="/usr/local/share/agents-manager"
exec bash "$GLOBAL_DIR/scripts/claude-install.sh" --user "$@"
EOF
    chmod +x "$LAUNCHER_DIR/claude-install"

    echo ""
    echo "========================================"
    echo "Global install complete!"
    echo "========================================"
    echo "Global: $GLOBAL_BASE"
    echo ""
    echo "All users (non-root) can now run:"
    echo "  agents-manager          → user setup (own ~/.hermes/.env)"
    echo "  hermes-install          → install/update hermes"
    echo "  claude-install          → install/update claude"
    echo ""
    echo "Shared (all users read+write):"
    echo "  $GLOBAL_BASE/skills"
    echo "  $GLOBAL_BASE/presets"
    echo ""
    echo "Private per user:"
    echo "  ~/.hermes/.env  — Mattermost token, API keys"
    echo "========================================"
}

# =====================================================================
# USER SETUP — create own private .env, use global skills directly
# =====================================================================
do_user_install() {
    local force_flag=""
    [ "$FORCE_FRESH" = true ] && force_flag="--force-fresh"

    echo "========================================"
    echo "USER SETUP"
    echo "========================================"
    echo "Global: $GLOBAL_BASE"
    echo "Home:   $HOME"

    # Ensure global skills/presets are readable+writable
    chmod -R a+rwX "$GLOBAL_BASE/skills" "$GLOBAL_BASE/presets" 2>/dev/null || true

    # Create own ~/.hermes/.env from template (Mattermost keys private)
    mkdir -p "$HOME/.hermes"
    if [ ! -f "$HOME/.hermes/.env" ]; then
        if [ -f "$GLOBAL_BASE/presets/hermes/.env.global" ]; then
            cp "$GLOBAL_BASE/presets/hermes/.env.global" "$HOME/.hermes/.env"
            echo "  Created ~/.hermes/.env — edit it to set your Mattermost/API keys"
        fi
    else
        echo "  ~/.hermes/.env exists — keeping existing"
    fi

    echo ""
    echo ">>> Installing Hermes (using global skills/presets)..."
    bash "$GLOBAL_BASE/scripts/hermes-install.sh" --user $force_flag

    echo ""
    echo "========================================"
    echo "User setup complete!"
    echo "========================================"
    echo "Hermes:  $HOME/.hermes/"
    echo "Skills:  $GLOBAL_BASE/skills  (shared, read+write)"
    echo ""
    echo "Edit ~/.hermes/.env to set your Mattermost token:"
    echo "  MATTERMOST_URL=https://mm.yourdomain.com"
    echo "  MATTERMOST_TOKEN=your-token"
    echo "========================================"
}

# =====================================================================
# DISPATCH
# =====================================================================
case "$MODE" in
    global) do_global_install ;;
    user)   do_user_install   ;;
esac