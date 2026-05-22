#!/bin/bash
# Coolify API - Dynamic project resolution
# Usage: source this in other scripts for API functions

# Determine skill directory
SKILL_DIR="${COOLIFY_SKILL_DIR:-/root/.claude/skills/coolify-workflow}"
CONFIG_FILE="${SKILL_DIR}/config/projects.json"

# Load env using python to handle special chars
load_env() {
    if [ -f /root/.env ]; then
        COOLIFY_API_KEY=$(python3 -c "
import os
with open('/root/.env') as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            k, v = line.split('=', 1)
            if k == 'COOLIFY_API_KEY':
                print(v)
                break
" 2>/dev/null)
        COOLIFY_URL=$(python3 -c "
import os
with open('/root/.env') as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            k, v = line.split('=', 1)
            if k == 'COOLIFY_URL':
                print(v)
                break
" 2>/dev/null)
        [ -n "$COOLIFY_API_KEY" ] && export COOLIFY_API_KEY
        [ -n "$COOLIFY_URL" ] && export COOLIFY_URL
    fi
}

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# API Base
load_api_config() {
    load_env
    export COOLIFY_URL="${COOLIFY_URL:-https://control.agent.nexeraa.io}"
    export API_BASE="${COOLIFY_URL}/api/v1"
}

# Get project UUID by name
get_project_uuid() {
    local name="${1}"
    python3 -c "
import json
with open('${CONFIG_FILE}') as f:
    config = json.load(f)
projects = config.get('projects', {})
if '${name}' in projects:
    print(projects['${name}']['uuid'])
    exit(0)
# Try fuzzy match
for key in projects:
    if '${name}' in key.lower() or key.lower() in '${name}'.lower():
        print(projects[key]['uuid'])
        exit(0)
print('NOT_FOUND')
" 2>/dev/null
}

# Get project config
get_project_config() {
    local name="${1}"
    python3 -c "
import json
with open('${CONFIG_FILE}') as f:
    config = json.load(f)
projects = config.get('projects', {})
if '${name}' in projects:
    print(json.dumps(projects['${name}']))
" 2>/dev/null
}

# List all configured projects
list_configured_projects() {
    python3 -c "
import json
with open('${CONFIG_FILE}') as f:
    config = json.load(f)
projects = config.get('projects', {})
for name, cfg in projects.items():
    print(f'{name}: {cfg.get(\"uuid\")} ({cfg.get(\"git_repo\")}:{cfg.get(\"branch\")})')
" 2>/dev/null
}

# API Call
api() {
    local endpoint="${1}"
    local method="${2:-GET}"
    local data="${3:-}"

    load_api_config

    python3 << EOPYTHON
import subprocess
api_base = "${API_BASE}"
api_endpoint = "${endpoint}"
api_key = "${COOLIFY_API_KEY}"
cmd = [
    'curl', '-s', '-X', '${method}',
    api_base + api_endpoint,
    '-H', 'Authorization: Bearer ' + api_key,
    '-H', 'Content-Type: application/json'
]
if '${data}':
    cmd += ['-d', '${data}']
result = subprocess.run(cmd, capture_output=True, text=True)
print(result.stdout)
EOPYTHON
}

# API Call - raw output
api_raw() {
    local endpoint="${1}"
    local method="${2:-GET}"
    local data="${3:-}"

    load_api_config

    python3 << EOPYTHON
import subprocess
api_base = "${API_BASE}"
api_endpoint = "${endpoint}"
api_key = "${COOLIFY_API_KEY}"
cmd = [
    'curl', '-s', '-X', '${method}',
    api_base + api_endpoint,
    '-H', 'Authorization: Bearer ' + api_key,
    '-H', 'Content-Type: application/json'
]
if '${data}':
    cmd += ['-d', '${data}']
result = subprocess.run(cmd, capture_output=True, text=True)
print(result.stdout)
EOPYTHON
}

# Check API key
check_api_key() {
    load_api_config
    if [ -z "$COOLIFY_API_KEY" ]; then
        echo -e "${RED}Error: COOLIFY_API_KEY not set in /root/.env${NC}"
        return 1
    fi
}

# Pretty print JSON
ppjson() {
    python3 -m json.tool 2>/dev/null
}

# Get deployment logs
# Requires token with read:sensitive or root permission
get_deployment_logs() {
    local uuid="${1}"
    local lines="${2:-}"

    load_api_config

    curl -s "${API_BASE}/deployments/${uuid}" \
        -H "Authorization: Bearer ${COOLIFY_API_KEY}" \
        -H "Content-Type: application/json" 2>/dev/null | python3 -c "
import sys,json
d = json.load(sys.stdin)
logs = d.get('logs', [])
if not logs:
    print('No logs available or insufficient permissions')
    sys.exit(1)

log_entries = json.loads(logs)
for entry in log_entries:
    ts = entry.get('timestamp', '')[:19]
    msg = entry.get('output', '')[:300]
    hidden = entry.get('hidden', False)
    if not hidden:
        print(f'{ts} | {msg}')
" 2>/dev/null
}

# Get deployment logs as raw JSON
get_deployment_logs_raw() {
    local uuid="${1}"

    load_api_config

    curl -s "${API_BASE}/deployments/${uuid}" \
        -H "Authorization: Bearer ${COOLIFY_API_KEY}" \
        -H "Content-Type: application/json" 2>/dev/null | python3 -c "
import sys,json
d = json.load(sys.stdin)
logs = d.get('logs', [])
if logs:
    log_entries = json.loads(logs)
    print(json.dumps(log_entries, indent=2))
else:
    print('{\"error\": \"No logs or insufficient permissions\"}')
" 2>/dev/null
}

# Get deployment status with logs (human readable)
get_deployment_status() {
    local uuid="${1}"

    load_api_config

    curl -s "${API_BASE}/deployments/${uuid}" \
        -H "Authorization: Bearer ${COOLIFY_API_KEY}" \
        -H "Content-Type: application/json" 2>/dev/null | python3 -c "
import sys,json
from datetime import datetime

d = json.load(sys.stdin)
print(f\"Deployment UUID: {d.get('deployment_uuid')}\")
print(f\"Status: {d.get('status')}\")
print(f\"Created: {d.get('created_at')}\")
print(f\"Finished: {d.get('finished_at')}\")
print(f\"Commit: {d.get('commit', '')[:12]}\")
print(f\"Commit Message: {d.get('commit_message', 'N/A')[:100]}\")

app = d.get('application', {})
if app:
    print(f\"Application: {app.get('name')}\")
    print(f\"Application Status: {app.get('status')}\")

logs = d.get('logs', [])
if logs:
    log_entries = json.loads(logs)
    print(f\"\\nLogs ({len(log_entries)} entries):\")
    for entry in log_entries[-20:]:
        ts = entry.get('timestamp', '')[:19]
        msg = entry.get('output', '')[:200]
        hidden = entry.get('hidden', False)
        if not hidden:
            print(f\"  {ts} | {msg}\")
else:
    print('\\nLogs: Not available (may need read:sensitive permission)')
" 2>/dev/null
}
