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

# port-guard.sh — blocks deployments that would conflict with existing ports
set -euo pipefail

RESERVE_DB="$AGENTS_HOME/safety-scripts/.port-reservations.db"
LOG="$AGENTS_HOME/logs/port-guard.log"
mkdir -p "$(dirname "$RESERVE_DB")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

die() { echo "=== PORT GUARD === $*"; log "ERROR: $*"; exit 1; }

# Known safe ports
is_system_port() {
    case "$1" in
        22|25|53|80|443|3306|5432|6379|27017|9200) return 0 ;;
        3000|3001|5000|5001|5002|5003|8080|8081|8082|8083) return 0 ;;
        18789|9229|9337|9357|9377) return 0 ;;
        *) return 1 ;;
    esac
}

get_system_port_label() {
    case "$1" in
        22) echo "ssh" ;;
        25) echo "smtp" ;;
        53) echo "dns" ;;
        80) echo "http" ;;
        443) echo "https" ;;
        3306) echo "mysql" ;;
        5432) echo "postgres" ;;
        6379) echo "redis" ;;
        27017) echo "mongodb" ;;
        9200) echo "elasticsearch" ;;
        3000|3001) echo "node-dev" ;;
        5000|5001|5002|5003) echo "app" ;;
        8080) echo "http-alt" ;;
        8081) echo "coolify" ;;
        8082) echo "mc-claude" ;;
        8083) echo "mc-codex" ;;
        18789) echo "mc-openclaw" ;;
        9229) echo "node-debug" ;;
        9337|9357|9377) echo "stealth-browser" ;;
        *) echo "unknown" ;;
    esac
}

is_listening() {
    ss -tlnp 2>/dev/null | grep -q ":$1 " && return 0 || return 1
}

show_conflict() {
    local port="$1"
    local label="$2"
    local reason="$3"
    echo ""
    echo "=== PORT GUARD — CONFLICT BLOCKED ==="
    echo "Port $port: $reason"
    echo "Label: $label"
    echo ""
    echo "Active on port:"
    ss -tlnp 2>/dev/null | grep ":$port " || netstat -tlnp 2>/dev/null | grep ":$port "
    echo ""
    echo "Use: export PORT_GUARD_FORCE=1 to override"
    echo ""
    log "BLOCKED: port=$port label=$label reason=$reason"
    return 1
}

do_check() {
    local port="$1"
    local label="${2:-unknown}"

    if is_system_port "$port"; then
        local sys_label
        sys_label=$(get_system_port_label "$port")
        if [ "${PORT_GUARD_FORCE:-0}" != "1" ]; then
            show_conflict "$port" "$label" "reserved for system service: $sys_label"
            return $?
        fi
        log "FORCE: overriding system port $port ($sys_label)"
    fi

    if is_listening "$port"; then
        # Check reservation DB
        if [ -f "$RESERVE_DB" ]; then
            local res_line
            res_line=$(grep "^${port}|" "$RESERVE_DB" 2>/dev/null || true)
            if [ -n "$res_line" ]; then
                local res_label
                local res_pid
                res_label=$(echo "$res_line" | cut -d'|' -f2)
                res_pid=$(echo "$res_line" | cut -d'|' -f3)
                if [ -n "$res_pid" ] && kill -0 "$res_pid" 2>/dev/null; then
                    log "PORT=$port OK — reserved by $res_label (PID=$res_pid)"
                    return 0
                else
                    # Stale — clean
                    grep -v "^${port}|" "$RESERVE_DB" > "$RESERVE_DB.tmp"
                    mv "$RESERVE_DB.tmp" "$RESERVE_DB"
                    log "STALE: removed stale reservation port=$port"
                fi
            fi
        fi

        if [ "${PORT_GUARD_FORCE:-0}" != "1" ]; then
            show_conflict "$port" "$label" "in use by another process"
            return $?
        fi
        log "FORCE: overriding port $port conflict"
    fi

    log "OK: port=$port available for $label"
    return 0
}

do_reserve() {
    local port="$1"
    local label="$2"
    local pid="${3:-$$}"
    echo "$port|$label|$pid|$(date '+%s')" >> "$RESERVE_DB"
    log "RESERVED: port=$port label=$label pid=$pid"
}

do_release() {
    local label="$1"
    local port
    port=$(grep "|$label|" "$RESERVE_DB" 2>/dev/null | cut -d'|' -f1 | head -1 || true)
    if [ -n "$port" ]; then
        grep -v "|$label|" "$RESERVE_DB" > "$RESERVE_DB.tmp"
        mv "$RESERVE_DB.tmp" "$RESERVE_DB"
        log "RELEASED: label=$label port=$port"
    else
        log "RELEASE: label=$label not found"
    fi
}

do_status() {
    echo "=== Active Listeners ==="
    ss -tlnp 2>/dev/null | grep LISTEN || echo "(none)"
    echo ""
    echo "=== Port Reservations ==="
    if [ -f "$RESERVE_DB" ]; then
        cat "$RESERVE_DB"
    else
        echo "(none)"
    fi
}

ACTION="$1"
shift

case "$ACTION" in
    check)
        do_check "$1" "${2:-unknown}"
        ;;
    check-all)
        for port in "$@"; do
            do_check "$port" "deploy" || exit 1
        done
        log "All ports OK: $*"
        ;;
    reserve)
        do_reserve "$1" "$2" "$3"
        ;;
    release)
        do_release "$1"
        ;;
    status)
        do_status
        ;;
    *)
        echo "Usage: port-guard.sh check|check-all|reserve|release|status"
        exit 1
        ;;
esac
