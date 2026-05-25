#!/bin/bash
# =====================================================================
# actions.sh — Modular Agent & Workspace Management
# =====================================================================
# Single entry point for all agent/workspace operations.
# Delegates to extensions/ via standardized middleware pattern.
#
# Usage: bash actions.sh <extension> <command> [options]
#
# Examples:
#   bash actions.sh install global        # Global install
#   bash actions.sh install hermes        # Install hermes
#   bash actions.sh install claude        # Install claude
#   bash actions.sh workspace create jdoe
#   bash actions.sh workspace test jdoe
#   bash actions.sh workspace list
#   bash actions.sh agent status hermes
# =====================================================================

set -euo pipefail

# =====================================================================
# Configuration
# =====================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_BASE="/usr/local/share/agents-manager"
WORKSPACE_BASE="/workspaces"

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

# =====================================================================
# Middleware: Load extension common utilities
# =====================================================================
load_extension() {
    local ext_name="$1"
    local common_file="$SCRIPT_DIR/extensions/$ext_name/_common.sh"

    if [ -f "$common_file" ]; then
        source "$common_file"
    fi
}

# =====================================================================
# Middleware: Dispatch to extension command
# =====================================================================
dispatch() {
    local ext_name="$1"
    local cmd="$2"
    shift 2

    local ext_script="$SCRIPT_DIR/extensions/$ext_name/$cmd.sh"

    if [ ! -f "$ext_script" ]; then
        log_error "Unknown command: $ext_name $cmd"
        echo "Run 'bash actions.sh help' for usage"
        return 1
    fi

    # Source common utilities
    load_extension "$ext_name"

    # Execute the command
    bash "$ext_script" "$@"
}

# =====================================================================
# Help
# =====================================================================
show_help() {
    cat << 'EOF'
Usage: bash actions.sh <extension> <command> [options]

Extensions:
  install      Install agents (global, hermes, claude)
  workspace    Workspace management (create, delete, test, list, mount)
  agent        Agent management (status, install)

Examples:
  # Install
  bash actions.sh install global           # Global shared install
  bash actions.sh install hermes --user    # Install hermes (user mode)
  bash actions.sh install claude           # Install claude

  # Workspace
  bash actions.sh workspace create jdoe   # Create workspace
  bash actions.sh workspace test jdoe      # Test workspace
  bash actions.sh workspace list           # List workspaces
  bash actions.sh workspace delete jdoe    # Delete workspace
  bash actions.sh workspace mount jdoe     # Mount workspace
  bash actions.sh workspace umount jdoe    # Unmount workspace

  # Agent
  bash actions.sh agent status hermes     # Check Hermes status
  bash actions.sh agent status claude     # Check Claude status

  bash actions.sh help                    # Show this help
EOF
}

# =====================================================================
# Main Dispatcher
# =====================================================================
EXTENSION="${1:-}"
CMD="${2:-}"

case "$EXTENSION" in
    install|workspace|agent)
        dispatch "$EXTENSION" "$CMD" "${@:3}"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        log_error "Unknown extension: $EXTENSION"
        echo ""
        show_help
        exit 1
        ;;
esac