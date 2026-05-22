#!/bin/bash
# =============================================================================
# _tool-utils.sh - Self-healing tool verification and repair
# =============================================================================
# Shared functions for Main Hermes to verify and repair global tools.
# Source this from other scripts or run standalone.
#
# SELF-HEALING OWNER: Main Hermes (root) — NOT workspace agents.
# Workspace agents just use the tools, they don't repair them.
#
# Usage:
#   source /path/to/_tool-utils.sh
#   verify_and_fix_all    # returns 0=ok, 1=repaired, 2=failed
#   verify_and_fix_all --force   # force rebuild
#
# Non-interactive: all operations are fully automated (no prompts).
# =============================================================================

# Source guard
[[ "${_TOOL_UTILS_SOURCED:-}" == "yes" ]] && return 0
_TOOL_UTILS_SOURCED=yes

# Non-interactive env
export DEBIAN_FRONTEND=noninteractive
export MAKEFLAGS="-j$(nproc)"

# =============================================================================
# CONFIG
# =============================================================================
# HERMES_HOME — derived from script location (self-locating, portable)
# This is the root of THIS hermes installation, not /root/.hermes specifically
if [[ -z "${HERMES_HOME:-}" ]]; then
    # Derive from the script's own path: .../workspace-manager/scripts/_tool-utils.sh
    SCRIPT_DIR_UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    HERMES_HOME="${SCRIPT_DIR_UTILS%/skills/devops/workspace-manager/scripts}"
fi
export HERMES_HOME

# Tool source repos (git clones) — live inside HERMES_HOME/tools/
HERMES_SOURCE="${HERMES_SOURCE:-${HERMES_HOME}/tools/hermes-agent}"
AATOSTEAM_SOURCE="${AATOSTEAM_SOURCE:-${HERMES_HOME}/tools/aatosteam}"

# Installed runtimes — live in /opt/ (world-readable, non-reset, self-contained)
HERMES_RUNTIME="${HERMES_RUNTIME:-/opt/hermes}"
AATOSTEAM_RUNTIME="${AATOSTEAM_RUNTIME:-/opt/aatosteam}"
CLAUDE_RUNTIME="${CLAUDE_RUNTIME:-/opt/claude}"

# =============================================================================
# LOGGING
# =============================================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
FIX()     { echo -e "${CYAN}[FIX]${NC} $1"; }
TOK()      { echo -e "${GREEN}[OK]${NC} $1"; }
FAIL()    { echo -e "${RED}[FAIL]${NC} $1"; }

# =============================================================================
# UV HELPER — non-interactive install
# =============================================================================
get_uv() {
    if command -v uv &>/dev/null; then
        echo "$(command -v uv)"
    elif [[ -x /root/.local/bin/uv ]]; then
        echo "/root/.local/bin/uv"
    elif [[ -x /opt/uv/bin/uv ]]; then
        echo "/opt/uv/bin/uv"
    else
        return 1
    fi
}

