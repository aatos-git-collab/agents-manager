#!/bin/bash
# =====================================================================
# extensions/workspace/create.sh — Create a Workspace
# =====================================================================
# Usage: bash actions.sh workspace create <username>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_BASE="/usr/local/share/agents-manager"
WORKSPACE_BASE="/workspaces"

source "${SCRIPT_DIR}/_common.sh"

USERNAME="${1:-}"
[ -z "$USERNAME" ] && { echo "Usage: bash actions.sh workspace create <username>"; exit 1; }

ws_dir="$WORKSPACE_BASE/$USERNAME"

# Check if workspace already exists
if [ -d "$ws_dir" ]; then
    log_error "Workspace already exists: $ws_dir"
    exit 1
fi

# Create system user if not exists
if ! id "$USERNAME" &>/dev/null; then
    log_info "Creating system user: $USERNAME"
    useradd -m -s /bin/bash "$USERNAME" 2>/dev/null || true
fi

log_info "Creating workspace: $ws_dir"

# Create directory structure
ensure_workspace_dirs "$ws_dir" "$USERNAME"
create_workspacerc "$ws_dir" "$USERNAME"

# Copy .env with API keys
env_src=$(get_env_source)
if [ -n "$env_src" ]; then
    log_info "Setting up workspace .env with API keys..."
    mkdir -p "$ws_dir/.hermes"
    cp "$env_src" "$ws_dir/.hermes/.env"
fi

# Setup bind mount
setup_home_mount "$USERNAME" "$ws_dir"

# Initialize hermes in workspace
log_step "Setting up Hermes..."
HERMES_HOME="$ws_dir/.hermes" bash "$GLOBAL_BASE/extensions/install/hermes.sh" --user 2>&1 | tail -3

# Initialize claude in workspace
log_step "Setting up Claude..."
bash "$GLOBAL_BASE/extensions/install/claude.sh" --user "$USERNAME" 2>&1 | tail -3

# Ensure ownership
chown -R "$USERNAME:$USERNAME" "$ws_dir"

log_ok "Workspace created: $ws_dir"
echo ""
echo "  Workspace: $ws_dir"
echo "  User: $USERNAME:$USERNAME"
echo "  Home: /home/$USERNAME"
echo ""
echo "  Quick access:"
echo "    su - $USERNAME     # Switch to user"
echo "    cd /home/$USERNAME # From root"