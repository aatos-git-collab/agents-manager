#!/bin/bash
# =============================================================================
# infrastructure-manager.sh - Root Hermes infrastructure control plane
# =============================================================================
# Root Hermes uses this to manage:
#   - Skill staging/approval (gatekeeper)
#   - Workspace creation requests (from agents)
#   - Global skill updates
#   - System health
#
# This is the ONLY script that modifies /root/.hermes/skills/global/
# and creates/deletes user accounts.
#
# Usage: sudo ./infrastructure-manager.sh <command> [args]
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
STEP()    { echo -e "${BLUE}[STEP]${NC} $1"; }
OK()      { echo -e "${GREEN}[OK]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_UTILS="$SCRIPT_DIR/_tool-utils.sh"
[[ -f "$TOOL_UTILS" ]] && source "$TOOL_UTILS"

# =============================================================================
# PATHS
# =============================================================================
SKILLS_GLOBAL="/opt/skills"          # world-readable skills (works directly, no symlinks needed)
SKILLS_STAGING="${HERMES_HOME}/skills/staging"
SKILLS_REJECTED="${HERMES_HOME}/skills/rejected"
SKILLS_LOCAL="${HERMES_HOME}/skills/local"

# =============================================================================
# PREFLIGHT
# =============================================================================
[[ $(id -u) -eq 0 ]] || { echo "Must run as root"; exit 1; }

COMMAND="${1:-}"
[[ -z "$COMMAND" ]] && {
    echo "Usage: sudo $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  workspace create <username> [--reuse]     Create workspace"
    echo "  workspace delete <username>                Delete workspace"
    echo "  workspace list                              List workspaces"
    echo "  workspace status <username>                 Show workspace config"
    echo "  workspace update <username> <key> <value>   Update workspace.json"
    echo "  skill stage-list                           List staged skills"
    echo "  skill approve <skill-name>                 Approve staged skill"
    echo "  skill reject <skill-name> <reason>         Reject staged skill"
    echo "  skill stage <skill-name> <path>            Stage a skill (from workspace)"
    echo "  skill global-list                          List global skills"
    echo "  skill sync-all                             Sync global skills to all workspaces"
    echo "  health                                     System health check"
    echo "  self-heal                                  Self-heal global tools"
    echo "  workspace audit                            Audit & fix all workspaces"
    echo "  vault status                               Vault-security health check"
    echo "  vault start                                Start vault-security stack"
    echo "  vault stop                                 Stop vault-security stack"
    echo "  vault restart                              Restart vault-security stack"
    echo "  vault install [--update]                   Install vault-security from source"
    echo "  vault self-heal [--check|--force]          Self-heal vault-security"
    echo "  mount                                      Show bind mount status"
    exit 1
}

shift

# =============================================================================
# WORKSPACE COMMANDS
# =============================================================================
cmd_workspace_create() {
    local username="${1:-}"
    [[ -z "$username" ]] && { echo "Usage: $0 workspace create <username> [--reuse]"; exit 1; }

    local reuse=false
    [[ "${2:-}" == "--reuse" ]] && reuse=true

    STEP "Creating workspace: $username"
    bash "$SCRIPT_DIR/create-workspace.sh" "$username" $([[ $reuse == true ]] && echo "--reuse")
    OK "Workspace '$username' created"
}

cmd_workspace_delete() {
    local username="${1:-}"
    [[ -z "$username" ]] && { echo "Usage: $0 workspace delete <username>"; exit 1; }

    if ! id "$username" &>/dev/null; then
        ERROR "User '$username' does not exist"
    fi

    STEP "Deleting workspace: $username"
    userdel -r "$username" 2>/dev/null && OK "Deleted" || ERROR "Failed to delete"
}

cmd_workspace_list() {
    echo ""
    echo "  Workspaces:"
    echo "  ==========="
    for dir in /home/*/; do
        local user
        user=$(basename "$dir")
        if [[ -d "/home/$user/.hermes" ]]; then
            local sessions
            sessions=$(ls -1 "/home/$user/.hermes/sessions/" 2>/dev/null | wc -l)
            local workspace_status="no-config"
            if [[ -f "/home/$user/.workspace/workspace.json" ]]; then
                workspace_status="workspace-ready"
            fi
            echo "    $user  (sessions: $sessions, $workspace_status)"
        fi
    done
    echo ""
}

cmd_workspace_audit() {
    # Audit and self-heal all workspaces
    bash "$SCRIPT_DIR/audit-and-fix-workspaces.sh"
}

cmd_workspace_status() {
    # Show workspace status for a workspace
    local username="${1:-}"
    [[ -z "$username" ]] && { echo "Usage: $0 workspace status <username>"; exit 1; }
    local workspace_json="/home/$username/.workspace/workspace.json"
    if [[ ! -f "$workspace_json" ]]; then
        ERROR "No workspace.json for workspace '$username'"
        return 1
    fi

    echo ""
    echo "  Workspace config for '$username':"
    echo "  ==============================="
    echo "    config:  $workspace_json"

    local agent_name
    agent_name=$(grep -m1 '"name"' "$workspace_json" | head -1 | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | tr -d '[:space:]')
    [[ -n "$agent_name" ]] && echo "    agent:   $agent_name"

    local gateway_port
    gateway_port=$(grep -o '"port"[[:space:]]*:[[:space:]]*[0-9]*' "$workspace_json" | grep -o '[0-9]*' | head -1)
    [[ -n "$gateway_port" ]] && echo "    gateway: port $gateway_port"

    local exec_mode
    exec_mode=$(grep -m1 '"approval"' "$workspace_json" | sed 's/.*"approval"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    [[ -n "$exec_mode" ]] && echo "    exec:    approval=$exec_mode"

    echo ""
}

cmd_workspace_update() {
    # Update workspace.json for a workspace
    local username="${1:-}"
    local key="${2:-}"
    local value="${3:-}"
    [[ -z "$username" || -z "$key" || -z "$value" ]] && { echo "Usage: $0 workspace update <username> <key> <value>"; exit 1; }

    local workspace_json="/home/$username/.workspace/workspace.json"
    [[ ! -f "$workspace_json" ]] && ERROR "No workspace.json for workspace '$username'"

    # Simple key update via jq if available, else sed
    if command -v jq &>/dev/null; then
        local tmp=$(mktemp)
        jq "$key = \\\"$value\\\"" "$workspace_json" > "$tmp" && mv "$tmp" "$workspace_json"
        chown "$username:$username" "$workspace_json"
        OK "Updated $key = $value"
    else
        WARN "jq not available; manual edit required: $workspace_json"
    fi
}

# =============================================================================
# SKILL COMMANDS
# =============================================================================

# Initialize skill directories
init_skill_dirs() {
    mkdir -p "$SKILLS_GLOBAL" "$SKILLS_STAGING" "$SKILLS_REJECTED" "$SKILLS_LOCAL"
    # /root/.hermes stays 700 — no chmod needed, /opt/ is the public runtime
}

cmd_skill_stage() {
    # Stage a skill from a workspace for review
    local name="${1:-}"; local src="${2:-}"
    [[ -z "$name" || -z "$src" ]] && { echo "Usage: $0 skill stage <name> <source-path>"; exit 1; }

    init_skill_dirs

    if [[ ! -f "$src" ]]; then
        ERROR "Skill file not found: $src"
    fi

    local dest="$SKILLS_STAGING/$name"
    cp -r "$src" "$dest"
    chmod -R 644 "$dest"
    chmod 755 "$dest"

    OK "Skill '$name' staged for review at $dest"
    echo ""
    echo "  Review it with: sudo $0 skill review $name"
    echo "  Approve with:   sudo $0 skill approve $name"
    echo "  Reject with:    sudo $0 skill reject $name <reason>"
}

cmd_skill_stage_list() {
    init_skill_dirs
    echo ""
    echo "  Staged Skills (pending review):"
    echo "  ================================"
    if [[ -z "$(ls -A "$SKILLS_STAGING" 2>/dev/null)" ]]; then
        echo "    (none)"
    else
        for d in "$SKILLS_STAGING"/*/; do
            local name
            name=$(basename "$d")
            local desc
            desc=$(grep -m1 "^description:" "$d/SKILL.md" 2>/dev/null | cut -d: -f2- | xargs)
            echo "    $name"
            [[ -n "$desc" ]] && echo "      $desc"
        done
    fi
    echo ""
}

cmd_skill_approve() {
    # Approve a staged skill — copy to global under its category
    local name="${1:-}"
    [[ -z "$name" ]] && { echo "Usage: $0 skill approve <name>"; exit 1; }

    init_skill_dirs

    # Find the staged skill (name might be just basename or category/name)
    local staged=""
    local staged_base=""
    
    # Try direct path first
    if [[ -d "$SKILLS_STAGING/$name" ]]; then
        staged="$SKILLS_STAGING/$name"
        staged_base="$name"
    else
        # Search for it
        for d in "$SKILLS_STAGING"/*/; do
            local base=$(basename "$d")
            # Match by skill name (strip any workspace_timestamp suffix)
            if [[ "$base" == "$name" || "$base" == "${name}_"* ]]; then
                staged="$d"
                staged_base="$name"
                break
            fi
        done
    fi
    
    [[ ! -d "$staged" ]] && ERROR "No staged skill named '$name' in $SKILLS_STAGING"

    # Validate SKILL.md exists
    [[ ! -f "$staged/SKILL.md" ]] && ERROR "SKILL.md missing in staged skill"

    # Parse category from SKILL.md
    local category
    category=$(grep -m1 "^category:" "$staged/SKILL.md" 2>/dev/null | cut -d: -f2 | xargs)
    [[ -z "$category" ]] && category="general"

    # Skill name is the staged_base (or extracted name)
    local skill_name="$staged_base"

    # Create category dir in global if needed
    mkdir -p "$SKILLS_GLOBAL/$category"

    # Copy to global: /opt/skills/<category>/<skill-name>/
    rm -rf "$SKILLS_GLOBAL/$category/$skill_name"
    cp -r "$staged" "$SKILLS_GLOBAL/$category/$skill_name"
    chmod -R 755 "$SKILLS_GLOBAL/$category/$skill_name"
    chmod 644 "$SKILLS_GLOBAL/$category/$skill_name"/*.md 2>/dev/null || true

    # Remove from staging
    rm -rf "$staged"

    OK "Skill '$category/$skill_name' approved and added to global"
    echo ""
    echo "  Synced to workspaces."
}

cmd_skill_reject() {
    # Reject a staged skill
    local name="${1:-}"; local reason="${2:-no reason}"
    [[ -z "$name" ]] && { echo "Usage: $0 skill reject <name> <reason>"; exit 1; }

    init_skill_dirs

    local staged="$SKILLS_STAGING/$name"
    [[ ! -d "$staged" ]] && ERROR "No staged skill named '$name'"

    # Move to rejected
    mkdir -p "$SKILLS_REJECTED/$name"
    echo "Rejected: $(date)" > "$SKILLS_REJECTED/$name/reason.txt"
    echo "Reason: $reason" >> "$SKILLS_REJECTED/$name/reason.txt"
    cp -r "$staged"/* "$SKILLS_REJECTED/$name/" 2>/dev/null || true
    rm -rf "$staged"

    OK "Skill '$name' rejected"
    echo "  Reason: $reason"
}

cmd_skill_global_list() {
    init_skill_dirs
    echo ""
    echo "  Global Skills:"
    echo "  =============="
    if [[ -z "$(ls -A "$SKILLS_GLOBAL" 2>/dev/null)" ]]; then
        echo "    (none)"
    else
        # Skills are at: /opt/skills/<category>/<skill-name>/SKILL.md
        for cat_dir in "$SKILLS_GLOBAL"/*/; do
            local category
            category=$(basename "$cat_dir")
            # Skip non-skill dirs
            [[ "$category" == "local" || "$category" == "staged" || "$category" == "staging-requests" ]] && continue
            
            for skill_dir in "$cat_dir"/*/; do
                [[ -d "$skill_dir" ]] || continue
                local skill_name
                skill_name=$(basename "$skill_dir")
                local full_name="${category}/${skill_name}"
                local desc
                desc=$(grep -m1 "^description:" "$skill_dir/SKILL.md" 2>/dev/null | cut -d: -f2- | sed "s/^'//; s/'$//" | xargs 2>/dev/null)
                echo "    $full_name"
                [[ -n "$desc" ]] && echo "      $desc"
            done
        done
    fi
    echo ""
}

cmd_skill_sync_all() {
    # Ensure global skills are world-readable (no symlinks needed)
    init_skill_dirs

    STEP "Ensuring global skills are world-readable..."
    chmod -R 755 "$SKILLS_GLOBAL" 2>/dev/null || true
    chown -R root:root "$SKILLS_GLOBAL" 2>/dev/null || true

    local count
    count=$(find "$SKILLS_GLOBAL" -maxdepth 2 -name "SKILL.md" 2>/dev/null | wc -l)
    OK "Global skills at $SKILLS_GLOBAL ($count skills, world-readable)"
}

cmd_skill_request() {
    # Called by workspace agent to request skill staging
    # Usage: sudo ./infrastructure-manager.sh skill-request <skill-name> <workspace-user>
    local name="${1:-}"; local workspace="${2:-}"
    [[ -z "$name" || -z "$workspace" ]] && { echo "Usage: $0 skill-request <name> <workspace>"; exit 1; }

    init_skill_dirs

    local workspace_skills="/home/$workspace/.hermes/skills/local/$name"
    [[ ! -d "$workspace_skills" ]] && ERROR "No local skill '$name' in workspace '$workspace'"

    local staged="$SKILLS_STAGING/$name"
    cp -r "$workspace_skills" "$staged"

    echo ""
    INFO "Skill '$name' staged for root review"
    echo "  From workspace: $workspace"
    echo "  Run 'sudo $0 skill approve $name' to approve"
}

# =============================================================================
# HEALTH
# =============================================================================
cmd_health() {
    echo ""
    echo "============================================"
    echo "  Infrastructure Health"
    echo "============================================"
    echo ""

    # Global tools
    echo "  Global Tools:"
    for tool in claude hermes aatosteam; do
        local ver
        ver=$($tool --version 2>&1 | head -1)
        [[ $? -eq 0 ]] && echo "    $tool: $ver" || echo "    $tool: FAIL"
    done

    echo ""

    # Workspaces (call list command)
    cmd_workspace_list

    # Skills count (individual skill dirs, not categories)
    init_skill_dirs
    local global_count=0
    for cat_dir in "$SKILLS_GLOBAL"/*/; do
        [[ -d "$cat_dir" ]] || continue
        local cat=$(basename "$cat_dir")
        [[ "$cat" == "local" || "$cat" == "staged" || "$cat" == "staging-requests" ]] && continue
        global_count=$((global_count + $(ls -d "$cat_dir"/*/ 2>/dev/null | wc -l)))
    done
    echo "  Skills:"
    echo "    global:  $global_count skills across $(ls -d "$SKILLS_GLOBAL"/*/ 2>/dev/null | wc -l) categories"
    echo "    staging: $(ls -A "$SKILLS_STAGING" 2>/dev/null | wc -l) pending"
    echo "    local:   $(ls -A "$SKILLS_LOCAL" 2>/dev/null | wc -l) (templates)"

    echo ""
    echo "  Symlinks (/usr/local/bin):"
    for tool in claude hermes aatosteam; do
        local sl="/usr/local/bin/$tool"
        if [[ -L "$sl" && -e "$sl" ]]; then
            echo "    $tool -> $(readlink $sl) ✓"
        else
            echo "    $tool: broken"
        fi
    done

    echo ""
}

# =============================================================================
# SELF-HEAL
# =============================================================================
cmd_self_heal() {
    echo ""
    INFO "Running self-heal..."
    verify_and_fix_all
}

# =============================================================================
# VAULT COMMANDS
# =============================================================================
cmd_vault_status() {
    echo ""
    INFO "Vault-Security Health:"
    echo ""
    bash "$SCRIPT_DIR/../vault/scripts/vault-self-heal.sh" --check
}

cmd_vault_start() {
    local VAULT_DOCKER_DIR="$SCRIPT_DIR/../vault/docker"
    [[ ! -d "$VAULT_DOCKER_DIR" ]] && { ERROR "Vault not installed. Run: $0 vault install"; exit 1; }
    INFO "Starting vault-security..."
    cd "$VAULT_DOCKER_DIR" && docker compose up -d
    sleep 3
    cmd_vault_status
}

cmd_vault_stop() {
    local VAULT_DOCKER_DIR="$SCRIPT_DIR/../vault/docker"
    [[ ! -d "$VAULT_DOCKER_DIR" ]] && { ERROR "Vault not installed."; exit 1; }
    INFO "Stopping vault-security..."
    cd "$VAULT_DOCKER_DIR" && docker compose down
    OK "Stopped"
}

cmd_vault_restart() {
    cmd_vault_stop
    cmd_vault_start
}

cmd_vault_install() {
    local update=false
    [[ "${1:-}" == "--update" ]] && update=true
    bash "$SCRIPT_DIR/../vault/scripts/vault-install.sh" $([[ $update == true ]] && echo "--update")
}

cmd_vault_self_heal() {
    bash "$SCRIPT_DIR/../vault/scripts/vault-self-heal.sh" "${1:-}"
}


# =============================================================================
# MAIN DISPATCH
# =============================================================================
case "$COMMAND" in
    workspace)
        case "${1:-}" in
            create)  cmd_workspace_create "${@:2}" ;;
            delete)  cmd_workspace_delete "${@:2}" ;;
            list)    cmd_workspace_list ;;
            status)  cmd_workspace_status "${@:2}" ;;
            update)  cmd_workspace_update "${@:2}" ;;
            audit)  cmd_workspace_audit ;;
            *)      echo "Unknown workspace command: $1"; exit 1 ;;
        esac
        ;;
    skill)
        case "${1:-}" in
            stage)       cmd_skill_stage "${@:2}" ;;
            approve)     cmd_skill_approve "${@:2}" ;;
            reject)      cmd_skill_reject "${@:2}" ;;
            stage-list)  cmd_skill_stage_list ;;
            global-list) cmd_skill_global_list ;;
            sync-all)    cmd_skill_sync_all ;;
            request)     cmd_skill_request "${@:2}" ;;
            *)           echo "Unknown skill command: $1"; exit 1 ;;
        esac
        ;;
    health)  cmd_health ;;
    self-heal) cmd_self_heal ;;
    vault)
        case "${1:-}" in
            status)     cmd_vault_status ;;
            start)      cmd_vault_start ;;
            stop)      cmd_vault_stop ;;
            restart)   cmd_vault_restart ;;
            install)   cmd_vault_install "${2:-}" ;;
            self-heal) cmd_vault_self_heal "${2:-}" ;;
            *)         echo "Unknown vault command: $1"; exit 1 ;;
        esac
        ;;
    mount)
        # Show mount status for all agents + skills + agents
        HERMES_ROOT="${HERMES_HOME:-/root/.hermes}"
        AGENTS_DIR="$HERMES_ROOT/workspaces/agents"
        echo ""
        echo "  Bind Mount Status (all agents)"
        echo "  ==============================="
        echo "  Format: HOME (source) -> MOUNT_POINT (viewed by root)"
        echo ""
        for dir in /home/*/; do
            agent=$(basename "$dir")
            [[ "$agent" == "root" ]] && continue

            # Home dir bind mount
            mount_point="$AGENTS_DIR/$agent"
            if mountinfo_line=$(cat /proc/self/mountinfo 2>/dev/null | grep " $mount_point "); then
                mount_src=$(echo "$mountinfo_line" | awk '{print $4}')
                printf "  %-18s %s -> %s\n" "$agent:" "$mount_src" "$mount_point"
            else
                printf "  %-18s %-45s\n" "$agent:" "NOT MOUNTED"
            fi

            # Claude skills mount
            skills_mount="$dir/.claude/skills"
            if mountinfo_line=$(cat /proc/self/mountinfo 2>/dev/null | grep " $skills_mount "); then
                printf "    %-16s -> %s\n" "skills:" "/root/.claude/skills"
            fi

            # Claude agents mount
            agents_mount="$dir/.claude/agents"
            if mountinfo_line=$(cat /proc/self/mountinfo 2>/dev/null | grep " $agents_mount "); then
                printf "    %-16s -> %s\n" "agents:" "/root/.claude/agents"
            fi
        done
        echo ""
        echo "  Global skills source:  /root/.claude/skills/  ($(ls -1 /root/.claude/skills/ 2>/dev/null | wc -l) skills)"
        echo "  Global agents source:  /root/.claude/agents/  ($(ls -1 /root/.claude/agents/ 2>/dev/null | wc -l) agent pools)"
        ;;
    *)       echo "Unknown command: $COMMAND"; exit 1 ;;
esac
