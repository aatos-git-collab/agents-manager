#!/bin/bash
# Get deployment logs by project name
# Usage: ./logs.sh <project_name> [--tail 50]
#
# Options:
#   --tail N       Show last N log entries (default: 50)
#   --last N       Get logs for last N deployments (default: 1)
#   --errors       Show only error entries

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/coolify.sh"

usage() {
    echo "Usage: $0 <project_name> [options]"
    echo ""
    echo "Options:"
    echo "  --tail N       Show last N log entries (default: 50)"
    echo "  --last N       Get logs for last N deployments (default: 1)"
    echo "  --errors       Show only error/stderr entries"
    echo "  --status       Show deployment status summary"
    echo "  -h, --help     Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 risheng-pawnshop --tail 30"
    echo "  $0 risheng-pawnshop --last 3 --errors"
    echo "  $0 risheng-pawnshop --status"
    exit 1
}

PROJECT_NAME=""
TAIL_LINES=50
LAST_N=1
SHOW_ERRORS_ONLY=false
SHOW_STATUS_ONLY=false

while [ $# -gt 0 ]; do
    case "$1" in
        --tail)
            TAIL_LINES="${2:-50}"
            shift 2
            ;;
        --last)
            LAST_N="${2:-1}"
            shift 2
            ;;
        --errors)
            SHOW_ERRORS_ONLY=true
            shift
            ;;
        --status)
            SHOW_STATUS_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$PROJECT_NAME" ]; then
                PROJECT_NAME="$1"
            fi
            shift
            ;;
    esac
done

[ -z "$PROJECT_NAME" ] && usage

UUID=$(get_project_uuid "$PROJECT_NAME")

if [ "$UUID" = "NOT_FOUND" ] || [ -z "$UUID" ]; then
    echo -e "${RED}Project not found: ${PROJECT_NAME}${NC}"
    echo ""
    echo "Available projects:"
    list_configured_projects
    exit 1
fi

check_api_key || exit 1

# Get deployment history
DEPLOY_RESP=$(api "/deployments/applications/${UUID}")

if [ "$SHOW_STATUS_ONLY" = true ]; then
    echo -e "${BLUE}=== Deployment Status: ${PROJECT_NAME} ===${NC}"
    echo ""

    echo "$DEPLOY_RESP" | python3 -c "
import sys,json
from datetime import datetime

d = json.load(sys.stdin)
count = d.get('count', 0)
deployments = d.get('deployments', [])
print(f'Total deployments: {count}')
print()

for dep in deployments[:${LAST_N}]:
    uuid = dep.get('deployment_uuid', 'unknown')
    status = dep.get('status', 'unknown')
    created = dep.get('created_at', 'unknown')[:19]
    finished = dep.get('finished_at', '')
    f = finished[:19] if finished and finished != 'null' else 'ongoing'
    commit = dep.get('commit', '')[:12]
    msg = dep.get('message', '')
    print(f'[{uuid[:12]}] {status:15} | {created} | commit: {commit}')
    if msg:
        print(f'  └─ {msg[:80]}')
"
else
    echo -e "${BLUE}=== Deployment Logs: ${PROJECT_NAME} ===${NC}"
    echo ""

    # Get last deployment UUID
    DEPLOY_UUID=$(echo "$DEPLOY_RESP" | python3 -c "
import sys,json
d = json.load(sys.stdin)
deployments = d.get('deployments', [])
if deployments and ${LAST_N} > 0:
    dep = deployments[${LAST_N}-1]
    print(dep.get('deployment_uuid', ''))
" 2>/dev/null)

    if [ -z "$DEPLOY_UUID" ]; then
        echo "No deployments found for ${PROJECT_NAME}"
        exit 1
    fi

    echo -e "${YELLOW}Deployment: ${DEPLOY_UUID}${NC}"
    echo ""

    # Get logs from deployment
    get_deployment_logs "$DEPLOY_UUID" 2>/dev/null | tail -"$TAIL_LINES"
fi