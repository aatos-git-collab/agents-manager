#!/bin/bash
# =============================================================================
# vault-install.sh — Build + start vault from skill source (in-place)
# =============================================================================
# Vault works in-place from skill directory.
# Docker builds and runs from the skill's vault/docker/ dir.
# No intermediate /opt or /root/.hermes/tools copying.
#
# Usage (as root):
#   bash vault-install.sh [--rebuild]
#
# SELF-LOCATING
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
STEP()    { echo -e "${BLUE}[STEP]${NC} $1"; }
OK()      { echo -e "${GREEN}[OK]${NC} $1"; }

# =============================================================================
# SELF-LOCATING
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${SCRIPT_DIR%/*}"    # skills/devops/workspace-manager/vault/scripts → skills/devops/workspace-manager/vault
VAULT_DIR="$SKILL_DIR"
VAULT_DOCKER_DIR="$VAULT_DIR/docker"

REBUILD="${1:-}"
[[ "$1" == "--rebuild" ]] && REBUILD=true || REBUILD=false

# =============================================================================
# Preflight
# =============================================================================
[[ $(id -u) -eq 0 ]] || { echo "Must run as root"; exit 1; }

if ! command -v docker &>/dev/null; then
    ERROR "Docker not installed"
    exit 1
fi

if [[ ! -d "$VAULT_DOCKER_DIR" ]]; then
    ERROR "Vault docker dir not found at $VAULT_DOCKER_DIR"
    exit 1
fi

# =============================================================================
# Stop existing containers
# =============================================================================
stop_vault() {
    STEP "Stopping vault containers..."
    cd "$VAULT_DOCKER_DIR"
    docker compose down 2>/dev/null || true
    OK "Containers stopped"
}

# =============================================================================
# Build Docker images (in-place from skill source)
# =============================================================================
build_images() {
    STEP "Building vault Docker images..."
    cd "$VAULT_DOCKER_DIR"
    docker compose build --pull 2>&1 | tail -8
    OK "Images built"
}

# =============================================================================
# Start vault stack
# =============================================================================
start_vault() {
    STEP "Starting vault-security stack..."
    cd "$VAULT_DOCKER_DIR"
    docker compose up -d

    # Wait for postgres
    local max_wait=30 waited=0
    while ! docker exec vault-postgres pg_isready -U vaultuser &>/dev/null 2>&1; do
        sleep 1; waited=$((waited + 1))
        if [[ $waited -ge $max_wait ]]; then
            ERROR "Postgres failed to start within ${max_wait}s"
            exit 1
        fi
    done

    # Wait for vault-api
    waited=0
    while ! curl -sf --max-time 3 http://localhost:8443/health &>/dev/null; do
        sleep 1; waited=$((waited + 1))
        if [[ $waited -ge 20 ]]; then
            ERROR "vault-api failed to start"
            docker logs vault-api 2>&1 | tail -8
            exit 1
        fi
    done

    # Wait for isolated-agent
    waited=0
    while ! curl -sf --max-time 3 http://localhost:8444/health &>/dev/null; do
        sleep 1; waited=$((waited + 1))
        if [[ $waited -ge 15 ]]; then
            WARN "isolated-agent not yet bootstrapped (run create-agent.sh to bootstrap)"
            break
        fi
    done

    OK "Vault stack started"
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo "============================================"
    echo "  Vault-Security Install"
    echo "  Vault: $VAULT_DIR"
    echo "  Rebuild: $REBUILD"
    echo "============================================"
    echo ""

    stop_vault
    build_images
    start_vault

    echo ""
    OK "Vault-Security installed and running"
    echo ""
    echo "  Vault dir:   $VAULT_DIR"
    echo "  vault-api:   http://localhost:8443"
    echo "  isolated-agent: http://localhost:8444 (not bootstrapped)"
    echo ""
    echo "  Bootstrap agent:"
    echo "    bash $VAULT_DIR/scripts/create-agent.sh"
    echo ""
}

main
