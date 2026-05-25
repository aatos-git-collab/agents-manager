#!/bin/bash
# docker-gate.sh — PORT-GATED docker wrapper
# All docker deployments MUST pass through this gate
#
# Usage: ./docker-gate.sh [command] [args]
#
# Commands that require port check:
#   up, start, run, compose up, compose run
#
# Commands that skip port check (safe/read-only):
#   ps, ps -a, stop, kill, rm, rmi, logs, exec, inspect, stats, diff, images, network, volume

set -euo pipefail

GATE_SCRIPT="/root/.hermes/skills/devops/port-manager/scripts/port-check.sh"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

COMMAND="${1:-}"
ARGS="${*:2}"

# Commands that NEED port check
PORT_CHECK_COMMANDS="up start run compose\ up compose\ run"

# Commands that are SAFE (no port check needed)
SAFE_COMMANDS="ps ps\ -a stop kill rm rmi logs exec inspect stats diff images network volume pull build"

is_safe_command() {
    local cmd="$1"
    for safe in $SAFE_COMMANDS; do
        if [[ "$cmd" == "$safe" ]]; then
            return 0
        fi
    done
    return 1
}

# Show banner
echo -e "${YELLOW}"
echo "═══════════════════════════════════════════"
echo "  DOCKER GATE — PORT-SAFE DEPLOYMENT"
echo "═══════════════════════════════════════════"
echo -e "${NC}"

# If no command, just show docker ps
if [[ -z "$COMMAND" ]]; then
    echo "No command given — showing running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 0
fi

# Check if this is a safe/read-only command
if is_safe_command "$COMMAND"; then
    echo -e "${GREEN}✓ Safe command — skipping port check${NC}"
    echo ""
    exec docker $COMMAND $ARGS
fi

# This is a deployment command — MUST pass port check
echo -e "${YELLOW}⚡ Deployment command detected — running port gate...${NC}"
echo ""

# Get compose file if provided
COMPOSE_FILE=""
for i in "$@"; do
    if [[ -f "$i" && "$i" == *.yml || "$i" == *.yaml ]]; then
        COMPOSE_FILE="$i"
        break
    fi
done

# Run port check
if [[ -n "$COMPOSE_FILE" ]]; then
    bash "$GATE_SCRIPT" "$COMPOSE_FILE"
else
    bash "$GATE_SCRIPT"
fi

GATE_RESULT=$?

if [[ $GATE_RESULT -ne 0 ]]; then
    echo ""
    echo -e "${RED}═══════════════════════════════════════════"
    echo "  DEPLOYMENT BLOCKED BY PORT GATE"
    echo -e "═══════════════════════════════════════════${NC}"
    exit 1
fi

# Gate passed — proceed with docker
echo -e "${GREEN}✓ Port gate passed — executing docker $COMMAND $ARGS${NC}"
echo ""
exec docker $COMMAND $ARGS
