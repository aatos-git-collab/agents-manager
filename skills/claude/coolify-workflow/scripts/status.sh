#!/bin/bash
# Check deployment status by project name
# Usage: ./status.sh <project_name>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/coolify.sh"

usage() {
    echo "Usage: $0 <project_name>"
    exit 1
}

[ -z "$1" ] && usage

PROJECT_NAME="${1}"
UUID=$(get_project_uuid "$PROJECT_NAME")

if [ "$UUID" = "NOT_FOUND" ] || [ -z "$UUID" ]; then
    echo -e "${RED}Project not found: ${PROJECT_NAME}${NC}"
    exit 1
fi

check_api_key || exit 1

echo -e "${BLUE}=== Deployment Status: ${PROJECT_NAME} ===${NC}"
echo ""

# Get latest deployments
RESPONSE=$(api "/deployments/applications/${UUID}")

COUNT=$(echo "$RESPONSE" | python3 -c "
import sys,json
d = json.load(sys.stdin)
print(d.get('count', 0))
" 2>/dev/null)

if [ "$COUNT" = "0" ] || [ -z "$COUNT" ]; then
    echo -e "${YELLOW}No deployments found${NC}"
    exit 0
fi

# Parse latest deployment
echo "$RESPONSE" | python3 -c "
import sys,json
d = json.load(sys.stdin)
deployments = d.get('deployments', [])
if deployments:
    dep = deployments[0]
    status = dep.get('status', 'unknown')
    commit = dep.get('commit', '')[:12]
    created = dep.get('created_at', '')[:19]
    finished = dep.get('finished_at', '')
    msg = dep.get('commit_message', '')[:60].replace('\n', ' ')
    print(f'UUID: {dep.get(\"deployment_uuid\", \"N/A\")}')
    print(f'Status: {status}')
    print(f'Commit: {commit}')
    print(f'Started: {created}')
    if finished:
        print(f'Finished: {finished[:19]}')
    else:
        print('Finished: In Progress')
    if msg:
        print(f'Message: {msg}')
" 2>/dev/null

# Status color
STATUS=$(echo "$RESPONSE" | python3 -c "
import sys,json
d = json.load(sys.stdin)
deployments = d.get('deployments', [])
if deployments:
    print(deployments[0].get('status', ''))
" 2>/dev/null)

echo ""
case "$STATUS" in
    successfully|success|done)
        echo -e "${GREEN}✓ Deployment Successful${NC}"
        ;;
    failed|cancelled|error)
        echo -e "${RED}✗ Deployment Failed${NC}"
        echo ""
        echo "Get detailed logs: ${SCRIPT_DIR}/logs.sh ${PROJECT_NAME}"
        ;;
    running|pending|in_progress)
        echo -e "${YELLOW}◐ Deployment In Progress${NC}"
        echo ""
        echo "Wait and re-run to check status"
        ;;
    *)
        echo -e "${YELLOW}◐ Status: ${STATUS}${NC}"
        ;;
esac
