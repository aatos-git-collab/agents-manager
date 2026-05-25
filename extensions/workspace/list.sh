#!/bin/bash
# =====================================================================
# extensions/workspace/list.sh — List All Workspaces
# =====================================================================
# Usage: bash actions.sh workspace list

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

log_info "Workspaces in $WORKSPACE_BASE:"
echo ""

if [ ! -d "$WORKSPACE_BASE" ]; then
    log_warn "No workspaces found"
    exit 0
fi

for ws in "$WORKSPACE_BASE"/*/; do
    [ -d "$ws" ] || continue
    username=$(basename "$ws")
    owner=$(get_workspace_owner "$ws" 2>/dev/null || echo "unknown")
    mounted="no"
    is_home_mounted "$username" && mounted="yes"

    echo "  $username"
    echo "    Path:   $ws"
    echo "    Owner:  $owner"
    echo "    Mount:  $mounted"
    echo ""
done