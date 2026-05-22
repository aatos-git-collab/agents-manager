#!/bin/bash
# Deploy application by project name
# Usage: ./deploy.sh <project_name>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/coolify.sh"

usage() {
    echo "Usage: $0 <project_name>"
    echo ""
    echo "Configured projects:"
    list_configured_projects
    exit 1
}

[ -z "$1" ] && usage

PROJECT_NAME="${1}"
UUID=$(get_project_uuid "$PROJECT_NAME")

if [ "$UUID" = "NOT_FOUND" ] || [ -z "$UUID" ]; then
    echo -e "${RED}Project not found: ${PROJECT_NAME}${NC}"
    echo ""
    echo "Available projects:"
    list_configured_projects
    exit 1
fi

check_api_key || exit 1

echo -e "${BLUE}=== Coolify Deploy ===${NC}"
echo -e "Project: ${GREEN}${PROJECT_NAME}${NC}"
echo -e "UUID: ${UUID}"
echo ""

# Get current status first
APP_DETAILS=$(api "/applications/${UUID}" | python3 -c "
import sys,json
d = json.load(sys.stdin)
print(f'Status: {d.get(\"status\", \"unknown\")}')
print(f'Branch: {d.get(\"git_branch\", \"unknown\")}')
print(f'Repo: {d.get(\"git_repository\", \"unknown\")}')
" 2>/dev/null)
echo -e "${APP_DETAILS}"
echo ""

# Trigger deploy via /deploy endpoint with uuid
echo -e "${YELLOW}Triggering deployment...${NC}"
RESPONSE=$(api_raw "/deploy" "POST" "{\"uuid\":\"${UUID}\"}")
echo "$RESPONSE" | python3 -c "
import sys,json
d = json.load(sys.stdin)
if 'error' in d:
    print(f\"Error: {d.get('error')}\")
    exit(1)
deployments = d.get('deployments', [])
if deployments:
    msg = deployments[0].get('message', 'Deployment queued')
    dep_uuid = deployments[0].get('deployment_uuid', '')
    print(f\"{msg}\")
    print(f\"Deployment UUID: {dep_uuid}\")
else:
    print(d)
" 2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to trigger deployment${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Deployment triggered${NC}"
echo ""
echo "Check status with: ${SCRIPT_DIR}/status.sh ${PROJECT_NAME}"
