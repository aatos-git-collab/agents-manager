#!/bin/bash
# run.sh — camoufox auto-start / self-healing / auto-install
# Usage: run.sh {start|stop|restart|status|health|install|verify}

set -e

CAMOFOX_URL="${CAMOFOX_URL:-http://localhost:9377}"
HERMES_HOME_DIR="${HERMES_DIR:-$HOME/.hermes}"
CAMOFOX_DIR="$HERMES_HOME_DIR/hermes-agent/node_modules/@askjo/camofox-browser"
SKILL_DIR="$HOME/.hermes/skills/hermes-browser"
PIDFILE="$SKILL_DIR/.camofox.pid"
LOGFILE="$SKILL_DIR/camofox.log"
INSTALLLOG="$SKILL_DIR/install.log"
INSTALLER="$SKILL_DIR/install.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log() { echo -e "[$(date '+%H:%M:%S')] $*"; }
log_ok() { log "${GREEN}✓${NC} $1"; }
log_warn() { log "${YELLOW}⚠${NC} $1"; }
log_fail() { log "${RED}✗${NC} $1"; }
step() { log "  → $1"; }

# ── Health check ───────────────────────────────────────────────────────────────
health_check() {
    curl -sf "${CAMOFOX_URL}/health" 2>/dev/null \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if d.get('ok') else 'fail')" 2>/dev/null \
        || echo "fail"
}

# ── Install missing binary ───────────────────────────────────────────────────────
ensure_binary() {
    if ! npx camoufox-js version &>/dev/null; then
        log_warn "camoufox binary missing, installing..."
        if [ -x "$INSTALLER" ]; then
            "$INSTALLER" install 2>&1 | tee -a "$INSTALLLOG"
        else
            log "  Running: npx camoufox-js fetch"
            npx camoufox-js fetch 2>&1 | tee -a "$INSTALLLOG"
        fi
    fi
}

# ── Ensure deps ─────────────────────────────────────────────────────────────────
ensure_deps() {
    if [ ! -d "$CAMOFOX_DIR/node_modules" ]; then
        log_warn "node_modules missing, installing deps..."
        cd "$CAMOFOX_DIR" && npm install --silent 2>&1 | tee -a "$INSTALLLOG"
    fi
}

# ── Check if running ────────────────────────────────────────────────────────────
is_running() {
    if [ -f "$PIDFILE" ]; then
        local pid=$(cat "$PIDFILE")
        kill -0 "$pid" 2>/dev/null && return 0
    fi
    return 1
}

# ── Start camoufox ─────────────────────────────────────────────────────────────
start_camofox() {
    if [ "$(health_check)" = "ok" ]; then
        # Sync PID file with actual running process
        local actual=$(lsof -ti :9377 2>/dev/null || true)
        if [ -n "$actual" ]; then
            echo "$actual" > "$PIDFILE"
            log_ok "camoufox already running at $CAMOFOX_URL (PID $actual)"
        else
            log_ok "camoufox already running at $CAMOFOX_URL"
        fi
        return 0
    fi

    log "Starting camoufox from $CAMOFOX_DIR"
    
    # Auto-install if needed
    ensure_deps
    ensure_binary
    
    cd "$CAMOFOX_DIR"
    CAMOFOX_DEFAULT_OS=windows CAMOFOX_PORT=9377 nohup node server.js >> "$LOGFILE" 2>&1 &
    local pid=$!
    echo $pid > "$PIDFILE"
    log "  PID: $pid, log: $LOGFILE"
    
    # Wait for startup (max 20s)
    for i in $(seq 1 20); do
        sleep 1
        if [ "$(health_check)" = "ok" ]; then
            log_ok "camoufox started (PID $pid)"
            return 0
        fi
    done
    
    log_fail "camoufox failed to start. See: tail -50 $LOGFILE"
    return 1
}

