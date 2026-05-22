#!/bin/bash
# =============================================================================
# verify-and-fix.sh — Main Hermes self-healing checker
# =============================================================================
# Run by Main Hermes (root) to check and repair global tools.
# NOT for workspace agents — they just use the tools.
#
# Usage:
#   sudo ./verify-and-fix.sh           # check + repair
#   sudo ./verify-and-fix.sh --check   # status only
#   sudo ./verify-and-fix.sh --force   # force rebuild all
#
# Fully non-interactive — no prompts, no passwords needed.
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_UTILS="$SCRIPT_DIR/_tool-utils.sh"

# Source tool-utils for RUNTIME variables (used in echo statements below)
# shellcheck source=/dev/null
source "$TOOL_UTILS"

[[ ! -f "$TOOL_UTILS" ]] && { echo "ERROR: _tool-utils.sh not found"; exit 1; }
source "$TOOL_UTILS"

MODE="${1:-fix}"
[[ "$1" == "--check" ]] && MODE="check"
[[ "$1" == "--force" ]] && MODE="force"

[[ $(id -u) -eq 0 ]] || { echo "Must run as root"; exit 1; }

echo ""
echo "============================================"
echo "  Self-Healing Tool Check (Main Hermes)"
echo "  Mode: $MODE"
echo "============================================"
echo ""

# =============================================================================
# uv
# =============================================================================
echo "--- uv package manager ---"
_uv=$(get_uv)
if [[ -n "$_uv" ]]; then
    echo "  uv: $($_uv --version | cut -d' ' -f1-2) ($_uv)"
else
    echo "  uv: NOT FOUND"
    if [[ "$MODE" != "check" ]]; then
        ensure_uv >/dev/null 2>&1 && echo "  uv: installed" || echo "  uv: FAILED"
    fi
fi

# =============================================================================
# Claude
# =============================================================================
echo ""
echo "--- Claude Code ---"
check_claude; cs=$?
if [[ $cs -eq 0 ]]; then
    echo "  Status: OK"
    echo "  Binary: $(${CLAUDE_RUNTIME}/bin/claude --version 2>&1 | head -1)"
elif [[ "$MODE" == "check" ]]; then
    echo "  Status: $([[ $cs -eq 1 ]] && echo 'BROKEN' || echo 'MISSING')"
else
    echo "  Status: $([[ $cs -eq 1 ]] && echo 'BROKEN — repairing' || echo 'MISSING — installing')"
    repair_claude
fi

# =============================================================================
# Hermes
# =============================================================================
echo ""
echo "--- Hermes Agent ---"
check_hermes; hs=$?
if [[ $hs -eq 0 && "$MODE" != "force" ]]; then
    echo "  Status: OK"
    echo "  Binary: $(${HERMES_RUNTIME}/bin/hermes --version 2>&1 | head -1)"
elif [[ "$MODE" == "check" ]]; then
    echo "  Status: $([[ $hs -eq 1 ]] && echo 'BROKEN' || echo 'MISSING')"
else
    echo "  Status: $([[ $hs -eq 1 ]] && echo 'BROKEN — repairing' || echo 'MISSING — installing')"
    [[ "$MODE" == "force" ]] && echo "  Force rebuild requested"
    repair_hermes
fi

# =============================================================================
# AatosTeam
# =============================================================================
echo ""
echo "--- AatosTeam ---"
check_aatosteam; as=$?
if [[ $as -eq 0 && "$MODE" != "force" ]]; then
    echo "  Status: OK"
    echo "  Binary: $(${AATOSTEAM_RUNTIME}/bin/aatosteam --version 2>&1)"
elif [[ "$MODE" == "check" ]]; then
    echo "  Status: $([[ $as -eq 1 ]] && echo 'BROKEN' || echo 'MISSING')"
else
    echo "  Status: $([[ $as -eq 1 ]] && echo 'BROKEN — repairing' || echo 'MISSING — installing')"
    [[ "$MODE" == "force" ]] && echo "  Force rebuild requested"
    repair_aatosteam
fi

# =============================================================================
# Symlinks
# =============================================================================
echo ""
echo "--- Symlinks (/usr/local/bin) ---"
for tool in claude hermes aatosteam; do
    _target=""
    case $tool in
        claude)    _target="${CLAUDE_RUNTIME}/bin/claude" ;;
        hermes)    _target="${HERMES_RUNTIME}/bin/hermes" ;;
        aatosteam) _target="${AATOSTEAM_RUNTIME}/bin/aatosteam" ;;
    esac
    _sl="/usr/local/bin/$tool"
    if [[ -L "$_sl" && -e "$_sl" ]]; then
        echo "  $_sl -> $_target ✓"
    elif [[ -f "$_sl" ]]; then
        echo "  $_sl: exists (not symlink)"
    else
        echo "  $_sl: MISSING"
        if [[ "$MODE" != "check" && -f "$_target" ]]; then
            ln -sf "$_target" "$_sl" && echo "  $_sl: created"
        fi
    fi
done

# =============================================================================
# ai-migrate
# =============================================================================
echo ""
echo "--- ai-migrate (code migration tool) ---"
_check_ai_migrate() {
    command -v ai-migrate &>/dev/null || return 2
    ai-migrate --version &>/dev/null || return 1
    return 0
}
_check_ai_migrate; ams=$?
if [[ $ams -eq 0 && "$MODE" != "force" ]]; then
    echo "  Status: OK"
    echo "  Binary: $(ai-migrate --version 2>&1 | head -1)"
elif [[ "$MODE" == "check" ]]; then
    echo "  Status: $([[ $ams -eq 1 ]] && echo 'BROKEN' || echo 'MISSING')"
else
    echo "  Status: $([[ $ams -eq 1 ]] && echo 'BROKEN — repairing' || echo 'MISSING — installing')"
    pipx install --force /root/.hermes/tools/ai-migrate-tools/ai_migrate_tools-0.1.3/ &>/dev/null && echo "  Repaired: pipx install forced" || echo "  Repair FAILED"
fi

# =============================================================================
# Final report
# =============================================================================
echo ""
echo "============================================"
echo "  Final Status"
echo "============================================"
echo ""
echo "  Claude:    $(${CLAUDE_RUNTIME}/bin/claude --version 2>&1 | head -1)"
echo "  Hermes:    $(${HERMES_RUNTIME}/bin/hermes --version 2>&1 | head -1)"
echo "  AatosTeam: $(${AATOSTEAM_RUNTIME}/bin/aatosteam --version 2>&1)"
echo ""

if [[ "$MODE" == "check" ]]; then
    echo "Mode: CHECK ONLY"
else
    echo "Mode: FIX (repairs applied)"
fi
echo ""
