#!/bin/bash
# =============================================================================
# install.sh - Full server global setup (self-healing)
# =============================================================================
# One-shot global install. Sets up Claude, Hermes, AatosTeam globally.
# Uses shared _tool-utils.sh for self-healing repair logic.
#
# Idempotent — safe to re-run on already-configured server.
# After install, use create-workspace.sh to create workspaces.
#
# Usage:
#   sudo bash install.sh              # install everything
#   sudo bash install.sh --check     # verify only
#   sudo bash install.sh --force     # force reinstall all tools
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_SCRIPTS_DIR="$SKILLS_DIR/workspace-manager/scripts"

# Derive HERMES_HOME from script location (self-locating, portable)
HERMES_HOME="${SCRIPT_DIR%/skills/devops/global-install}"
export HERMES_HOME

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
STEP()    { echo -e "${BLUE}[STEP]${NC} $1"; }
OK()      { echo -e "${GREEN}[OK]${NC} $1"; }

MODE="${1:-install}"
[[ "$MODE" == "--check" ]] && MODE="check"
[[ "$MODE" == "--force" ]] && MODE="force"

[[ $(id -u) -eq 0 ]] || ERROR "Must run as root"

echo ""
echo "============================================"
echo "  Global Server Setup — Self-Healing"
echo "============================================"
echo ""

# =============================================================================
# Source shared tool utilities
# =============================================================================
TOOL_UTILS="$WORKSPACE_SCRIPTS_DIR/_tool-utils.sh"
if [[ -f "$TOOL_UTILS" ]]; then
    source "$TOOL_UTILS"
else
    ERROR "_tool-utils.sh not found at $TOOL_UTILS"
fi

# =============================================================================
# 1. System packages
# =============================================================================
STEP "[1/5] System packages..."
apt update -qq 2>/dev/null || true
apt install -y python3.12 python3.12-venv git curl tmux 2>/dev/null || {
    WARN "Some packages failed (may already be installed)"
}
OK "System packages ready"

# =============================================================================
# 2. uv package manager
# =============================================================================
STEP "[2/5] uv package manager..."
UV_BIN=$(get_uv)
if [[ -z "$UV_BIN" ]]; then
    INFO "Installing uv..."
    UV_BIN=$(ensure_uv)
    OK "uv installed at $UV_BIN"
else
    OK "uv already installed: $($UV_BIN --version | cut -d' ' -f1-2)"
fi

# =============================================================================
# 3. Claude Code
# =============================================================================
STEP "[3/5] Claude Code..."
if [[ "$MODE" == "check" ]]; then
    check_claude; cs=$?
    if [[ $cs -eq 0 ]]; then
        OK "Claude: $(/opt/claude/bin/claude --version 2>&1 | head -1)"
    elif [[ $cs -eq 1 ]]; then
        WARN "Claude is broken"
    else
        WARN "Claude not installed"
    fi
else
    check_claude; cs=$?
    if [[ $cs -eq 2 ]]; then
        INFO "Installing Claude..."
        repair_claude || true
    elif [[ $cs -eq 1 || "$MODE" == "force" ]]; then
        INFO "Reinstalling Claude (broken or --force)..."
        repair_claude || true
    else
        OK "Claude: $(/opt/claude/bin/claude --version 2>&1 | head -1)"
    fi
fi

# =============================================================================
# 4. Hermes Agent
# =============================================================================
STEP "[4/5] Hermes Agent..."
if [[ "$MODE" == "check" ]]; then
    check_hermes; hs=$?
    if [[ $hs -eq 0 ]]; then
        OK "Hermes: $(/opt/hermes/bin/hermes --version 2>&1 | head -1)"
    elif [[ $hs -eq 1 ]]; then
        WARN "Hermes is broken"
    else
        WARN "Hermes not installed"
    fi
else
    check_hermes; hs=$?
    if [[ $hs -eq 2 ]]; then
        INFO "Installing Hermes..."
        repair_hermes || true
    elif [[ $hs -eq 1 || "$MODE" == "force" ]]; then
        INFO "Reinstalling Hermes (broken or --force)..."
        repair_hermes || true
    else
        OK "Hermes: $(/opt/hermes/bin/hermes --version 2>&1 | head -1)"
    fi
fi

# =============================================================================
# 5. AatosTeam
# =============================================================================
STEP "[5/5] AatosTeam..."
if [[ "$MODE" == "check" ]]; then
    check_aatosteam; as=$?
    if [[ $as -eq 0 ]]; then
        OK "AatosTeam: $(/opt/aatosteam/bin/aatosteam --version 2>&1)"
    elif [[ $as -eq 1 ]]; then
        WARN "AatosTeam is broken"
    else
        WARN "AatosTeam not installed"
    fi
else
    check_aatosteam; as=$?
    if [[ $as -eq 2 ]]; then
        INFO "Installing AatosTeam..."
        repair_aatosteam || true
    elif [[ $as -eq 1 || "$MODE" == "force" ]]; then
        INFO "Reinstalling AatosTeam (broken or --force)..."
        repair_aatosteam || true
    else
        OK "AatosTeam: $(/opt/aatosteam/bin/aatosteam --version 2>&1)"
    fi
fi

