#!/bin/bash
# n8n-mcp startup script - sources .env and starts the container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Set defaults if not defined
export AUTH_TOKEN="${AUTH_TOKEN:-$(openssl rand -hex 32)}"
export PORT="${PORT:-3000}"
export MCP_MODE="${MCP_MODE:-http}"
export LOG_LEVEL="${LOG_LEVEL:-info}"
export NODE_ENV="${NODE_ENV:-production}"

echo "Starting n8n-mcp container..."
echo "  AUTH_TOKEN: ${AUTH_TOKEN:0:8}..."
echo "  PORT: $PORT"
echo "  MCP_MODE: $MCP_MODE"
echo "  N8N_API_URL: ${N8N_API_URL:-not set}"

# Stop existing container if running
docker compose down 2>/dev/null || true

# Check if port is in use and find alternative
PORT="${PORT:-3001}"
if netstat -tuln 2>/dev/null | grep -q ":${PORT} " || ss -tuln 2>/dev/null | grep -q ":${PORT} "; then
  echo "Port $PORT is in use, trying alternative ports..."
  for alt in 3001 3002 3003 3004; do
    if ! netstat -tuln 2>/dev/null | grep -q ":${alt} " && ! ss -tuln 2>/dev/null | grep -q ":${alt} "; then
      PORT=$alt
      # Update .env
      sed -i "s/^PORT=.*/PORT=$PORT/" .env 2>/dev/null || echo "PORT=$PORT" >> .env
      echo "Using port $PORT"
      break
    fi
  done
fi

# Start container
docker compose up -d

# Wait for health check
echo "Waiting for container to be healthy..."
for i in {1..20}; do
  sleep 2
  status=$(docker inspect --format='{{.State.Health.Status}}' n8n-mcp 2>/dev/null || echo "starting")
  echo "  [$i] Status: $status"
  if [ "$status" = "healthy" ]; then
    echo "n8n-mcp is ready!"
    exit 0
  fi
done

echo "Warning: Container may not be fully healthy yet"
docker logs n8n-mcp --tail 10