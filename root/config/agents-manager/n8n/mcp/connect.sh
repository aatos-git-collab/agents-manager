#!/bin/bash
# n8n-mcp connect script - adds n8n-mcp MCP server to Claude Code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load env
source .env 2>/dev/null || true

PORT="${PORT:-3001}"
AUTH_TOKEN="${AUTH_TOKEN}"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo "Connecting n8n-mcp to Claude Code..."
echo "  Host: localhost:$PORT"
echo ""

# Check if n8n-mcp is running
if ! docker ps --format '{{.Names}}' | grep -q "^n8n-mcp$"; then
  echo "n8n-mcp container not running. Starting..."
  ./start.sh
fi

# Wait for health
sleep 3

echo "Adding n8n MCP server to Claude Code settings..."

# Use python for reliable JSON manipulation
python3 << PYEOF
import json
import os

settings_file = os.path.expanduser("$CLAUDE_SETTINGS")
port = "$PORT"
token = "$AUTH_TOKEN"

# Read existing settings
if os.path.exists(settings_file):
    with open(settings_file, 'r') as f:
        settings = json.load(f)
else:
    settings = {}

# Ensure mcpServers exists
if 'mcpServers' not in settings:
    settings['mcpServers'] = {}

# Add n8n-mcp server
settings['mcpServers']['n8n-mcp'] = {
    "url": f"http://127.0.0.1:{port}/mcp",
    "headers": {
        "Authorization": f"Bearer {token}"
    }
}

# Write back
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print(f"Added n8n-mcp to {settings_file}")
PYEOF

echo ""
echo "Done! Restart Claude Code or use /mcp command to load the new server."
echo ""
echo "To verify: ./test.sh"