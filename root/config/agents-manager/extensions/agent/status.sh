#!/bin/bash
# =====================================================================
# extensions/agent/status.sh — Check Agent Status
# =====================================================================
# Usage: bash actions.sh agent status <hermes|claude>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $1"; }

AGENT="${1:-}"
[ -z "$AGENT" ] && { echo "Usage: bash actions.sh agent status <hermes|claude>"; exit 1; }

case "$AGENT" in
    hermes)
        if command -v hermes &>/dev/null; then
            log_ok "Hermes CLI: installed"
            hermes --version 2>/dev/null || true
            echo ""
            hermes status 2>&1 | head -30
        else
            log_error "Hermes CLI: not installed"
            exit 1
        fi
        ;;
    claude)
        if command -v claude &>/dev/null; then
            log_ok "Claude CLI: installed"
            claude --version 2>/dev/null || true
        else
            log_error "Claude CLI: not installed"
            exit 1
        fi
        ;;
    *)
        log_error "Unknown agent: $AGENT"
        echo "Available: hermes, claude"
        exit 1
        ;;
esac