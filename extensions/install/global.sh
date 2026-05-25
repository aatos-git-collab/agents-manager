#!/bin/bash
# =====================================================================
# extensions/install/global.sh — Global Shared Install
# =====================================================================
# Sets up /usr/local/share/agents-manager and creates launchers.
# Run once as root before any user runs agents.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_BASE="/usr/local/share/agents-manager"

source "${SCRIPT_DIR}/_common.sh"

log_step "Global install..."
log_info "Global dir: $GLOBAL_BASE"
log_info "Launchers: /usr/local/bin"

# Sync to global base
log_step "Copying to $GLOBAL_BASE..."
sync_to_global "$SCRIPT_DIR/../.."

# Create .env.global template if missing
mkdir -p "$GLOBAL_BASE/presets/hermes"
if [ ! -f "$GLOBAL_BASE/presets/hermes/.env.global" ]; then
    cat > "$GLOBAL_BASE/presets/hermes/.env.global" << 'EOF'
# Global Hermes config template
MINIMAX_ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic
LLM_MODEL=MiniMax-M2.7
HERMES_TUI_THEME=dark
HERMES_TUI_LIGHT=false
ANTHROPIC_API_KEY=your_anthropic_api_key_here
EOF
    chmod 644 "$GLOBAL_BASE/presets/hermes/.env.global"
    log_ok ".env.global template created"
fi

# Create launchers
log_step "Creating launchers..."
create_launchers

log_ok "Global install complete!"
echo ""
echo "All users can now run:"
echo "  hermes-install  — Install/update Hermes"
echo "  claude-install  — Install/update Claude"
echo "  agents-manager  — Unified launcher"
echo "  actions         — Modular management"
echo ""
echo "Global: $GLOBAL_BASE"