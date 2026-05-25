#!/bin/bash
# =====================================================================
# extensions/workspace/_common.sh — Shared Workspace Utilities
# =====================================================================

GLOBAL_BASE="${GLOBAL_BASE:-/usr/local/share/agents-manager}"
WORKSPACE_BASE="${WORKSPACE_BASE:-/workspaces}"

# =====================================================================
# Color output (from actions.sh)
# =====================================================================
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
# Validate workspace exists
# =====================================================================
validate_workspace() {
    local username="$1"
    local ws_dir="$WORKSPACE_BASE/$username"

    if [ ! -d "$ws_dir" ]; then
        log_error "Workspace does not exist: $ws_dir"
        return 1
    fi

    echo "$ws_dir"
}

# =====================================================================
# Check workspace ownership
# =====================================================================
get_workspace_owner() {
    local ws_dir="$1"
    stat -c '%U:%G' "$ws_dir" 2>/dev/null
}

# =====================================================================
# Ensure workspace has required directories
# =====================================================================
ensure_workspace_dirs() {
    local ws_dir="$1"
    local username="$2"

    mkdir -p "$ws_dir"/{projects,skills,memories,sessions,tasks,logs,.hermes}
    chown -R "$username:$username" "$ws_dir"
    chmod -R 755 "$ws_dir"
}

# =====================================================================
# Create workspace .workspacerc config
# =====================================================================
create_workspacerc() {
    local ws_dir="$1"
    local username="$2"

    cat > "$ws_dir/.workspacerc" << EOF
# Workspace configuration
WORKSPACE_USER="$username"
WORKSPACE_ROOT="$ws_dir"
WORKSPACE_CREATED="$(date -Iseconds)"
AGENTS_HOME="$GLOBAL_BASE"
HERMES_HOME="$ws_dir/.hermes"
CLAUDE_HOME="$ws_dir/.claude"
EOF
}

# =====================================================================
# Setup bind mount or symlink for /home/<user>
# =====================================================================
setup_home_mount() {
    local username="$1"
    local ws_dir="$2"

    # systemd mode: create proper mount unit
    if [ -d /run/systemd/system ]; then
        local mount_file="/etc/systemd/system/home-${username}.mount"

        if [ ! -f "$mount_file" ]; then
            cat > "/tmp/home-${username}.mount" << EOF
[Unit]
Description=Bind mount workspace for $username
After=local-fs.target

[Mount]
What=$ws_dir
Where=/home/$username
Type=none
Options=bind,rw

[Install]
WantedBy=multi-user.target
EOF
            cp "/tmp/home-${username}.mount" "/etc/systemd/system/"
            systemctl daemon-reload
            systemctl enable "home-${username}.mount" 2>/dev/null || true
            systemctl start "home-${username}.mount" 2>/dev/null || true
            log_info "Bound /home/$username → $ws_dir (systemd)"
        fi
    else
        # Container mode: bind mount or symlink
        if [ ! -d "/home/$username" ] || [ ! -L "/home/$username" ]; then
            # Backup existing home if it's a real directory
            if [ -d "/home/$username" ] && [ ! -L "/home/$username" ]; then
                mv "/home/$username" "/home/${username}.bak" 2>/dev/null || true
            fi
            mkdir -p "/home/$username"
            if ! mount --bind "$ws_dir" "/home/$username" 2>/dev/null; then
                log_warn "Bind mount failed, using symlink fallback"
                ln -sf "$ws_dir" "/home/$username"
            fi
            log_info "Bound /home/$username → $ws_dir (container mode)"
        fi
    fi
}

# =====================================================================
# Cleanup home mount on workspace delete
# =====================================================================
cleanup_home_mount() {
    local username="$1"

    if [ -d /run/systemd/system ]; then
        systemctl stop "home-${username}.mount" 2>/dev/null || true
        systemctl disable "home-${username}.mount" 2>/dev/null || true
        rm -f "/etc/systemd/system/home-${username}.mount"
    else
        umount "/home/$username" 2>/dev/null || true
        rm -f "/home/$username" 2>/dev/null || true
    fi
}

# =====================================================================
# Check if home is mounted
# =====================================================================
is_home_mounted() {
    local username="$1"
    mountpoint -q "/home/$username" 2>/dev/null
}

# =====================================================================
# Get workspace .env source (prefers /config/.hermes/.env)
# =====================================================================
get_env_source() {
    if [ -f "/config/.hermes/.env" ]; then
        echo "/config/.hermes/.env"
    elif [ -f "$GLOBAL_BASE/.env" ]; then
        echo "$GLOBAL_BASE/.env"
    fi
}