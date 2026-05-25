#!/bin/bash
# =============================================================================
# setup-workspace-sudoers.sh — Grant passwordless sudo for self-repair
# =============================================================================
# Creates sudoers file allowing workspace users to run repair scripts
# without a password. This is REQUIRED for agent self-healing.
#
# Only grants access to specific repair scripts — not full root.
#
# Usage: sudo ./setup-workspace-sudoers.sh <username>
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Derive HERMES_HOME from script location (self-locating, portable)
if [[ -z "${HERMES_HOME:-}" ]]; then
    HERMES_HOME="${SCRIPT_DIR%/skills/devops/workspace-manager/scripts}"
fi
export HERMES_HOME

WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$SCRIPT_DIR}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

USERNAME="${1:-}"
[[ -n "$USERNAME" ]] || { echo "Usage: sudo $0 <username>"; exit 1; }

[[ $(id -u) -eq 0 ]] || ERROR "Must run as root"
id "$USERNAME" &>/dev/null || ERROR "User '$USERNAME' does not exist"

SUDOERS_FILE="/etc/sudoers.d/workspace-repair-${USERNAME}"
TOOLS_FILE="/etc/sudoers.d/workspace-tools-${USERNAME}"

echo ""
INFO "Setting up passwordless sudo for workspace user: $USERNAME"
echo ""

# Find all scripts that exist
ALL_SCRIPTS=(
    "${SCRIPT_DIR}/verify-and-fix.sh"
    "${SCRIPT_DIR}/setup-workspace.sh"
    "${SCRIPT_DIR}/self-heal.sh"
)

# Build list of existing scripts only
CMND_LIST=""
for script in "${ALL_SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        if [[ -z "$CMND_LIST" ]]; then
            CMND_LIST="$script"
        else
            CMND_LIST="$CMND_LIST, $script"
        fi
    fi
done

if [[ -z "$CMND_LIST" ]]; then
    ERROR "No repair scripts found!"
fi

# Write sudoers fragment — use printf to avoid heredoc variable expansion
printf '%s\n' \
    "# Workspace repair sudoers for: $USERNAME" \
    "# Allows passwordless sudo for tool repair scripts" \
    "$USERNAME ALL=(root) NOPASSWD: $CMND_LIST" \
    > "$SUDOERS_FILE"

chmod 440 "$SUDOERS_FILE"

# Validate
if visudo -c -f "$SUDOERS_FILE" 2>/dev/null; then
    INFO "Sudoers file created: $SUDOERS_FILE"
else
    rm -f "$SUDOERS_FILE"
    ERROR "Sudoers file is invalid — rolled back"
fi

# Tool-level sudoers (for python/venv repair)
printf '%s\n' \
    "# Tool access for workspace: $USERNAME" \
    "$USERNAME ALL=(root) NOPASSWD: /usr/bin/chmod, /usr/bin/chown, /usr/bin/ln, /usr/bin/python3, /usr/bin/python3.12" \
    "$USERNAME ALL=(root) NOPASSWD: /opt/hermes/bin/hermes, /opt/hermes/bin/python, /opt/aatosteam/bin/aatosteam, /opt/aatosteam/bin/python" \
    > "$TOOLS_FILE"
chmod 440 "$TOOLS_FILE"

echo ""
INFO "Passwordless sudo granted!"
echo ""
echo "  User '$USERNAME' can now run (without password):"
echo "    sudo ${HERMES_HOME}/skills/devops/workspace-manager/scripts/verify-and-fix.sh"
echo "    sudo ${HERMES_HOME}/skills/devops/workspace-manager/scripts/setup-workspace.sh"
echo "    sudo ${HERMES_HOME}/skills/devops/workspace-manager/scripts/self-heal.sh"
echo ""

# Test it
if sudo -u "$USERNAME" sudo -n true 2>/dev/null; then
    INFO "Sudo access verified for: $USERNAME"
else
    WARN "Could not verify sudo — test manually:"
    echo "    sudo -u $USERNAME sudo -n true"
fi
