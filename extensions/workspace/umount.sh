#!/bin/bash
# =====================================================================
# extensions/workspace/umount.sh — Unmount Workspace from /home/<user>
# =====================================================================
# Usage: bash actions.sh workspace umount <username>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/_common.sh"

USERNAME="${1:-}"
[ -z "$USERNAME" ] && { echo "Usage: bash actions.sh workspace umount <username>"; exit 1; }

if ! is_home_mounted "$USERNAME"; then
    log_warn "Not mounted: /home/$USERNAME"
    exit 0
fi

cleanup_home_mount "$USERNAME"
log_ok "Unmounted: /home/$USERNAME"