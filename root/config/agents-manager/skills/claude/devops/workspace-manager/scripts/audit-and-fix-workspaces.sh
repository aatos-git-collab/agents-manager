#!/bin/bash
# =============================================================================
# audit-and-fix-workspaces.sh — Self-heal all agent workspaces
# =============================================================================
# Architecture:
#   /home/<agent>/                     ← source of truth (agent works here)
#   /root/.hermes/workspaces/agents/<agent>  ← bind mount mirror (root views here)
#
# Runs pre-flight checks on all workspaces:
#   1. Shell configs (.bashrc, .profile, .bash_logout)
#   2. .hermes/ directory and contents
#   3. .claude/ directory and contents
#   4. .ssh/ directory and authorized_keys
#   5. Ownership correctness
#   6. Bind mount status
#
# Safe to run repeatedly — idempotent.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
FIXED()   { echo -e "${BLUE}[FIXED]${NC} $1"; }
OK()      { echo -e "${GREEN}[OK]${NC} $1"; }

HERMES_ROOT="${HERMES_HOME:-/root/.hermes}"
AGENTS_DIR="$HERMES_ROOT/workspaces/agents"
FIX_COUNT=0
ISSUE_COUNT=0

# -----------------------------------------------------------------------------
# Get list of all agents (from /home/ only — that's the source of truth)
# -----------------------------------------------------------------------------
get_all_agents() {
    ls /home/ 2>/dev/null | grep -v "^root$" | grep -v "^cbuilder$" | sort
}

# -----------------------------------------------------------------------------
# Ensure bind mount exists for an agent
# -----------------------------------------------------------------------------
ensure_bind_mount() {
    local agent="$1"
    local home="/home/$agent"
    local mount_point="$AGENTS_DIR/$agent"

    if [[ ! -d "$mount_point" ]]; then
        mkdir -p "$mount_point"
        FIXED "Created mount point: $mount_point"
        FIX_COUNT=$((FIX_COUNT + 1))
    fi

    # Check if already mounted
    if ! findmnt -n "$mount_point" >/dev/null 2>&1; then
        mount --bind "$home" "$mount_point" 2>/dev/null && {
            FIXED "Bound $home -> $mount_point"
            FIX_COUNT=$((FIX_COUNT + 1))
        } || {
            WARN "Could not bind mount $home -> $mount_point"
        }
    fi

    # Ensure fstab entry exists
    if ! grep -q "$mount_point" /etc/fstab 2>/dev/null; then
        echo "$home $mount_point none bind 0 0" >> /etc/fstab
        FIXED "Added fstab entry for $agent"
        FIX_COUNT=$((FIX_COUNT + 1))
    fi
}

# -----------------------------------------------------------------------------
# Check if a directory has any real content (not just cache/empty)
# -----------------------------------------------------------------------------
has_real_content() {
    local dir="$1"
    [[ -d "$dir" ]] && [[ $(find "$dir" -maxdepth 1 ! -path "$dir" -type f 2>/dev/null | wc -l) -gt 0 || \
                         $(find "$dir" -mindepth 1 -maxdepth 1 -type d ! -name ".*cache*" ! -name "node_modules" 2>/dev/null | wc -l) -gt 0 ]]
}

# -----------------------------------------------------------------------------
# Audit and fix one agent
# -----------------------------------------------------------------------------
audit_agent() {
    local agent="$1"
    local home="/home/$agent"
    local fixed=0
    local issues=0

    echo ""
    echo "========================================"
    echo "  Auditing: $agent"
    echo "========================================"

    # -------------------------------------------------------------------------
    # 0. Ensure bind mount is set up
    # -------------------------------------------------------------------------
    ensure_bind_mount "$agent"

    # -------------------------------------------------------------------------
    # 1. Shell configs
    # -------------------------------------------------------------------------
    for cfg in .bashrc .profile .bash_logout; do
        if [[ ! -f "$home/$cfg" ]]; then
            case "$cfg" in
                .bashrc)
                    cat > "$home/$cfg" << 'EOF'
# ~/.bashrc
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export EDITOR=vim
alias ll='ls -la'
EOF
                        ;;
                .profile)
                    cat > "$home/$cfg" << 'EOF'
# ~/.profile
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export EDITOR=vim
[ -f ~/.bashrc ] && . ~/.bashrc
EOF
                        ;;
                .bash_logout)
                    touch "$home/$cfg"
                    ;;
            esac
            chown "$agent:$agent" "$home/$cfg"
            FIXED "Created missing $cfg"
            FIX_COUNT=$((FIX_COUNT + 1)); fixed=1
        fi
    done

    # -------------------------------------------------------------------------
    # 2. .hermes/ directory
    # -------------------------------------------------------------------------
    if [[ ! -d "$home/.hermes" ]]; then
        mkdir -p "$home/.hermes"
        chown "$agent:$agent" "$home/.hermes"
        FIXED "Created .hermes dir"
        FIX_COUNT=$((FIX_COUNT + 1)); fixed=1
    fi

    # .env is always required
    if [[ ! -f "$home/.hermes/.env" ]]; then
        cat > "$home/.hermes/.env" << HERMESENV
