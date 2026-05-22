#!/bin/bash
# =============================================================================
# vault-install.sh — Install vault-security from source
# =============================================================================
# Downloads/updates vault-security source from canonical location or git,
# installs Docker Compose stack (vault-api + vault-postgres + isolated-agent).
#
# Usage (as root):
#   bash vault-install.sh [--update]
#
# Self-locating: finds its own script dir to locate source
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO()    { echo -e "${GREEN}[INFO]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
ERROR()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
STEP()    { echo -e "${BLUE}[STEP]${NC} $1"; }
OK()      { echo -e "${GREEN}[OK]${NC} $1"; }

# Self-locating
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${SCRIPT_DIR%/scripts}"

UPDATE="${1:-}"
[[ "$1" == "--update" ]] && UPDATE=true || UPDATE=false

# Canonical source location
VAULT_SOURCE="${VAULT_SOURCE:-/opt/vault-security}"
VAULT_DEST="/opt/vault-security"
VAULT_DOCKER_DIR="$VAULT_DEST/docker"

# Git source (if different from dest)
VAULT_GIT_REPO="https://github.com/aatos-git-collab/server-merge"
VAULT_GIT_BRANCH="merged-servers"
VAULT_GIT_SRC=".servers"

# =============================================================================
# Preflight
# =============================================================================
[[ $(id -u) -eq 0 ]] || { echo "Must run as root"; exit 1; }

# =============================================================================
# Detect source: use existing /opt/vault-security or clone from git
# =============================================================================
detect_source() {
    if [[ -d "$VAULT_SOURCE" && -d "$VAULT_SOURCE/api" ]]; then
        echo "$VAULT_SOURCE"
        return 0
    fi
    return 1
}

# =============================================================================
# Clone vault source from git (aatos-git-collab/server-merge/.servers)
# =============================================================================
clone_source() {
    local tmp_clone="/tmp/vault-security-clone"

    STEP "Cloning vault source from $VAULT_GIT_REPO (branch: $VAULT_GIT_BRANCH)..."

    rm -rf "$tmp_clone"
    GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$VAULT_GIT_BRANCH" "$VAULT_GIT_REPO" "$tmp_clone" 2>/dev/null \
        || { ERROR "Git clone failed"; exit 1; }

    # The vault-security structure is at .servers — copy to /opt/vault-security
    mkdir -p /opt
    cp -r "$tmp_clone/$VAULT_GIT_SRC" "$VAULT_DEST"
    rm -rf "$tmp_clone"

    OK "Cloned to $VAULT_DEST"
}

# =============================================================================
# Copy or update source
# =============================================================================
install_source() {
    if [[ -d "$VAULT_DEST" && -d "$VAULT_DEST/api" ]]; then
        if [[ "$UPDATE" == "true" ]]; then
            STEP "Updating vault source..."
            clone_source
        else
            INFO "Vault source already exists at $VAULT_DEST (use --update to refresh)"
        fi
    else
        STEP "Installing vault source..."
        clone_source
    fi
}

# =============================================================================
# Ensure Docker is available
# =============================================================================
check_docker() {
    if ! command -v docker &>/dev/null; then
        ERROR "Docker not installed"
        exit 1
    fi
    if ! docker info &>/dev/null; then
        ERROR "Docker daemon not running"
        exit 1
    fi
    OK "Docker available"
}

# =============================================================================
# Build Docker images
# =============================================================================
build_images() {
    STEP "Building vault Docker images..."

    if [[ ! -d "$VAULT_DOCKER_DIR" ]]; then
        ERROR "Docker dir not found at $VAULT_DOCKER_DIR"
        exit 1
    fi

    cd "$VAULT_DOCKER_DIR"

    # Build without cache pull for fresh build
    docker compose build --pull 2>&1 | tail -5

    OK "Docker images built"
}

# =============================================================================
# Start vault stack
# =============================================================================
start_vault() {
    STEP "Starting vault-security stack..."

    cd "$VAULT_DOCKER_DIR"
    docker compose down 2>/dev/null || true
    docker compose up -d

    # Wait for postgres
    local max_wait=30
    local waited=0
    while ! docker exec vault-postgres pg_isready -U vaultuser &>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [[ $waited -ge $max_wait ]]; then
            ERROR "Postgres failed to start within ${max_wait}s"
            exit 1
        fi
    done

    # Wait for vault-api
    waited=0
    while ! curl -sf https://localhost:8443/health &>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [[ $waited -ge 15 ]]; then
            ERROR "vault-api failed to start within ${waited}s"
            docker logs vault-api 2>&1 | tail -5
            exit 1
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
    echo "  Update mode: $UPDATE"
    echo "============================================"
    echo ""

    check_docker
    install_source
    build_images
    start_vault

    echo ""
    OK "Vault-security installed and running"
    echo ""
    echo "  vault-api:       https://localhost:8443"
    echo "  isolated-agent:  https://localhost:8444"
    echo ""
    echo "  HEALTH:"
    curl -sf https://localhost:8443/health | head -1 || echo "  vault-api: FAIL"
    curl -sf https://localhost:8444/health | head -1 || echo "  isolated-agent: FAIL"
    echo ""
}

main
