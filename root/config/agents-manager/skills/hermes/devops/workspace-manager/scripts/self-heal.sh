#!/bin/bash
# =============================================================================
# self-heal.sh — Agent-self-healing launcher (for workspace users)
# =============================================================================
# Run by a workspace agent to self-heal broken tools without human help.
# Uses NOPASSWD sudo to run repair scripts as root.
#
# Usage (as workspace user):
#   bash ~/self-heal.sh                    # check + repair
#   bash ~/self-heal.sh --check           # status only
#   bash ~/self-heal.sh --force           # force rebuild
#
# How it works:
#   1. Quick health check (runs tools directly — they work for all users)
#   2. If broken, uses sudo NOPASSWD to run verify-and-fix.sh as root
#   3. Reports result so agent knows repair outcome
# =============================================================================

set -uo pipefail

# Detect the actual user running this script.
# When run via `sudo -u testbot`: SUDO_USER=root, USER=testbot
# When run directly as testbot: USER=testbot, SUDO_USER=unset
# Use $USER (the effective user) not SUDO_USER (the invoker)
if [[ -n "${SUDO_USER:-}" ]]; then
    # Running via sudo -u <user>
    ACTUAL_USER="$SUDO_USER"
elif [[ -n "${USER:-}" ]]; then
    ACTUAL_USER="$USER"
else
    ACTUAL_USER="$(whoami)"
fi
WORKSPACE_NAME="${WORKSPACE_NAME:-$ACTUAL_USER}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Derive HERMES_HOME from script location (self-locating, portable)
if [[ -z "${HERMES_HOME:-}" ]]; then
    HERMES_HOME="${SCRIPT_DIR%/skills/devops/workspace-manager/scripts}"
fi
export HERMES_HOME

WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$SCRIPT_DIR}"

MODE="${1:-fix}"
[[ "$1" == "--check" ]] && MODE="check"
[[ "$1" == "--force" ]] && MODE="force"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }

echo ""
echo "============================================"
echo "  Self-Heal: $WORKSPACE_NAME (user: $ACTUAL_USER)"
echo "  Mode: $MODE"
echo "============================================"
echo ""

# =============================================================================
# Quick health check — runs tools directly
# Tools are in /usr/local/bin (symlinked to /opt/) so PATH is correct
# =============================================================================
quick_health_check() {
    local broken=0

    for tool in claude hermes aatosteam; do
        local ver
        ver=$($tool --version 2>&1 | head -1)
        if [[ $? -eq 0 && -n "$ver" ]]; then
            echo "  $tool: OK ($ver)"
        else
            echo "  $tool: BROKEN"
            broken=1
        fi
    done

    return $broken
}

# =============================================================================
# Can we sudo to root without a password?
# =============================================================================
can_sudo() {
    sudo -n true 2>/dev/null
}

# =============================================================================
# Find the repair script
# =============================================================================
find_repair_script() {
    for p in \
        "$SCRIPT_DIR/verify-and-fix.sh" \
        "${HERMES_HOME}/skills/devops/workspace-manager/scripts/verify-and-fix.sh"
    do
        [[ -f "$p" ]] && echo "$p" && return 0
    done
    return 1
}

# =============================================================================
# Main
# =============================================================================
main() {
    log_info "Health check for workspace: $WORKSPACE_NAME"
    echo ""

    if quick_health_check; then
        log_ok "All tools healthy — no repair needed"
        echo ""
        exit 0
    fi

    echo ""
    log_warn "Some tools are broken — attempting self-repair..."

    if can_sudo; then
        local script
        script=$(find_repair_script) || {
            log_error "Repair script not found"
            exit 1
        }

        log_info "Running sudo repair (script: $script)..."
        echo ""

        case "$MODE" in
            check)  sudo bash "$script" --check ;;
            force)  sudo bash "$script" --force ;;
            *)      sudo bash "$script" ;;
        esac

        local repair_exit=$?

        echo ""
        if [[ $repair_exit -eq 0 ]]; then
            log_ok "Self-repair completed"
            echo ""
            log_info "Final verification:"
            echo ""
            quick_health_check
        else
            log_error "Self-repair failed (exit code: $repair_exit)"
            exit 1
        fi
    else
        echo ""
        log_error "No sudo access — cannot repair."
        log_info "Grant passwordless sudo with:"
        echo ""
        echo "  sudo ${HERMES_HOME}/skills/devops/workspace-manager/scripts/setup-workspace-sudoers.sh $ACTUAL_USER"
        echo ""
        exit 1
    fi
}

main
