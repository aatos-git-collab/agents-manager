#!/bin/bash
# =====================================================================
# extensions/workspace/umount.sh — Unmount Workspace from /home/<user>
# =====================================================================
# Usage: bash actions.sh workspace umount <username>

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
[ -z "$USERNAME" ] && { echo "Usage: bash actions.sh workspace umount <username>"; exit 1; }

if ! is_home_mounted "$USERNAME"; then
    log_warn "Not mounted: /home/$USERNAME"
    exit 0
fi

cleanup_home_mount "$USERNAME"
log_ok "Unmounted: /home/$USERNAME"