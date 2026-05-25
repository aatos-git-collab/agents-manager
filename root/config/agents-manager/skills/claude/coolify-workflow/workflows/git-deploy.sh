#!/bin/bash
# Git Deploy Workflow: push → Coolify deploys → monitor → report
# Usage: ./git-deploy.sh <project_name> [--poll] [--fix]
#
# Workflow:
# 1. Show pending changes
# 2. Push to git (triggers Coolify webhook)
# 3. Monitor deployment
# 4. If failed: show logs, offer to fix and retry

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "${SKILL_DIR}/scripts/coolify.sh"

POLL=""
AUTO_FIX=""

while [ $# -gt 0 ]; do
    case "$1" in
        --poll)
            POLL="yes"
            shift
            ;;
        --fix)
            AUTO_FIX="yes"
            shift
            ;;
        *)
            PROJECT_NAME="${1}"
            shift
            ;;
    esac
done

[ -z "$PROJECT_NAME" ] && { echo "Usage: $0 <project_name> [--poll] [--fix]"; exit 1; }

UUID=$(get_project_uuid "$PROJECT_NAME")
if [ "$UUID" = "NOT_FOUND" ] || [ -z "$UUID" ]; then
    echo -e "${RED}Project not found: ${PROJECT_NAME}${NC}"
    list_configured_projects
    exit 1
fi

check_api_key || exit 1

# Get project git info
GIT_CONFIG=$(get_project_config "$PROJECT_NAME" | python3 -c "
import sys,json
d = json.load(sys.stdin)
print(f\"{d.get('git_repo')}:{d.get('branch')}\")
" 2>/dev/null)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Coolify Git Deploy Workflow${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Project: ${GREEN}${PROJECT_NAME}${NC}"
echo -e "Git: ${YELLOW}${GIT_CONFIG}${NC}"
echo -e "UUID: ${UUID}"
echo ""

# Check git status
echo -e "${YELLOW}1. Checking git status...${NC}"
cd "/root/${PROJECT_NAME}" 2>/dev/null || cd "/root/risheng-pawnshop" 2>/dev/null || { echo "Project dir not found"; exit 1; }

GIT_STATUS=$(git status --short 2>/dev/null)
if [ -z "$GIT_STATUS" ]; then
    echo -e "${GREEN}✓ No pending changes${NC}"
    echo ""
    echo "Nothing to deploy. Make changes and push."
    exit 0
fi

echo -e "${YELLOW}Pending changes:${NC}"
echo "$GIT_STATUS"
echo ""

# Show what changed
CHANGES_COUNT=$(echo "$GIT_STATUS" | wc -l)
echo -e "${YELLOW}2. ${CHANGES_COUNT} file(s) to commit${NC}"

# Commit and push
echo ""
echo -e "${YELLOW}3. Committing and pushing...${NC}"

git add -A
COMMIT_MSG="${PROJECT_NAME}: deploy $(date '+%Y-%m-%d %H:%M')"
git commit -m "$COMMIT_MSG" 2>/dev/null || echo "Nothing to commit"

echo -e "${YELLOW}Pushing to origin...${NC}"
PUSH_RESULT=$(git push origin 2>&1)
PUSH_EXIT=$?

if [ $PUSH_EXIT -ne 0 ]; then
    echo -e "${RED}✗ Push failed${NC}"
    echo "$PUSH_RESULT"
    exit 1
fi

echo -e "${GREEN}✓ Pushed successfully${NC}"
echo ""
echo -e "${YELLOW}Coolify webhook triggered - build in progress...${NC}"

# Wait for build to start
sleep 5

# Poll if requested
if [ "$POLL" = "yes" ]; then
    echo ""
    echo -e "${YELLOW}4. Monitoring deployment...${NC}"
    echo ""

    for i in {1..30}; do
        STATUS=$(api "/deployments/applications/${UUID}" | python3 -c "
import sys,json
d = json.load(sys.stdin)
deployments = d.get('deployments', [])
if deployments:
    print(deployments[0].get('status', ''))
else:
    print('none')
" 2>/dev/null)

        echo -n "."

        case "$STATUS" in
            successfully|success|done)
                echo ""
                echo -e "${GREEN}✓ Deployment Successful!${NC}"
                exit 0
                ;;
            failed|cancelled|error)
                echo ""
                echo -e "${RED}✗ Deployment Failed${NC}"
                echo ""
                echo "Get logs: ${SCRIPT_DIR}/../scripts/logs.sh ${PROJECT_NAME}"
                exit 1
                ;;
            running|pending|in_progress)
                sleep 10
                ;;
            *)
                sleep 10
                ;;
        esac
    done

    echo ""
    echo -e "${YELLOW}Timeout waiting for deployment${NC}"
    echo "Check status: ${SCRIPT_DIR}/../scripts/status.sh ${PROJECT_NAME}"
else
    echo ""
    echo -e "${YELLOW}Deployment triggered. Check status with:${NC}"
    echo "  ${SCRIPT_DIR}/../scripts/status.sh ${PROJECT_NAME}"
    echo "  ${SCRIPT_DIR}/../scripts/logs.sh ${PROJECT_NAME}"
fi
