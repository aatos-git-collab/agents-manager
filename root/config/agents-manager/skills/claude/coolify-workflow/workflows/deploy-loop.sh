#!/bin/bash
# Continuous Deploy Loop: deploy → monitor → if failed fix & retry → until success
# Usage: ./deploy-loop.sh <project_name> [--fix]
#
# Loop:
# 1. Push code to git (or trigger deploy)
# 2. Monitor deployment
# 3. If failed: show error, wait, auto-retry
# 4. If success: exit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "${SKILL_DIR}/scripts/coolify.sh"

AUTO_FIX=""
PROJECT_NAME=""

while [ $# -gt 0 ]; do
    case "$1" in
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

[ -z "$PROJECT_NAME" ] && { echo "Usage: $0 <project_name> [--fix]"; exit 1; }

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
echo -e "${BLUE}  Coolify Continuous Deploy Loop${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Project: ${GREEN}${PROJECT_NAME}${NC}"
echo -e "Git: ${YELLOW}${GIT_CONFIG}${NC}"
echo -e "UUID: ${UUID}"
echo ""

LOOP_COUNT=0
MAX_LOOPS=10

while [ $LOOP_COUNT -lt $MAX_LOOPS ]; do
    LOOP_COUNT=$((LOOP_COUNT + 1))
    echo -e "${BLUE}--- Loop ${LOOP_COUNT}/${MAX_LOOPS} ---${NC}"
    echo ""

    # Get current git status and push
    echo -e "${YELLOW}1. Checking git...${NC}"

    # Find project directory
    PROJECT_DIR=""
    for dir in "/root/${PROJECT_NAME}" "/root/risheng-pawnshop" "/root/${PROJECT_NAME}-*" "/root"; do
        if [ -d "$dir" ] && [ -d "$dir/.git" ]; then
            PROJECT_DIR="$dir"
            break
        fi
    done

    if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR/.git" ]; then
        echo -e "${RED}Could not find git directory for ${PROJECT_NAME}${NC}"
        echo "Push code manually or ensure project is in /root/"
        echo ""
        echo -e "${YELLOW}Waiting 60s before retry...${NC}"
        sleep 60
        continue
    fi

    cd "$PROJECT_DIR"

    # Check for changes
    GIT_STATUS=$(git status --short 2>/dev/null)
    if [ -z "$GIT_STATUS" ]; then
        echo -e "${GREEN}✓ No pending changes${NC}"
    else
        echo -e "${YELLOW}Pending changes, committing and pushing...${NC}"
        echo "$GIT_STATUS"
        echo ""

        git add -A
        COMMIT_MSG="${PROJECT_NAME}: deploy loop $(date '+%Y-%m-%d %H:%M:%S')"
        git commit -m "$COMMIT_MSG" 2>/dev/null || echo "Nothing to commit"

        echo -e "${YELLOW}Pushing to origin...${NC}"
        if ! git push origin 2>&1; then
            echo -e "${RED}Push failed, retrying in 30s...${NC}"
            sleep 30
            continue
        fi
        echo -e "${GREEN}✓ Pushed${NC}"
    fi

    # Wait for Coolify to process
    echo ""
    echo -e "${YELLOW}2. Waiting for Coolify to start build (15s)...${NC}"
    sleep 15

    # Monitor deployment
    echo ""
    echo -e "${YELLOW}3. Monitoring deployment...${NC}"

    DEPLOY_STARTED=0
    DEPLOY_UUID=""
    FINAL_STATUS=""

    for i in {1..60}; do
        RESPONSE=$(api "/deployments/applications/${UUID}")

        DEPLOY_COUNT=$(echo "$RESPONSE" | python3 -c "
import sys,json
d = json.load(sys.stdin)
print(d.get('count', 0))
" 2>/dev/null)

        if [ "$DEPLOY_COUNT" = "0" ] || [ -z "$DEPLOY_COUNT" ]; then
            echo -n "."
            sleep 5
            continue
        fi

        DEPLOY=$(echo "$RESPONSE" | python3 -c "
import sys,json
d = json.load(sys.stdin)
deployments = d.get('deployments', [])
if deployments:
    dep = deployments[0]
    print(f\"{dep.get('deployment_uuid')}|{dep.get('status')}|{dep.get('commit', '')[:12]}\")
" 2>/dev/null)

        DEPLOY_UUID=$(echo "$DEPLOY" | cut -d'|' -f1)
        STATUS=$(echo "$DEPLOY" | cut -d'|' -f2)
        COMMIT=$(echo "$DEPLOY" | cut -d'|' -f3)

        if [ -n "$STATUS" ]; then
            if [ $DEPLOY_STARTED -eq 0 ]; then
                echo ""
                echo -e "Deployment: ${DEPLOY_UUID:0:12}... Status: $STATUS"
                DEPLOY_STARTED=1
            else
                echo -n "."
            fi
        fi

        case "$STATUS" in
            successfully|success|done)
                FINAL_STATUS="success"
                echo ""
                echo ""
                echo -e "${GREEN}========================================${NC}"
                echo -e "${GREEN}  ✓ DEPLOYMENT SUCCESSFUL!${NC}"
                echo -e "${GREEN}========================================${NC}"
                echo ""
                echo -e "Commit: ${COMMIT}"
                echo "URL: Check Coolify dashboard for app URL"
                exit 0
                ;;
            failed|cancelled|error)
                FINAL_STATUS="failed"
                echo ""
                break
                ;;
            running|pending|in_progress)
                sleep 10
                ;;
            *)
                sleep 5
                ;;
        esac
    done

    if [ "$FINAL_STATUS" = "failed" ]; then
        echo ""
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}  ✗ DEPLOYMENT FAILED${NC}"
        echo -e "${RED}========================================${NC}"
        echo ""

        # Get logs
        echo -e "${YELLOW}Last 30 lines of logs:${NC}"
        LOGS=$(api "/applications/${UUID}/logs")

        echo "$LOGS" | python3 -c "
import sys,json
try:
    d = json.load(sys.stdin)
    logs = d if isinstance(d, list) else d.get('logs', [])
    if isinstance(logs, list):
        for entry in logs[-30:]:
            if isinstance(entry, dict) and not entry.get('hidden', False):
                ts = entry.get('timestamp', '')[:19]
                msg = entry.get('output', '')[:150]
                print(f'{ts} | {msg}')
except:
    print('(no logs available)')
" 2>/dev/null

        echo ""
        if [ "$AUTO_FIX" = "yes" ]; then
            echo -e "${YELLOW}Auto-fix mode: waiting 30s then retrying...${NC}"
            sleep 30
        else
            echo -e "${YELLOW}To auto-retry, run with --fix flag${NC}"
            echo -e "${YELLOW}Waiting 60s before retry...${NC}"
            sleep 60
        fi
        echo ""
    fi
done

echo ""
echo -e "${RED}Max loops (${MAX_LOOPS}) reached. Giving up.${NC}"
exit 1
