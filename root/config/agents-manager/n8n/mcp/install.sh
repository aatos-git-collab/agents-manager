#!/bin/bash
# n8n-mcp install/setup script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Setting up n8n-mcp..."

# Check if .env exists
if [ ! -f .env ]; then
  echo "Creating .env from example..."
  cat > .env << 'EOF'
N8N_API_URL=https://bot.agent.nexeraa.io
AUTH_TOKEN=__REPLACE_WITH_YOUR_TOKEN__
PORT=3001
MCP_MODE=http
LOG_LEVEL=info
NODE_ENV=production
EOF
  echo "Please edit .env and add your AUTH_TOKEN"
  echo "You can generate one with: openssl rand -hex 32"
  exit 1
fi

# Ensure AUTH_TOKEN is set
if ! grep -q "AUTH_TOKEN=" .env || grep "AUTH_TOKEN=__REPLACE" .env > /dev/null 2>&1; then
  echo "Generating AUTH_TOKEN..."
  TOKEN=$(openssl rand -hex 32)
  # Preserve existing values, update or add AUTH_TOKEN
  if grep -q "^AUTH_TOKEN=" .env; then
    sed -i "s/^AUTH_TOKEN=.*/AUTH_TOKEN=$TOKEN/" .env
  else
    echo "AUTH_TOKEN=$TOKEN" >> .env
  fi
fi

# Make scripts executable
chmod +x start.sh stop.sh connect.sh

echo "Setup complete!"
echo ""
echo "To start: ./start.sh"
echo "To stop:  ./stop.sh"
echo ""
echo "Current .env:"
cat .env | grep -v "API_KEY" | sed 's/API_KEY=.*/API_KEY=***/'