# ── Stop camoufox ─────────────────────────────────────────────────────────────
stop_camofox() {
    if [ -f "$PIDFILE" ]; then
        local pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" && log "Stopped (PID $pid)" || true
        fi
        rm -f "$PIDFILE"
    fi
    # Also kill any stray camoufox on port 9377
    local stray=$(lsof -ti :9377 2>/dev/null || true)
    if [ -n "$stray" ]; then
        log "Killing stray process on port 9377: $stray"
        kill $stray 2>/dev/null || true
    fi
}

# ── Restart ───────────────────────────────────────────────────────────────────
restart_camofox() {
    log "Restarting camoufox..."
    stop_camofox
    sleep 2
    start_camofox
}

# ── Status ─────────────────────────────────────────────────────────────────────
status_camofox() {
    local health=$(health_check)
    if is_running && [ "$health" = "ok" ]; then
        echo "STATUS: running ($(cat $PIDFILE))"
        curl -sf "${CAMOFOX_URL}/health" 2>/dev/null | python3 -m json.tool 2>/dev/null || \
            curl -sf "${CAMOFOX_URL}/health" 2>/dev/null
    else
        echo "STATUS: stopped"
    fi
}

# ── Full self-heal ─────────────────────────────────────────────────────────────
heal() {
    log "=== camoufox self-heal ==="
    local health=$(health_check)
    
    if [ "$health" = "ok" ]; then
        log_ok "camoufox healthy, nothing to do"
        return 0
    fi
    
    log_warn "camoufox unhealthy, attempting repair..."
    
    # Try restart first
    restart_camofox
    
    if [ "$(health_check)" = "ok" ]; then
        log_ok "Self-heal successful"
    else
        log_fail "Self-heal failed"
        log "  Run 'bash $INSTALLER install' for full reinstall"
        return 1
    fi
}

# ── Install ────────────────────────────────────────────────────────────────────
do_install() {
    if [ -x "$INSTALLER" ]; then
        "$INSTALLER" full
    else
        log_warn "install.sh not found, using inline install"
        ensure_deps
        ensure_binary
        verify 2>/dev/null || true
    fi
}

# ── Verify ─────────────────────────────────────────────────────────────────────
verify() {
    log "=== Verifying camoufox install ==="
    local ok=0
    
    if [ -f "$CAMOFOX_DIR/server.js" ]; then
        log_ok "server.js found"
    else
        log_fail "server.js NOT found"
        ok=1
    fi
    step "Checking npm dependencies..."
    if [ -d "$HERMES_HOME_DIR/hermes-agent/node_modules" ]; then
        log_ok "node_modules present (at hermes-agent root)"
    else
        log_fail "node_modules missing at $HERMES_HOME_DIR/hermes-agent/node_modules"
        ok=1
    fi
    
    if npx camoufox-js version 2>&1 | grep -q "Camoufox:"; then
        local ver=$(npx camoufox-js version 2>&1 | grep "Camoufox:" | head -1)
        log_ok "camoufox binary: $ver"
    else
        log_fail "camoufox binary missing"
        ok=1
    fi
    
    for f in src/session-manager.js src/browser-agent.js SKILL.md run.sh; do
        if [ -f "$SKILL_DIR/$f" ]; then
            log_ok "skill: $f"
        else
            log_fail "skill: $f missing"
            ok=1
        fi
    done
    
    [ $ok -eq 0 ] && log_ok "All checks passed" || log_fail "Some checks failed"
    return $ok
}

# ── Main ───────────────────────────────────────────────────────────────────────
case "${1:-start}" in
    start)         start_camofox ;;
    stop)          stop_camofox ;;
    restart)       restart_camofox ;;
    status)        status_camofox ;;
    health)        curl -sf "${CAMOFOX_URL}/health" && echo "" || echo "unreachable" ;;
    heal)          heal ;;
    install)       do_install ;;
    verify)        verify ;;
    *)             echo "Usage: $0 {start|stop|restart|status|health|heal|install|verify}" ;;
esac
