#!/bin/bash
# =====================================================================
# extensions/workspace/mount.sh — Mount Workspace to /home/<user>
# =====================================================================
# Usage: bash actions.sh workspace mount <username>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_BASE="/workspaces"

source "${SCRIPT_DIR}/_common.sh"

USERNAME="${1:-}"
[ -z "$USERNAME" ] && { echo "Usage: bash actions.sh workspace mount <username>"; exit 1; }

ws_dir="$WORKSPACE_BASE/$USERNAME"

if [ ! -d "$ws_dir" ]; then
    log_error "Workspace does not exist: $ws_dir"
    exit 1
fi

if is_home_mounted "$USERNAME"; then
    log_warn "Already mounted: /home/$USERNAME"
    exit 0
fi

setup_home_mount "$USERNAME" "$ws_dir"
log_ok "Mounted: /home/$USERNAME → $ws_dir"