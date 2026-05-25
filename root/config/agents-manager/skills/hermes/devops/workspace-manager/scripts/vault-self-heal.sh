#!/bin/bash
# =============================================================================
# vault-self-heal.sh — Self-healing for vault-security
# =============================================================================
# Checks vault-security health and repairs broken components.
# Run manually or via self-heal.sh.
#
# Usage (as root):
#   bash vault-self-heal.sh          # check + repair
#   bash vault-self-heal.sh --check  # status only
#   bash vault-self-heal.sh --force  # force rebuild + restart
#
# Self-locating: finds its own script dir
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
OK()      { echo -e "${GREEN}[OK]${NC} $1"; }
STEP()    { echo -e "${BLUE}[STEP]${NC} $1"; }

# Self-locating
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${SCRIPT_DIR%/scripts}"
VAULT_DOCKER_DIR="/opt/vault-security/docker"

MODE="${1:-fix}"
[[ "$1" == "--check" ]] && MODE="check"
[[ "$1" == "--force" ]] && MODE="force"

# =============================================================================
# Health checks
# =============================================================================
check_vault_api() {
    if curl -sf --max-time 5 http://localhost:8443/health | grep -q '"status"'; then
        echo "  vault-api: OK"
        return 0
    else
        echo "  vault-api: DOWN"
        return 1
    fi
}

check_isolated_agent() {
    if curl -sf --max-time 5 http://localhost:8444/health | grep -q '"agentMode"'; then
        echo "  isolated-agent: OK"
        return 0
    else
        echo "  isolated-agent: DOWN"
        return 1
    fi
}

check_postgres() {
    if docker exec vault-postgres pg_isready -U vaultuser &>/dev/null; then
        echo "  vault-postgres: OK"
        return 0
    else
        echo "  vault-postgres: DOWN"
        return 1
    fi
}

check_docker_network() {
    if docker network inspect vault-net &>/dev/null; then
        echo "  vault-net: OK"
        return 0
    else
        echo "  vault-net: MISSING"
        return 1
    fi
}

# =============================================================================
# Repair functions
# =============================================================================
repair_vault_net() {
    INFO "Creating vault-net network..."
    docker network create vault-net 2>/dev/null || true
}

repair_postgres() {
    STEP "Starting vault-postgres..."
    cd "$VAULT_DOCKER_DIR"
    docker compose up -d vault-postgres
    local max_wait=30
    local waited=0
    while ! docker exec vault-postgres pg_isready -U vaultuser &>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [[ $waited -ge $max_wait ]]; then
            ERROR "Postgres failed to start"
            return 1
        fi
    done
    OK "vault-postgres started"
}

repair_vault_api() {
    STEP "Building + starting vault-api..."
    cd "$VAULT_DOCKER_DIR"
    docker compose up -d --build vault-api 2>&1 | tail -3
    local max_wait=30
    local waited=0
    while ! curl -sf --max-time 3 http://localhost:8443/health &>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [[ $waited -ge $max_wait ]]; then
            ERROR "vault-api failed to start"
            docker logs vault-api 2>&1 | tail -5
            return 1
        fi
    done
    OK "vault-api started"
}

repair_isolated_agent() {
    STEP "Building + starting isolated-agent..."
    cd "$VAULT_DOCKER_DIR"
    docker compose up -d --build isolated-agent 2>&1 | tail -3
    local max_wait=20
    local waited=0
    while ! curl -sf --max-time 3 http://localhost:8444/health &>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [[ $waited -ge $max_wait ]]; then
            ERROR "isolated-agent failed to start"
            docker logs isolated-agent-carol 2>&1 | tail -5
            return 1
        fi
    done
    OK "isolated-agent started"
}

restart_all() {
    STEP "Restarting entire vault stack..."
    cd "$VAULT_DOCKER_DIR"
    docker compose down 2>/dev/null || true
    docker compose up -d --build 2>&1 | tail -5

    local max_wait=60
    local waited=0
    while ! docker exec vault-postgres pg_isready -U vaultuser &>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [[ $waited -ge $max_wait ]]; then
            ERROR "Postgres failed to start"
            exit 1
        fi
    done

    waited=0
    while ! curl -sf --max-time 3 http://localhost:8443/health &>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [[ $waited -ge 30 ]]; then
            ERROR "vault-api failed to start"
            docker logs vault-api 2>&1 | tail -5
            exit 1
        fi
    done

    waited=0
    while ! curl -sf --max-time 3 http://localhost:8444/health &>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [[ $waited -ge 20 ]]; then
            ERROR "isolated-agent failed to start"
            exit 1
        fi
    done

    OK "Vault stack restarted"
}

# =============================================================================
# Quick full health check — returns 0 if all healthy
# =============================================================================
quick_health() {
    local all_ok=0

    check_postgres || all_ok=1
    check_vault_api || all_ok=1
    check_isolated_agent || all_ok=1

    return $all_ok
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo "============================================"
    echo "  Vault-Security Self-Heal"
    echo "  Mode: $MODE"
    echo "============================================"
    echo ""

    if [[ ! -d "$VAULT_DOCKER_DIR" ]]; then
        ERROR "Vault not installed at $VAULT_DOCKER_DIR"
        echo ""
        INFO "Install with: bash $SCRIPT_DIR/vault-install.sh"
        exit 1
    fi

    if [[ "$MODE" == "check" ]]; then
        INFO "Health check:"
        echo ""
        quick_health
        echo ""
        exit $?
    fi

    INFO "Health check:"
    echo ""
    if quick_health; then
        OK "All vault components healthy — no repair needed"
        echo ""
        exit 0
    fi

    echo ""
    WARN "Some vault components are broken — repairing..."

    if [[ "$MODE" == "force" ]]; then
        restart_all
    else
        # Selective repair
        check_docker_network || repair_vault_net
        check_postgres || repair_postgres
        check_vault_api || repair_vault_api
        check_isolated_agent || repair_isolated_agent
    fi

    echo ""
    INFO "Final health check:"
    echo ""
    if quick_health; then
        OK "All vault components repaired"
    else
        ERROR "Some components still broken"
        exit 1
    fi
    echo ""
}

main
