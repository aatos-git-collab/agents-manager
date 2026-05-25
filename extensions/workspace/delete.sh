#!/bin/bash
# =====================================================================
# extensions/workspace/delete.sh — Delete a Workspace
# =====================================================================
# Usage: bash actions.sh workspace delete <username>

set -euo pipefail

# Use SCRIPT_DIR from parent if passed (via actions.sh dispatch), otherwise calculate
if [ -n "${SCRIPT_DIR:-}" ]; then
    PROJECT_DIR="$SCRIPT_DIR"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
WORKSPACE_BASE="/workspaces"

source "${PROJECT_DIR}/extensions/workspace/_common.sh"

USERNAME="${1:-}"
[ -z "$USERNAME" ] && { echo "Usage: bash actions.sh workspace delete <username>"; exit 1; }

ws_dir="$WORKSPACE_BASE/$USERNAME"

# Validate workspace exists
if [ ! -d "$ws_dir" ]; then
    log_error "Workspace does not exist: $ws_dir"
    exit 1
fi

log_warn "Deleting workspace: $ws_dir"
read -p "  Are you sure? (yes/no): " confirm
[ "$confirm" != "yes" ] && { log_info "Cancelled"; exit 0; }

# Cleanup mount
cleanup_home_mount "$USERNAME"

# Delete workspace directory
rm -rf "$ws_dir"
log_ok "Workspace deleted: $ws_dir"