#!/bin/bash
# =============================================================================
# workspace-request.sh - Workspace agent → Root Hermes communication
# =============================================================================
# Workspace agents use this to:
#   - Request new workspace creation (root does useradd)
#   - Propose skills for staging
#   - Query request status
#
# Workspace agents CANNOT use sudo. They write requests here.
# Root Hermes processes requests from HERMES_HOME/skills/staging-requests/
#
# Usage (as workspace user):
#   ~/request.sh workspace create <new-username>
#   ~/request.sh skill propose <skill-name>
#   ~/request.sh status [request-id]
# =============================================================================

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Derive HERMES_HOME from script location (self-locating, portable)
if [[ -z "${HERMES_HOME:-}" ]]; then
    HERMES_HOME="${SCRIPT_DIR%/skills/devops/workspace-manager/scripts}"
fi
export HERMES_HOME

WORKSPACE_NAME="${WORKSPACE_NAME:-$(whoami)}"
REQUESTS_DIR="${HERMES_HOME}/requests"
STAGING_ROOT="${HERMES_HOME}/skills/staging-requests"
INFRA_MANAGER="${HERMES_HOME}/skills/devops/workspace-manager/scripts/infrastructure-manager.sh"

mkdir -p "$REQUESTS_DIR" 2>/dev/null || true

# =============================================================================
# Write a request file
# =============================================================================
write_request() {
    local type="$1"; shift
    local id
    id="req_$(date +%s)_$$"
    local file="$REQUESTS_DIR/$id.json"

    local payload
    payload=$(printf '{"id":"%s","workspace":"%s","type":"%s","timestamp":"%s","args":%s}' \
        "$id" "$WORKSPACE_NAME" "$type" "$(date -Iseconds)" "$*")

    echo "$payload" > "$file"
    chmod 644 "$file"

    echo "$id"
}

# =============================================================================
# List pending requests
# =============================================================================
list_requests() {
    echo ""
    echo "  Pending Requests:"
    echo "  ================"
    local count=0
    for f in "$REQUESTS_DIR"/req_*.json; do
        [[ -f "$f" ]] || continue
        local id basename id2
        id=$(basename "$f" .json)
        local ws type ts args
        ws=$(grep -oP '"workspace":"[^"]*"' "$f" | cut -d'"' -f4)
        type=$(grep -oP '"type":"[^"]*"' "$f" | cut -d'"' -f4)
        ts=$(grep -oP '"timestamp":"[^"]*"' "$f" | cut -d'"' -f4)
        echo "    [$id]"
        echo "      workspace: $ws"
        echo "      type:     $type"
        echo "      time:    $ts"
        echo ""
        ((count++))
    done
    [[ $count -eq 0 ]] && echo "    (none)"
    echo ""
}

# =============================================================================
# COMMANDS
# =============================================================================

cmd_workspace_create() {
    local new_user="${1:-}"
    [[ -z "$new_user" ]] && { echo "Usage: $0 workspace create <username>"; exit 1; }

    # Validate username
    if ! [[ "$new_user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        ERROR "Invalid username: $new_user"
    fi

    # Write request
    local req_id
    req_id=$(write_request "workspace-create" "\"$new_user\"")
    INFO "Request sent: $req_id"
    echo ""
    echo "  Requested: create workspace '$new_user'"
    echo "  Root Hermes will process this request."
    echo "  Check status with: $0 status $req_id"
    echo ""
}

cmd_skill_propose() {
    local skill_name="${1:-}"
    [[ -z "$skill_name" ]] && { echo "Usage: $0 skill propose <skill-name>"; exit 1; }

    local skill_path="$HERMES_HOME/skills/local/$skill_name"
    if [[ ! -d "$skill_path" ]]; then
        ERROR "No local skill at: $skill_path"
    fi

    # Copy to staging requests
    mkdir -p "$STAGING_ROOT"
    local dest="$STAGING_ROOT/${skill_name}_${WORKSPACE_NAME}_$(date +%s)"
    cp -r "$skill_path" "$dest"

    # Write request
    local req_id
    req_id=$(write_request "skill-propose" "{\"name\":\"$skill_name\",\"path\":\"$dest\"}")
    INFO "Skill '$skill_name' submitted for review: $req_id"
    echo ""
    echo "  Root Hermes will review and approve/reject."
    echo "  Check status with: $0 status"
    echo ""
}

cmd_status() {
    list_requests
}

# =============================================================================
# MAIN
# =============================================================================
COMMAND="${1:-}"
[[ -z "$COMMAND" ]] && {
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  workspace create <username>   Request new workspace (root does useradd)"
    echo "  skill propose <skill-name>    Propose local skill for global approval"
    echo "  status                       List pending requests"
    echo "  status <request-id>         Check specific request"
    echo ""
    echo "Workspace: $WORKSPACE_NAME"
    echo "Requests dir: $REQUESTS_DIR"
    echo ""
    exit 0
}

shift

case "$COMMAND" in
    workspace)
        case "${1:-}" in
            create) cmd_workspace_create "${@:2}" ;;
            *)      echo "Unknown: workspace $1"; exit 1 ;;
        esac
        ;;
    skill)
        case "${1:-}" in
            propose) cmd_skill_propose "${@:2}" ;;
            *)       echo "Unknown: skill $1"; exit 1 ;;
        esac
        ;;
    status) cmd_status ;;
    *)      echo "Unknown command: $COMMAND"; exit 1 ;;
esac
