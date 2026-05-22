#!/bin/bash
# =============================================================================
# create-workspace.sh - Create isolated passwordless user workspace
# =============================================================================
# Creates a Linux user with SSH key auth for AI agent operation.
# Then calls setup-workspace.sh to configure the workspace.
#
# Usage: sudo ./create-workspace.sh <username> [--reuse]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
STEP()    { echo -e "${BLUE}[STEP]${NC} $1"; }

REUSE=false
USERNAME=""

# Parse args properly — flags can come before or after username
for arg in "$@"; do
    case "$arg" in
        --reuse) REUSE=true ;;
        -h|--help) echo "Usage: sudo $0 <username> [--reuse]"; exit 0 ;;
        -*)
            # Skip unknown flags silently, or warn
            ;;
        *)
            USERNAME="$arg"
            ;;
    esac
done

if [[ -z "$USERNAME" ]]; then
    echo "Usage: sudo $0 <username> [--reuse]"
    echo "  <username>  : workspace name (Linux user)"
    echo "  --reuse     : reuse existing user"
    exit 1
fi

# =============================================================================
# PREFLIGHT
# =============================================================================
[[ $(id -u) -eq 0 ]] || ERROR "Must run as root"

if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    ERROR "Invalid username '$USERNAME'. Lowercase letters, numbers, underscore, hyphen only."
fi

SETUP_SCRIPT="$SCRIPT_DIR/setup-workspace.sh"
[[ -f "$SETUP_SCRIPT" ]] || ERROR "setup-workspace.sh not found"

# =============================================================================
# 1. CREATE OR REUSE USER
# =============================================================================
USER_HOME="/home/$USERNAME"

if id "$USERNAME" &>/dev/null; then
    if $REUSE; then
        INFO "User '$USERNAME' exists, reusing"
        # Ensure docker + sudo group membership on reuse
        if getent group docker >/dev/null 2>&1; then
            usermod -aG docker "$USERNAME" 2>/dev/null && INFO "Ensured docker group" || true
        fi
        if getent group sudo >/dev/null 2>&1; then
            usermod -aG sudo "$USERNAME" 2>/dev/null && INFO "Ensured sudo group" || true
        fi
    else
        ERROR "User '$USERNAME' exists. Use --reuse or: userdel -r $USERNAME"
    fi
else
    STEP "[1/6] Creating user: $USERNAME"
    useradd -m -s /bin/bash "$USERNAME" || ERROR "useradd failed"
    passwd -l "$USERNAME" &>/dev/null || true
    INFO "User created (password locked, SSH key only)"
fi

# Add user to docker group so they can run Docker without sudo
# Docker is required for all workspaces — fail if group doesn't exist
STEP "[1b/6] Adding user to docker group..."
getent group docker >/dev/null 2>&1 || ERROR "docker group does not exist on this system. Install Docker first."
usermod -aG docker "$USERNAME" && INFO "Added to docker group" || ERROR "Failed to add $USERNAME to docker group"

# Add user to sudo group for passwordless sudo
STEP "[1c/6] Adding user to sudo group (NOPASSWD)..."
if getent group sudo >/dev/null 2>&1; then
    usermod -aG sudo "$USERNAME" && INFO "Added to sudo group (NOPASSWD)" || WARN "Failed to add to sudo group"
else
    WARN "sudo group does not exist — skipping"
fi

mkdir -p "$USER_HOME"
mkdir -p "$USER_HOME/.hermes"

# =============================================================================
# 2. SSH KEYS
# =============================================================================
STEP "Setting up SSH keys..."
SSH_DIR="$USER_HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ -f "$SSH_DIR/id_ed25519" ]]; then
    INFO "SSH key already exists"
else
    ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -N "" -C "${USERNAME}@workspace" \
        || ERROR "ssh-keygen failed"
    INFO "Generated SSH key"
fi

if [[ -n "${2:-}" && -f "$2" ]]; then
    cat "$2" > "$SSH_DIR/authorized_keys"
    INFO "Added public key from: $2"
else
    cat "$SSH_DIR/id_ed25519.pub" > "$SSH_DIR/authorized_keys"
    echo ""
    echo "  Add this key to GitHub/GitLab:"
    echo "  ==========================================="
    cat "$SSH_DIR/id_ed25519.pub"
    echo "  ==========================================="
    echo ""
fi

chmod 600 "$SSH_DIR/authorized_keys"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

# =============================================================================
# 3. WORKSPACE DIRECTORIES
# =============================================================================
STEP "Creating directories..."
for dir in projects logs tests reports .config; do
    mkdir -p "$USER_HOME/$dir"
    chown "$USERNAME:$USERNAME" "$USER_HOME/$dir"
done
chmod 755 "$USER_HOME"

# =============================================================================
# 4. WORKSPACE REQUEST TOOL
# =============================================================================
REQUEST_SCRIPT="$SCRIPT_DIR/workspace-request.sh"
if [[ -f "$REQUEST_SCRIPT" ]]; then
    cp "$REQUEST_SCRIPT" "$USER_HOME/request.sh"
    chmod 700 "$USER_HOME/request.sh"
    chown "$USERNAME:$USERNAME" "$USER_HOME/request.sh"
    INFO "Request tool: ~/request.sh (for workspace → root communication)"
fi

# =============================================================================
# 5. CALL SETUP
# =============================================================================
STEP "Calling setup-workspace.sh..."
bash "$SETUP_SCRIPT" "$USERNAME"

INFO "Workspace '$USERNAME' ready!"
echo ""
echo "  Connect: sudo -u $USERNAME -i"
echo "  Verify:  sudo -u $USERNAME -i bash -lc 'claude --version'"
echo ""
echo "  Workspace agent commands:"
echo "    ~/request.sh workspace create <new-user>   # request new workspace"
echo "    ~/request.sh skill propose <skill>           # propose skill for review"
echo "    ~/request.sh status                         # check pending requests"
echo ""
echo "  Root commands:"
echo "    sudo $SCRIPT_DIR/infrastructure-manager.sh health"
echo ""
