#!/bin/bash
# List all projects from API + config
# Usage: ./list.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/coolify.sh"

check_api_key || exit 1

echo -e "${BLUE}=== Configured Projects ===${NC}"
list_configured_projects
echo ""

echo -e "${BLUE}=== All Coolify Applications ===${NC}"
API_CALL="curl -s -H 'Authorization: Bearer ${COOLIFY_API_KEY}' '${API_BASE}/applications'"
APPS=$(eval "$API_CALL" | python3 -c "
import sys,json
d = json.load(sys.stdin)
for app in d:
    print(f\"{app.get('uuid')}: {app.get('name')} [{app.get('status')}]\")
" 2>/dev/null)
echo "$APPS"