HERMES_AGENT_NAME=$agent
HERMES_HOME=/root/.hermes
HERMES_WORKSPACE=/root/.hermes/workspaces/agents/$agent
HERMES_AGENT_HOME=$home
HERMESENV
        chown "$agent:$agent" "$home/.hermes/.env"
        FIXED "Created .hermes/.env"
        FIX_COUNT=$((FIX_COUNT + 1)); fixed=1
    fi

    # -------------------------------------------------------------------------
    # 3. .claude/ directory
    # -------------------------------------------------------------------------
    if [[ ! -d "$home/.claude" ]]; then
        mkdir -p "$home/.claude/projects"
        chown -R "$agent:$agent" "$home/.claude"
        cat > "$home/.claude/settings.json" << 'EOF'
{}
EOF
        chown "$agent:$agent" "$home/.claude/settings.json"
        FIXED "Created minimal .claude"
        FIX_COUNT=$((FIX_COUNT + 1)); fixed=1
    elif [[ ! -f "$home/.claude/settings.json" ]]; then
        cat > "$home/.claude/settings.json" << 'EOF'
{}
EOF
        chown "$agent:$agent" "$home/.claude/settings.json"
        FIXED "Created settings.json"
        FIX_COUNT=$((FIX_COUNT + 1)); fixed=1
    fi

    # -------------------------------------------------------------------------
    # 4. .ssh/ directory and authorized_keys
    # -------------------------------------------------------------------------
    if [[ ! -d "$home/.ssh" ]]; then
        mkdir -p "$home/.ssh"
        chmod 700 "$home/.ssh"
        chown "$agent:$agent" "$home/.ssh"
        FIXED "Created .ssh dir (no keys yet)"
        FIX_COUNT=$((FIX_COUNT + 1)); fixed=1
    fi

    # authorized_keys — create if missing or empty
    if [[ ! -f "$home/.ssh/authorized_keys" ]] || [[ ! -s "$home/.ssh/authorized_keys" ]]; then
        touch "$home/.ssh/authorized_keys"
        chmod 600 "$home/.ssh/authorized_keys"
        chown "$agent:$agent" "$home/.ssh/authorized_keys"
        FIXED "Created empty authorized_keys"
        FIX_COUNT=$((FIX_COUNT + 1)); fixed=1
    fi

    # -------------------------------------------------------------------------
    # 5. Ensure key subdirs exist in home
    # -------------------------------------------------------------------------
    for subdir in projects logs tests reports; do
        if [[ ! -d "$home/$subdir" ]]; then
            mkdir -p "$home/$subdir"
            chown -R "$agent:$agent" "$home/$subdir"
            FIXED "Created $subdir/"
            FIX_COUNT=$((FIX_COUNT + 1)); fixed=1
        fi
    done

    # -------------------------------------------------------------------------
    # 6. Ownership fix
    # -------------------------------------------------------------------------
    if [[ $(stat -c '%U' "$home") != "$agent" ]]; then
        chown -R "$agent:$agent" "$home"
        FIXED "Fixed ownership of $home"
        FIX_COUNT=$((FIX_COUNT + 1)); fixed=1
    fi

    # -------------------------------------------------------------------------
    # 7. Verify bind mount is working
    # -------------------------------------------------------------------------
    local mount_point="$AGENTS_DIR/$agent"
    if findmnt -n "$mount_point" >/dev/null 2>&1; then
        # Verify content matches
        if diff <(ls "$home/" | sort) <(ls "$mount_point/" | sort) >/dev/null 2>&1; then
            OK "$agent — bind mount OK"
        else
            WARN "$agent — bind mount content mismatch (may be transient)"
        fi
    else
        WARN "$agent — NOT MOUNTED"
        issues=$((issues + 1))
    fi

    if [[ $fixed -eq 0 ]]; then
        OK "$agent — no issues found"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo "=============================================="
    echo "  Workspace Audit & Self-Heal"
    echo "=============================================="
    echo ""

    # Ensure agents directory exists
    mkdir -p "$AGENTS_DIR"

    local agents
    agents=$(get_all_agents)

    if [[ -z "$agents" ]]; then
        ERROR "No agents found. Check /home/"
        exit 1
    fi

    INFO "Found agents: $(echo $agents | tr '\n' ' ')"
    echo ""

    for agent in $agents; do
        if id "$agent" >/dev/null 2>&1; then
            audit_agent "$agent"
        else
            WARN "User $agent does not exist — skipping"
        fi
    done

    echo ""
    echo "=============================================="
    echo "  Summary"
    echo "=============================================="
    if [[ $FIX_COUNT -gt 0 ]]; then
        echo -e "  ${BLUE}Fixed: $FIX_COUNT item(s)${NC}"
    else
        echo "  All workspaces healthy — no fixes needed"
    fi

    echo ""
    echo "  Bind Mount Status:"
    echo "  =================="
    for agent in $agents; do
        local mount_point="$AGENTS_DIR/$agent"
        if findmnt -n "$mount_point" >/dev/null 2>&1; then
            echo -e "    ${GREEN}$agent: OK${NC}"
        else
            echo -e "    ${RED}$agent: NOT MOUNTED${NC}"
        fi
    done
}

main "$@"
