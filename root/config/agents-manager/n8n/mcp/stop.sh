#!/bin/bash
# n8n-mcp stop script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping n8n-mcp container..."
docker compose down

echo "n8n-mcp stopped"