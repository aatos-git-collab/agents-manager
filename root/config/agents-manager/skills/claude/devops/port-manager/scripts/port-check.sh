#!/bin/bash
# port-check.sh — MANDATORY gate for all docker deployments
# Usage: ./port-check.sh [compose_file.yml] [service_name]
# Exits 0 = proceed, Exit 1 = BLOCK

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ===== PORT REGISTRY =====
# These ports are ALLOCATED. If any is in use → BLOCK.
ALLOCATED_PORTS=(
    80      # coolify-proxy / traefik
    443     # coolify-proxy / traefik
    8080    # coolify-internal
    8081    # coolify-prod
    8010    # coolify-dev
    1025    # coolify-mailpit SMTP
    8025    # coolify-mailpit SMTP-ALT
    9000    # coolify-minio
    9001    # coolify-minio console
    6379    # coolify-redis / dev-redis
    5432    # coolify-postgres / dev-postgres
    6001    # coolify-soketi / dev-soketi
    6002    # coolify-dev-soketi-alt
    5174    # coolify-vite
    8443    # code-server / coolify-internal
    8453    # code-server-ext
    3333    # mission-control
    5000    # lead-gen
    5001    # payment
    5002    # delivery
    5003    # creator-tools
    8880    # webbuilder-traefik
    8443    # webbuilder-traefik-ssl
    8881    # webbuilder-traefik-alt
    9377    # stealth-browser
)

# ===== RESERVED (system) =====
RESERVED_PORTS=(22 53)

echo "═══════════════════════════════════════════"
echo "  PORT CONFLICT CHECK — PRE-DEPLOY GATE"
echo "═══════════════════════════════════════════"
echo ""

# Parse ports from docker-compose file if provided
EXTRACTED_PORTS=()
if [[ $# -ge 1 && -f "$1" ]]; then
    COMPOSE_FILE="$1"
    echo "Scanning: $COMPOSE_FILE"
    
    # Extract all port mappings (both -p and ports: formats)
    # Match patterns like: - "5000:5000"  or  -p 5000:5000  or  ports: [5000]
    grep -oE '[0-9]+:[0-9]+' "$COMPOSE_FILE" | cut -d: -f1 | sort -u | while read -r port; do
        EXTRACTED_PORTS+=("$port")
    done
    
    echo "Ports declared in compose: ${EXTRACTED_PORTS[*]:-none}"
    echo ""
fi

# Merge with registry
ALL_CHECK_PORTS=("${ALLOCATED_PORTS[@]}")
if [[ ${#EXTRACTED_PORTS[@]} -gt 0 ]]; then
    ALL_CHECK_PORTS+=("${EXTRACTED_PORTS[@]}")
fi

# Dedupe
ALL_CHECK_PORTS=($(printf '%s\n' "${ALL_CHECK_PORTS[@]}" | sort -u | tr '\n' ' '))

echo "Checking ${#ALL_CHECK_PORTS[@]} ports for conflicts..."
echo ""

CONFLICTS=0
CONFLICT_DETAILS=()

for PORT in "${ALL_CHECK_PORTS[@]}"; do
    # Skip reserved system ports in check
    if [[ " ${RESERVED_PORTS[*]} " =~ " ${PORT} " ]]; then
        continue
    fi
    
    # Check what's using the port
    USERS=$(ss -tlnp 2>/dev/null | grep ":${PORT}[[:space:]]" || true)
    DOCKER_USAGE=$(docker ps --format '{{.Ports}}' 2>/dev/null | grep -oE "0\.0\.0\.0:${PORT}|:::${PORT}" || true)
    
    if [[ -n "$USERS" || -n "$DOCKER_USAGE" ]]; then
        ((CONFLICTS++))
        # Extract process info
        PROC_INFO=$(echo "$USERS" | grep -oP 'users:\(\([^)]+\)\)' | head -1 || echo "docker container")
        
        CONFLICT_DETAILS+=("  ✗ PORT $PORT — IN USE")
        CONFLICT_DETAILS+=("    $USERS $DOCKER_USAGE")
        
        echo -e "  ${RED}✗ PORT $PORT${NC} — IN USE"
        echo "    $USERS $DOCKER_USAGE"
    else
        echo -e "  ${GREEN}✓ PORT $PORT${NC} — free"
    fi
done

echo ""
echo "═══════════════════════════════════════════"

if [[ $CONFLICTS -gt 0 ]]; then
    echo -e "${RED}  ⚠️  BLOCKED — $CONFLICTS PORT CONFLICT(S)${NC}"
    echo ""
    echo "  CONFLICT SUMMARY:"
    printf '%s\n' "${CONFLICT_DETAILS[@]}"
    echo ""
    echo "  FIX: Stop the conflicting service before deploying"
    echo ""
    echo "  Common fixes:"
    echo "    docker stop \$(docker ps -q)              # stop all containers"
    echo "    fuser -k PORT/tcp                        # kill process on PORT"
    echo "    ss -tlnp | grep :PORT                    # see what's using it"
    echo ""
    echo "═══════════════════════════════════════════"
    exit 1
else
    echo -e "${GREEN}  ✓ ALL PORTS FREE — DEPLOYMENT APPROVED${NC}"
    echo ""
    echo "═══════════════════════════════════════════"
    exit 0
fi