ensure_uv() {
    local uv_bin
    uv_bin=$(get_uv) && echo "$uv_bin" && return 0

    INFO "Installing uv (non-interactive)..."
    # Non-interactive uv install
    curl -LsSf https://astral.sh/uv/install.sh 2>/dev/null | \
        UV_INSTALL_DIR="/opt/uv" sh -s -- --yes 2>/dev/null || \
        (curl -LsSf https://astral.sh/uv/install.sh 2>/dev/null | sh 2>/dev/null)

    export PATH="$HOME/.local/bin:$PATH"
    uv_bin=$(get_uv) || return 1
    echo "$uv_bin"
}

# =============================================================================
# TOOL STATUS CHECK — returns 0=ok, 1=broken, 2=missing
# =============================================================================

check_claude() {
    if [[ ! -f ${CLAUDE_RUNTIME}/bin/claude ]]; then
        return 2
    fi
    ${CLAUDE_RUNTIME}/bin/claude --version &>/dev/null || return 1
    return 0
}

check_hermes() {
    if [[ ! -f ${HERMES_RUNTIME}/bin/hermes ]]; then
        return 2
    fi
    ${HERMES_RUNTIME}/bin/hermes --version &>/dev/null || return 1
    return 0
}

check_aatosteam() {
    if [[ ! -f ${AATOSTEAM_RUNTIME}/bin/aatosteam ]]; then
        return 2
    fi
    ${AATOSTEAM_RUNTIME}/bin/aatosteam --version &>/dev/null || return 1
    return 0
}

# =============================================================================
# TOOL REPAIR — fully non-interactive
# =============================================================================

repair_claude() {
    FIX "Repairing Claude..."

    mkdir -p ${CLAUDE_RUNTIME}/bin

    local src=""
    # Find Claude source
    if [[ -f /root/.local/share/claude/versions/*/claude ]] 2>/dev/null; then
        src=$(find /root/.local/share/claude/versions/*/claude -maxdepth 1 -type f 2>/dev/null | head -1)
    elif [[ -f ${CLAUDE_RUNTIME}/bin/claude ]] && ${CLAUDE_RUNTIME}/bin/claude --version &>/dev/null; then
        src="${CLAUDE_RUNTIME}/bin/claude"
    fi

    if [[ -n "$src" && -f "$src" ]]; then
        cp "$src" ${CLAUDE_RUNTIME}/bin/claude
        chmod +x ${CLAUDE_RUNTIME}/bin/claude
        TOK "Claude copied from: $src"
    else
        ERROR "Claude source not found. Install Claude first."
        return 1
    fi

    # Fix symlink
    ln -sf ${CLAUDE_RUNTIME}/bin/claude /usr/local/bin/claude 2>/dev/null || true

    if ${CLAUDE_RUNTIME}/bin/claude --version &>/dev/null; then
        TOK "Claude: $(${CLAUDE_RUNTIME}/bin/claude --version 2>&1 | head -1)"
        return 0
    else
        FAIL "Claude repair failed"
        return 1
    fi
}

repair_hermes() {
    FIX "Repairing Hermes Agent..."

    if [[ ! -d "$HERMES_SOURCE" ]]; then
        ERROR "Hermes source not found at $HERMES_SOURCE"
        return 1
    fi

    local uv_bin
    uv_bin=$(get_uv) || { ensure_uv >/dev/null 2>&1; uv_bin=$(get_uv); }
    [[ -z "$uv_bin" ]] && { ERROR "uv not available"; return 1; }

    # Check if venv is corrupt
    if [[ -d ${HERMES_RUNTIME} ]]; then
        if ! ${HERMES_RUNTIME}/bin/python -c "import hermes_cli" &>/dev/null; then
            FIX "Hermes venv corrupt — rebuilding..."
            rm -rf ${HERMES_RUNTIME}
        fi
    fi

    if [[ ! -d ${HERMES_RUNTIME} ]]; then
        INFO "Creating Hermes venv..."
        "$uv_bin" venv ${HERMES_RUNTIME} --python python3.12 2>&1 | tail -1 || {
            ERROR "Failed to create Hermes venv"
            return 1
        }
    fi

    INFO "Installing Hermes..."
    "$uv_bin" pip install "$HERMES_SOURCE" \
        --python ${HERMES_RUNTIME}/bin/python \
        --reinstall \
        2>&1 | grep -v "^$" | tail -3

    # Recreate launcher (fixes shebang after venv rebuild)
    cat > ${HERMES_RUNTIME}/bin/hermes << 'EOF'
#!${HERMES_RUNTIME}/bin/python
import sys
sys.path.insert(0, '${HERMES_RUNTIME}/lib/python3.12/site-packages')
from hermes_cli.main import main
if __name__ == "__main__":
    main()
EOF
    chmod +x ${HERMES_RUNTIME}/bin/hermes
    ln -sf ${HERMES_RUNTIME}/bin/hermes /usr/local/bin/hermes 2>/dev/null || true

    if ${HERMES_RUNTIME}/bin/hermes --version &>/dev/null; then
        TOK "Hermes: $(${HERMES_RUNTIME}/bin/hermes --version 2>&1 | head -1)"
        return 0
    else
        FAIL "Hermes repair failed"
        return 1
    fi
}

repair_aatosteam() {
    FIX "Repairing AatosTeam..."

    if [[ ! -d "$AATOSTEAM_SOURCE" ]]; then
        ERROR "AatosTeam source not found at $AATOSTEAM_SOURCE"
        return 1
    fi

    local uv_bin
    uv_bin=$(get_uv) || { ensure_uv >/dev/null 2>&1; uv_bin=$(get_uv); }
    [[ -z "$uv_bin" ]] && { ERROR "uv not available"; return 1; }

    # Check if venv is corrupt
    if [[ -d ${AATOSTEAM_RUNTIME} ]]; then
        if ! ${AATOSTEAM_RUNTIME}/bin/python -c "import aatosteam" &>/dev/null; then
            FIX "AatosTeam venv corrupt — rebuilding..."
            rm -rf ${AATOSTEAM_RUNTIME}
        fi
    fi

    if [[ ! -d ${AATOSTEAM_RUNTIME} ]]; then
        INFO "Creating AatosTeam venv..."
        "$uv_bin" venv ${AATOSTEAM_RUNTIME} --python python3.12 2>&1 | tail -1 || {
            ERROR "Failed to create AatosTeam venv"
            return 1
        }
    fi

    INFO "Installing AatosTeam..."
    "$uv_bin" pip install "$AATOSTEAM_SOURCE" \
        --python ${AATOSTEAM_RUNTIME}/bin/python \
        --reinstall \
        2>&1 | grep -v "^$" | tail -3

    # Recreate launcher
    cat > ${AATOSTEAM_RUNTIME}/bin/aatosteam-bin << 'EOF'
#!${AATOSTEAM_RUNTIME}/bin/python
from aatosteam.cli.commands import app
app()
EOF
    chmod +x ${AATOSTEAM_RUNTIME}/bin/aatosteam-bin
    ln -sf ${AATOSTEAM_RUNTIME}/bin/aatosteam-bin /usr/local/bin/aatosteam 2>/dev/null || true

    # MCP server
    if [[ -d ${AATOSTEAM_RUNTIME}/lib/python*/site-packages/aatosteam/mcp ]] || \
       [[ -f ${AATOSTEAM_RUNTIME}/lib/python*/site-packages/aatosteam/mcp/server.py ]]; then
        cat > ${AATOSTEAM_RUNTIME}/bin/aatosteam-mcp-bin << 'EOF'
#!${AATOSTEAM_RUNTIME}/bin/python
from aatosteam.mcp.server import main
main()
EOF
        chmod +x ${AATOSTEAM_RUNTIME}/bin/aatosteam-mcp-bin
        ln -sf ${AATOSTEAM_RUNTIME}/bin/aatosteam-mcp-bin /usr/local/bin/aatosteam-mcp 2>/dev/null || true
    fi

    if ${AATOSTEAM_RUNTIME}/bin/aatosteam --version &>/dev/null; then
        TOK "AatosTeam: $(${AATOSTEAM_RUNTIME}/bin/aatosteam --version 2>&1)"
        return 0
    else
        FAIL "AatosTeam repair failed"
        return 1
    fi
}

# =============================================================================
# AI-MIGRATE (pipx global install)
# =============================================================================
AI_MIGRATE_RUNTIME="${AI_MIGRATE_RUNTIME:-/root/.local/share/pipx/venvs/ai-migrate-tools}"

check_ai_migrate() {
    if [[ ! -f /root/.local/bin/ai-migrate ]]; then
        return 2
    fi
    /root/.local/bin/ai-migrate --help &>/dev/null || return 1
    return 0
}

repair_ai_migrate() {
    FIX "Repairing ai-migrate-tools..."

    # Ensure pipx is available
    if ! command -v pipx &>/dev/null; then
        INFO "Installing pipx..."
        pipx_install=$(mktemp)
        curl -LsSf https://pipx.app/install.sh 2>/dev/null | python3 - --path /root/.local/bin 2>/dev/null || \
            python3 -m pip install pipx --break-system-packages 2>/dev/null
    fi

    # Install or reinstall ai-migrate-tools
    if [[ -d ${AI_MIGRATE_RUNTIME} ]]; then
        if ! ${AI_MIGRATE_RUNTIME}/bin/python -c "import ai_migrate" &>/dev/null; then
            FIX "ai-migrate venv corrupt — reinstalling..."
            pipx uninstall ai-migrate-tools 2>/dev/null || true
        fi
    fi

    pipx install ai-migrate-tools --force 2>&1 | tail -3

    if /root/.local/bin/ai-migrate --help &>/dev/null; then
        TOK "ai-migrate: $(/root/.local/bin/ai-migrate --version 2>&1 || echo 'ok')"
        return 0
    else
        FAIL "ai-migrate repair failed"
        return 1
    fi
}

# =============================================================================
# FIX BROKEN SYMLINKS
# =============================================================================
repair_symlinks() {
    local fixed=0
    for tool in claude hermes aatosteam ai-migrate; do
        local target=""
        case $tool in
            claude)    target="${CLAUDE_RUNTIME}/bin/claude" ;;
            hermes)    target="${HERMES_RUNTIME}/bin/hermes" ;;
            aatosteam) target="${AATOSTEAM_RUNTIME}/bin/aatosteam" ;;
            ai-migrate) target="/root/.local/bin/ai-migrate" ;;
        esac

        local symlink="/usr/local/bin/$tool"
        if [[ -L "$symlink" && ! -e "$symlink" ]]; then
            FIX "Broken symlink: $symlink -> $(readlink $symlink)"
            if [[ -f "$target" ]]; then
                ln -sf "$target" "$symlink"
                TOK "Fixed: $symlink"
                ((fixed++))
            fi
        elif [[ ! -f "$symlink" && -f "$target" ]]; then
            ln -sf "$target" "$symlink"
            FIX "Created: $symlink -> $target"
            ((fixed++))
        fi
    done
    [[ $fixed -gt 0 ]] && return 0 || return 1
}

