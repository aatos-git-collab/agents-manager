#!/bin/bash
# n8n-mcp test script - tests the MCP connection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load env
export $(grep -v '^#' .env | xargs)

PORT="${PORT:-3001}"
AUTH_TOKEN="${AUTH_TOKEN}"

if [ -z "$AUTH_TOKEN" ]; then
  echo "Error: AUTH_TOKEN not set in .env"
  exit 1
fi

echo "Testing n8n-mcp at localhost:$PORT"
echo "AUTH_TOKEN: ${AUTH_TOKEN:0:8}..."
echo ""

# Test 1: Health check
echo "=== Test 1: Health Check ==="
HEALTH=$(curl -s http://127.0.0.1:$PORT/health)
echo "Health: $HEALTH"
echo ""

# Test 2: Initialize
echo "=== Test 2: Initialize ==="
RESP=$(curl -s -X POST http://127.0.0.1:$PORT/mcp \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}')

echo "Response: $RESP"
echo ""

# Extract session - n8n-mcp may use cookie or return in different format
# For now, just verify we get a valid initialize response
if echo "$RESP" | grep -q "serverInfo"; then
  echo "✓ Initialize successful"
else
  echo "✗ Initialize failed"
fi