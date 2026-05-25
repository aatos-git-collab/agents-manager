#!/bin/bash
# =====================================================================
# extensions/workspace/list.sh — List All Workspaces
# =====================================================================
# Usage: bash actions.sh workspace list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_BASE="/workspaces"

source "${SCRIPT_DIR}/_common.sh"

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