#!/bin/bash
# Detect AGENTS_HOME — allows install on any user home
if [ -z "$AGENTS_HOME" ]; then
    _self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Traverse up to find .agents-manager directory
    if [ "$(basename "$_self")" = "safety-scripts" ]; then
        AGENTS_HOME="$(dirname "$_self")"
    elif [ "$(basename "$_self")" = "watchdogs" ]; then
        AGENTS_HOME="$(dirname "$(dirname "$_self")")"
    elif [ "$(basename "$_self")" = ".monitor" ]; then
        AGENTS_HOME="$(dirname "$_self")"
    elif [ "$(basename "$_self")" = "git-hooks" ]; then
        AGENTS_HOME="$(dirname "$_self")"
    elif [ "$(basename "$_self")" = ".monitor/watchdogs" ]; then
        AGENTS_HOME="$(dirname "$(dirname "$_self")")"
    else
        AGENTS_HOME="/root/.agents-manager"
    fi
    export AGENTS_HOME
fi

# container-guard.sh — validates docker-compose before deploying
# Prevents: port conflicts, conflicting container names, missing env vars
set -euo pipefail

PORT_GUARD="$AGENTS_HOME/safety-scripts/port-guard.sh"
LOG="$AGENTS_HOME/logs/container-guard.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

check_compose() {
    local compose_file="${1:-docker-compose.yml}"
    local label="${2:-deploy}"

    if [ ! -f "$compose_file" ]; then
        log "ERROR: $compose_file not found"
        return 1
    fi

    log "Checking $compose_file..."

    # Extract ports from compose file
    PORTS=$(grep -E "^\s+(- |\")?[0-9]+:" "$compose_file" 2>/dev/null | \
            grep -oE "[0-9]{4,5}" | sort -n | uniq || true)

    if [ -n "$PORTS" ]; then
        log "Ports found in $compose_file: $PORTS"
        for port in $PORTS; do
            if [ -x "$PORT_GUARD" ]; then
                "$PORT_GUARD" check "$port" "$label" || {
                    log "BLOCKED: port conflict in $compose_file"
                    return 1
                }
            fi
        done
    fi

    # Check for conflicting container names
    CONTAINERS=$(grep -E "^\s+container_name:" "$compose_file" 2>/dev/null | \
                  awk '{print $2}' | tr -d '"' || true)
    if [ -n "$CONTAINERS" ]; then
        for c in $CONTAINERS; do
            if docker ps -a --format '{{.Names}}' | grep -q "^${c}$"; then
                log "WARN: container name '$c' already exists (will recreate)"
            fi
        done
    fi

    log "OK: $compose_file validated"
    return 0
}

check_ports_only() {
    local port_list="$1"
    local label="${2:-deploy}"
    for port in $port_list; do
        [ -x "$PORT_GUARD" ] && "$PORT_GUARD" check "$port" "$label" || return 1
    done
    log "Ports OK: $port_list"
}

case "$1" in
    check|validate)
        check_compose "$2" "${3:-unknown}"
        ;;
    check-ports)
        check_ports_only "$2" "${3:-deploy}"
        ;;
    *)
        echo "Usage: container-guard.sh check <compose.yml> [label]"
        echo "       container-guard.sh check-ports <port1 port2...> [label]"
        ;;
esac
