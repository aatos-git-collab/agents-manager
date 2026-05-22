#!/bin/bash
# watchdog.sh — Hermes Memory System watchdog (every 10 min)
# Auto-detects drift, self-heals, logs results
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$HOME/.hermes/hermes-agent/venv"
GRAPHIFY_REPO="/root/graphify"
MEMORY_GRAPHIFY="$HOME/.hermes/memory/graphify"
MEMORY_DAILY="$HOME/.hermes/memory/daily"
HONCHO_CONFIG="$HOME/.honcho/config.json"
BACKUP_GIT="$HOME/.hermes/memory-backup.git"
LOG="$HOME/.hermes/memory/watchdog.log"
LOG_DIR="$(dirname "$LOG")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { mkdir -p "$LOG_DIR" && echo -e "${BLUE}[watchdog]${NC} $(date '+%Y-%m-%d %H:%M') $*" | tee -a "$LOG"; }
ok()   { echo -e "${GREEN}[OK]${NC}  $*" | tee -a "$LOG"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*" | tee -a "$LOG"; }

# Exit codes: 0=healthy, 1=healed, 2=partial, 3=failed

# ─── Check: Graphify CLI ────────────────────────────────────────────────────
check_graphify() {
    if command -v graphify &>/dev/null; then
        ok "Graphify CLI: available"
        return 0
    elif [ -d "$GRAPHIFY_REPO" ]; then
        warn "Graphify repo present but CLI not in PATH — reinstalling..."
        cd "$GRAPHIFY_REPO" && pip install -e . -q 2>/dev/null || \
        "$VENV/bin/python3" -m pip install -e . -q 2>/dev/null || true
        if command -v graphify &>/dev/null; then
            ok "Graphify CLI: reinstalled"
            return 1
        fi
    fi
    warn "Graphify CLI: not installed (run: graphify hermes install)"
    return 0  # Not fatal
}

# ─── Check: Honcho SDK ──────────────────────────────────────────────────────
check_honcho_sdk() {
    if "$VENV/bin/python3" -c "import honcho" 2>/dev/null || \
       [ -d "$VENV/lib/python3.11/site-packages/honcho_ai-2.1.1.dist-info" ]; then
        ok "Honcho SDK: present"
        return 0
    fi
    warn "Honcho SDK: not installed — installing..."
    "$VENV/bin/python3" -m pip install honcho-ai -q 2>/dev/null || true
    if "$VENV/bin/python3" -c "import honcho" 2>/dev/null; then
        ok "Honcho SDK: reinstalled"
        return 1
    fi
    fail "Honcho SDK: install failed"
    return 2
}

# ─── Check: Honcho Config (THE critical file) ───────────────────────────────
# Honcho is self-hosted at http://localhost:8000
# Config file lets us reconnect to the local server
check_honcho_config() {
    if [ -f "$HONCHO_CONFIG" ]; then
        local size=$(wc -c < "$HONCHO_CONFIG")
        local has_key=$(grep -c '"api_key"' "$HONCHO_CONFIG" 2>/dev/null || echo 0)
        ok "Honcho config: present ($size bytes)"
        if [ "$has_key" -gt 0 ]; then
            ok "Honcho config: API key present"
        else
            warn "Honcho config: no api_key field — may need re-setup"
        fi
        return 0
    fi
    warn "Honcho config: MISSING ($HONCHO_CONFIG)"
    warn "Run 'bash backup.sh restore honcho' to restore from backup"
    return 2
}

# ─── Check: Honcho server containers (self-hosted) ───────────────────────────
check_honcho_server() {
    local container="honcho-api-1"
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
        # null means no healthcheck defined — treat as healthy
        if [ "$health" = "healthy" ] || [ "$health" = "none" ] || [ -z "$health" ]; then
            ok "Honcho server: running (health=${health:-none})"
        else
            warn "Honcho server: unhealthy (health=$health)"
            return 1
        fi
    else
        warn "Honcho server: not running — starting..."
        cd /root/honcho && docker compose up -d 2>/dev/null || true
        sleep 2
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            ok "Honcho server: started"
            return 1
        fi
        fail "Honcho server: could not start"
        return 2
    fi
    return 0
}

# ─── Check: Honcho API connectivity (local server) ───────────────────────────
check_honcho_connectivity() {
    local status=$(curl -s -o /dev/null -w "%{http_code}" \
        http://localhost:8000/health 2>/dev/null || echo "000")

    if [ "$status" = "200" ]; then
        ok "Honcho API: reachable (HTTP $status)"
        return 0
    elif [ "$status" = "000" ]; then
        warn "Honcho API: unreachable — server may be down"
        return 1  # Healed by check_honcho_server
    else
        warn "Honcho API: unexpected status HTTP $status"
        return 1
    fi
}

# ─── Check: Memory dirs ─────────────────────────────────────────────────────
check_memory_dirs() {
    local errors=0
    for dir in "$MEMORY_GRAPHIFY" "$MEMORY_DAILY"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            warn "Created missing dir: $dir"
        elif [ ! -w "$dir" ]; then
            fail "Not writable: $dir"
            ((errors++)) || true
        fi
    done
    if [ "$errors" -eq 0 ]; then
        ok "Memory dirs: OK"
        return 0
    fi
    return 2
}

# ─── Check: Hooks ───────────────────────────────────────────────────────────
check_hooks() {
    local installed=0
    for hook in session-memory-guardian auto-new-trigger; do
        if [ -d "$HOME/.hermes/hooks/$hook" ]; then
            ((installed++)) || true
        fi
    done
    if [ "$installed" -eq 2 ]; then
        ok "Hooks: 2/2 present"
        return 0
    fi
    warn "Hooks: $installed/2 present — reinstalling..."
    bash "$SCRIPT_DIR/run.sh" start 2>/dev/null
    return 1
}

# ─── Check: Git backup repo ────────────────────────────────────────────────
check_backup_git() {
    if [ -d "$BACKUP_GIT" ]; then
        ok "Git backup repo: present"
        return 0
    fi
    warn "Git backup repo: missing — run 'bash backup.sh' to create"
    return 0  # Not fatal
}

# ─── Check: Watchdog cron job ───────────────────────────────────────────────
check_cron() {
    if crontab -l 2>/dev/null | grep -q "hermes-memory-watchdog"; then
        ok "Watchdog cron: scheduled"
        return 0
    fi
    warn "Watchdog cron: not scheduled — reinstalling..."
    (crontab -l 2>/dev/null | grep -v "hermes-memory-watchdog"; \
     echo "*/10 * * * * bash $SCRIPT_DIR/watchdog.sh run >> $LOG 2>&1") | crontab -
    ok "Watchdog cron: reinstalled"
    return 1
}

# ─── Check: Graphify symlinks (graph data lives in pawnshop) ──────────────────
check_graphify_symlinks() {
    local graph_src="/root/pawnshop/graphify-out"
    local graph_json="$MEMORY_GRAPHIFY/graph.json"
    if [ -d "$graph_src" ] && [ ! -L "$graph_json" ] || \
       [ -L "$graph_json" ] && [ ! -e "$graph_json" ]; then
        warn "Graphify symlinks broken — re-linking..."
        ln -sfn "$graph_src/graph.json" "$graph_json"
        ln -sfn "$graph_src/GRAPH_REPORT.md" "$MEMORY_GRAPHIFY/GRAPH_REPORT.md"
        ln -sfn "$graph_src/graph.html" "$MEMORY_GRAPHIFY/graph.html"
        ln -sfn "$graph_src/cache" "$MEMORY_GRAPHIFY/cache"
        ok "Graphify symlinks: re-linked"
        return 1
    fi
    if [ -L "$graph_json" ] && [ -e "$graph_json" ]; then
        ok "Graphify symlinks: OK"
    fi
    return 0
}

# ─── Run all checks ─────────────────────────────────────────────────────────
cmd_run() {
    log "=== Watchdog run starting ==="

    local healed=0
    local failed=0

    check_graphify;              ec=$?; [ $ec -eq 1 ] && healed=1; [ $ec -ge 2 ] && failed=1
    check_graphify_symlinks;     ec=$?; [ $ec -eq 1 ] && healed=1; [ $ec -ge 2 ] && failed=1
    check_honcho_sdk;            ec=$?; [ $ec -eq 1 ] && healed=1; [ $ec -ge 2 ] && failed=1
    check_honcho_server;        ec=$?; [ $ec -eq 1 ] && healed=1; [ $ec -ge 2 ] && failed=1
    check_honcho_config;         ec=$?; [ $ec -eq 1 ] && healed=1; [ $ec -ge 2 ] && failed=1
    check_honcho_connectivity;    ec=$?; [ $ec -eq 1 ] && healed=1; [ $ec -ge 2 ] && failed=1
    check_memory_dirs;            ec=$?; [ $ec -eq 1 ] && healed=1; [ $ec -ge 2 ] && failed=1
    check_hooks;                 ec=$?; [ $ec -eq 1 ] && healed=1; [ $ec -ge 2 ] && failed=1
    check_backup_git;            ec=$?; [ $ec -eq 1 ] && healed=1
    check_cron;                  ec=$?; [ $ec -eq 1 ] && healed=1

    log "=== Watchdog run complete (healed=$healed, failed=$failed) ==="

    [ $failed -gt 0 ] && exit 3
    [ $healed   -gt 0 ] && exit 1
    exit 0
}

cmd_verify() {
    echo "=== Memory System Verify ==="
    bash "$SCRIPT_DIR/run.sh" verify
}

cmd_report() {
    echo "=== Memory System Report ==="
    echo ""
    echo "Honcho config:"
    if [ -f "$HONCHO_CONFIG" ]; then
        cat "$HONCHO_CONFIG"
    else
        echo "  (not configured — run: hermes honcho setup)"
    fi
    echo ""
    echo "Graphify memory files: $(find $MEMORY_GRAPHIFY -type f 2>/dev/null | wc -l)"
    echo "Daily memory files: $(find $MEMORY_DAILY -type f 2>/dev/null | wc -l)"
    echo ""
    echo "Last watchdog log:"
    tail -30 "$LOG" 2>/dev/null || echo "(no log yet)"
    echo ""
    bash "$SCRIPT_DIR/run.sh" status
}

# ─── Dispatch ───────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"

case "${1:-run}" in
    run)    cmd_run ;;
    verify) cmd_verify ;;
    report) cmd_report ;;
    *)      echo "Usage: $0 {run|verify|report}" ;;
esac