# =============================================================================
# MAIN SELF-HEALING FUNCTION
# =============================================================================
# Returns: 0=all ok, 1=some repaired, 2=critical failure
verify_and_fix_all() {
    local fixed_any=0

    INFO "=== Self-Healing Tool Check ==="

    # Fix broken symlinks first
    repair_symlinks 2>/dev/null || true

    # Claude
    check_claude; cs=$?
    if [[ $cs -eq 0 ]]; then
        TOK "Claude: $(${CLAUDE_RUNTIME}/bin/claude --version 2>&1 | head -1)"
    elif [[ $cs -eq 1 ]]; then
        WARN "Claude broken — repairing..."
        repair_claude && ((fixed_any++))
    else
        FIX "Claude missing — installing..."
        repair_claude && ((fixed_any++))
    fi

    # Hermes
    check_hermes; hs=$?
    if [[ $hs -eq 0 ]]; then
        TOK "Hermes: $(${HERMES_RUNTIME}/bin/hermes --version 2>&1 | head -1)"
    elif [[ $hs -eq 1 ]]; then
        WARN "Hermes broken — repairing..."
        repair_hermes && ((fixed_any++))
    else
        FIX "Hermes missing — installing..."
        repair_hermes && ((fixed_any++))
    fi

    # AatosTeam
    check_aatosteam; as=$?
    if [[ $as -eq 0 ]]; then
        TOK "AatosTeam: $(${AATOSTEAM_RUNTIME}/bin/aatosteam --version 2>&1)"
    elif [[ $as -eq 1 ]]; then
        WARN "AatosTeam broken — repairing..."
        repair_aatosteam && ((fixed_any++))
    else
        FIX "AatosTeam missing — installing..."
        repair_aatosteam && ((fixed_any++))
    fi

    # uv
    if [[ -z "$(get_uv)" ]]; then
        WARN "uv missing — installing..."
        ensure_uv >/dev/null 2>&1 && ((fixed_any++))
    fi

    # ai-migrate
    check_ai_migrate; ms=$?
    if [[ $ms -eq 0 ]]; then
        TOK "ai-migrate: ok"
    elif [[ $ms -eq 1 ]]; then
        WARN "ai-migrate broken — repairing..."
        repair_ai_migrate && ((fixed_any++))
    else
        FIX "ai-migrate missing — installing..."
        repair_ai_migrate && ((fixed_any++))
    fi

    echo ""
    if [[ $fixed_any -gt 0 ]]; then
        WARN "Repaired $fixed_any tool(s)"
        echo ""
        INFO "Final status:"
        echo "  Claude:    $(${CLAUDE_RUNTIME}/bin/claude --version 2>&1 | head -1)"
        echo "  Hermes:    $(${HERMES_RUNTIME}/bin/hermes --version 2>&1 | head -1)"
        echo "  AatosTeam: $(${AATOSTEAM_RUNTIME}/bin/aatosteam --version 2>&1)"
        echo ""
        return 1
    else
        TOK "All tools healthy"
        return 0
    fi
}

# =============================================================================
# STANDALONE MODE
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $(id -u) -eq 0 ]] || { echo "Must run as root"; exit 1; }
    verify_and_fix_all
fi