# =============================================================================
# Vault-Security (optional — two-factor encrypted secrets for agents)
# Vault works in-place from skill source, no intermediate copy needed.
# =============================================================================

# =============================================================================
# Fix symlinks in /usr/local/bin
# =============================================================================
VAULT_INSTALL="${HERMES_HOME}/skills/devops/workspace-manager/vault/scripts/vault-install.sh"
VAULT_SELF_HEAL="${HERMES_HOME}/skills/devops/workspace-manager/vault/scripts/vault-self-heal.sh"

STEP "[vault] Vault-Security..."
if [[ -f "$VAULT_SELF_HEAL" ]]; then
    if bash "$VAULT_SELF_HEAL" --check &>/dev/null; then
        OK "Vault-Security already running"
    else
        INFO "Vault-Security not running — installing..."
        if bash "$VAULT_INSTALL" 2>&1 | tail -5; then
            OK "Vault-Security installed"
        else
            WARN "Vault-Security install failed — non-critical, skipping"
        fi
    fi
else
    INFO "Vault not in skills — skipping"
fi
for tool in claude hermes aatosteam; do
    local target=""
    case $tool in
        claude)    target="/opt/claude/bin/claude" ;;
        hermes)    target="/opt/hermes/bin/hermes" ;;
        aatosteam) target="/opt/aatosteam/bin/aatosteam" ;;
    esac
    if [[ -f "$target" ]]; then
        ln -sf "$target" "/usr/local/bin/$tool" 2>/dev/null || true
    fi
done
OK "Symlinks ready"

# =============================================================================
# Root's internal skills management dirs (staging, rejected, etc.)
# =============================================================================
STEP "[skills] Root skills management dirs..."
mkdir -p "${HERMES_HOME}/skills/staging" "${HERMES_HOME}/skills/rejected" "${HERMES_HOME}/skills/local"
chmod 700 "${HERMES_HOME}/skills" 2>/dev/null || true
chmod 755 "${HERMES_HOME}/skills/staging" "${HERMES_HOME}/skills/rejected" "${HERMES_HOME}/skills/local" 2>/dev/null || true
OK "Root skills at ${HERMES_HOME}/skills/"

# =============================================================================
# Global skills directory (world-readable, no symlinks needed)
# =============================================================================
STEP "[skills] Global skills directory..."
if [[ ! -d /opt/skills ]] || [[ -z "$(ls -A /opt/skills 2>/dev/null)" ]]; then
    # First install — populate /opt/skills from HERMES_HOME/skills if available
    if [[ -d "${HERMES_HOME}/skills/global" ]]; then
        cp -r "${HERMES_HOME}/skills/global"/* /opt/skills/ 2>/dev/null || true
    fi
fi
mkdir -p /opt/skills
chmod -R 755 /opt/skills
chown -R root:root /opt/skills
OK "Global skills at /opt/skills/ (world-readable)"

# =============================================================================
# Final report
# =============================================================================
echo ""
echo "============================================"
echo "  Installation Report"
echo "============================================"
echo ""
echo "  Claude:    $(/opt/claude/bin/claude --version 2>&1 | head -1 2>/dev/null || echo 'MISSING')"
echo "  Hermes:    $(/opt/hermes/bin/hermes --version 2>&1 | head -1 2>/dev/null || echo 'MISSING')"
echo "  AatosTeam: $(/opt/aatosteam/bin/aatosteam --version 2>&1 2>/dev/null || echo 'MISSING')"
echo ""
echo "  /usr/local/bin/claude     : $(ls -la /usr/local/bin/claude 2>/dev/null | grep -o '/opt/[^ ]*' || echo 'MISSING')"
echo "  /usr/local/bin/hermes     : $(ls -la /usr/local/bin/hermes 2>/dev/null | grep -o '/opt/[^ ]*' || echo 'MISSING')"
echo "  /usr/local/bin/aatosteam  : $(ls -la /usr/local/bin/aatosteam 2>/dev/null | grep -o '/opt/[^ ]*' || echo 'MISSING')"
echo ""
echo "  Global skills:  /opt/skills/ (world-readable)"
echo ""

# Non-root test
echo "  Non-root test:"
for tuser in nobody testuser; do
    if id "$tuser" &>/dev/null; then
        r=$(su -s /bin/bash "$tuser" -c 'claude --version 2>&1 | head -1' 2>/dev/null)
        echo "    as $tuser: claude = ${r:-FAIL}"
        r=$(su -s /bin/bash "$tuser" -c 'hermes --version 2>&1 | head -1' 2>/dev/null)
        echo "    as $tuser: hermes = ${r:-FAIL}"
        r=$(su -s /bin/bash "$tuser" -c 'aatosteam --version 2>&1' 2>/dev/null)
        echo "    as $tuser: aatosteam = ${r:-FAIL}"
        break
    fi
done

echo ""
echo "============================================"
echo ""
INFO "Next: Create first workspace:"
echo "  sudo ${HERMES_HOME}/skills/devops/workspace-manager/scripts/create-workspace.sh engineering"
echo ""
echo "Self-healing check anytime:"
echo "  sudo ${HERMES_HOME}/skills/devops/workspace-manager/scripts/verify-and-fix.sh"
echo ""
