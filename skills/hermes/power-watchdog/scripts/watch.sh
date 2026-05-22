#!/bin/bash
# power-watchdog — Unified self-healing watchdog for the entire skill ecosystem
# Usage: watch.sh [run|report|install-cron]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
HERMES_SKILLS="$HOME/.hermes/skills"
CLAUDE_SKILLS="$HOME/.claude/skills"
LOG="$HOME/.hermes/memory/watchdog.log"
LOCK="$HOME/.hermes/memory/watchdog.lock"
STATUS_DIR="$HOME/.hermes/memory/watchdog-status"

# Thresholds
MAX_SYMLINK_AGE_SEC=1800   # 30 min — symlink older than this = stale
MAX_LOG_AGE_SEC=1800       # 30 min — log not written in 30min = stuck
WATCHDOG_CRON="*/10 * * * *"
SKILL_SYNC_CRON="*/15 * * * *"
GRAPHIFY_CRON="*/15 * * * *"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[watchdog $(date +%H:%M:%S)]${NC} $1" | tee -a "$LOG"; }
ok()  { echo -e "  ${GREEN}✅${NC}  $*"; }
fail(){ echo -e "  ${RED}❌${NC}  $*"; ((issues++)) || true; }
warn(){ echo -e "  ${YELLOW}⚠️${NC}  $*"; ((warnings++)) || true; }
info(){ echo -e "  ${BLUE}ℹ️${NC}  $*"; }

# Counters
issues=0; warnings=0; heals=0

# ─── Lock to prevent overlapping runs ─────────────────────────────────────────
acquire_lock() {
    if [ -f "$LOCK" ]; then
        local pid age
        pid=$(cat "$LOCK" 2>/dev/null || echo "")
        age=$(($(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0)))
        if [ -n "$pid" ] && [ "$age" -lt 300 ] && kill -0 "$pid" 2>/dev/null; then
            echo "Already running (PID $pid, ${age}s old) — exiting"
            exit 0
        fi
        warn "Stale lock found (PID $pid, ${age}s) — taking over"
    fi
    echo $$ > "$LOCK"
}
release_lock() { rm -f "$LOCK"; }
trap release_lock EXIT

# ─── Sub-commands ─────────────────────────────────────────────────────────────

cmd_report() {
    echo "=== power-watchdog report [$(date '+%Y-%m-%d %H:%M:%S')] ==="
    check_skill_sync_cron
    check_hermes_watchdog_cron
    check_graphify_cron
    check_symlinks
    check_honcho_api
    check_docker_containers
    check_git_backup
    check_memory_dirs
    check_graphify_cli
    check_sync_log
    echo ""
    echo "Issues: $issues | Warnings: $warnings"
}

cmd_run() {
    local start_ms
    start_ms=$(date +%s%3N)
    mkdir -p "$(dirname "$LOG")" "$(dirname "$LOCK")" "$STATUS_DIR"
    acquire_lock

    echo "" >> "$LOG"
    log "=== power-watchdog starting ==="

    # Run all checks
    cmd_report > >(tee -a "$LOG")

    local end_ms elapsed
    end_ms=$(date +%s%3N)
    elapsed=$(( (end_ms - start_ms) / 1000 ))
    log "=== power-watchdog done: ${elapsed}s | issues=$issues heals=$heals ==="

    # Write status for cron monitor
    echo "{\"ts\":\"$(date -Iseconds)\",\"issues\":$issues,\"warnings\":$warnings,\"elapsed_ms\":$elapsed}" \
        > "$STATUS_DIR/last-run.json"

    release_lock
    return 0
}

cmd_install_cron() {
    log "Installing power-watchdog cron..."
    local cron_line="*/10 * * * * bash $SCRIPT_DIR/watch.sh run >> $LOG 2>&1"
    (crontab -l 2>/dev/null | grep -v "power-watchdog") | crontab - 2>/dev/null || true
    echo "$cron_line" | crontab - 2>/dev/null || {
        warn "Could not install cron via crontab — manual entry:"
        warn "  $cron_line"
    }
    log "power-watchdog cron installed: */10 * * * *"
}

# ─── Individual checks ────────────────────────────────────────────────────────

check_skill_sync_cron() {
    echo -n "  skill-sync cron: "
    if crontab -l 2>/dev/null | grep -q "skill-sync.*cron"; then
        ok "alive ($(crontab -l 2>/dev/null | grep 'skill-sync' | grep -o '[0-9*/,:-]*[0-9][0-9*,/-]*' | head -1))"
    else
        fail "MISSING — reinstalling..."
        bash "$HERMES_SKILLS/skill-sync/scripts/sync.sh" install-cron 2>/dev/null || true
        ((heals++)) || true
    fi
}

check_hermes_watchdog_cron() {
    echo -n "  hermes-memory watchdog: "
    if crontab -l 2>/dev/null | grep -q "power-watchdog\|hermes-memory.*watchdog"; then
        ok "alive (superseded by power-watchdog)"
    else
        fail "MISSING — reinstalling hermes-memory watchdog..."
        local SCRIPT="$HERMES_SKILLS/hermes-memory-aatos/scripts/watchdog.sh"
        if [ -f "$SCRIPT" ]; then
            (crontab -l 2>/dev/null | grep -v "hermes-memory"; \
                echo "*/10 * * * * bash $SCRIPT run >> $HOME/.hermes/memory/watchdog.log 2>&1") \
                | crontab - 2>/dev/null || true
            ((heals++)) || true
        else
            warn "hermes-memory watchdog script not found"
        fi
    fi
}

check_graphify_cron() {
    echo -n "  graphify-bootstrap cron: "
    if crontab -l 2>/dev/null | grep -q "graphify-bootstrap"; then
        ok "alive"
    else
        warn "MISSING — consider installing graphify-bootstrap cron"
    fi
}

check_symlinks() {
    echo -n "  Skill symlinks: "
    local broken=0 total=0
    for skill_path in "$HERMES_SKILLS"/*/; do
        [ -d "$skill_path" ] || continue
        ((total++)) || true
        skill_name="$(basename "$skill_path")"
        target="$CLAUDE_SKILLS/$skill_name"
        if [ -L "$target" ] && [ ! -e "$target" ]; then
            # Broken symlink — heal it
            ln -sfn "$skill_path" "$target"
            warn "fixed: $skill_name (broken symlink)"
            ((heals++)) || true
            ((broken++)) || true
        fi
    done
    if [ "$broken" -eq 0 ]; then
        ok "$total/$total valid"
    else
        ok "$((total - broken))/$total valid (fixed $broken broken)"
    fi
}

check_honcho_api() {
    echo -n "  Honcho API: "
    local resp
    resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8000/health 2>/dev/null || echo "000")
    if [ "$resp" = "200" ]; then
        ok "healthy"
    else
        fail "down (HTTP $resp) — attempting docker restart..."
        cd /root/honcho && docker compose restart 2>/dev/null || docker restart honcho-api-1 2>/dev/null || true
        sleep 3
        resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8000/health 2>/dev/null || echo "000")
        if [ "$resp" = "200" ]; then
            ok "restarted successfully"
            ((heals++)) || true
        else
            fail "still down after restart attempt"
        fi
    fi
}

check_docker_containers() {
    echo -n "  Docker containers: "
    local running=0 total=3
    for container in honcho-api-1 honcho-database-1 honcho-redis-1; do
        if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container}$"; then
            ((running++)) || true
        fi
    done
    if [ "$running" -eq "$total" ]; then
        ok "$running/$total running"
    else
        fail "$running/$total running — restarting..."
        cd /root/honcho && docker compose restart 2>/dev/null || true
        ((heals++)) || true
    fi
}

check_git_backup() {
    echo -n "  Git backup repo: "
    local repo="$HOME/.hermes/memory-backup.git"
    if [ -d "$repo" ] && [ -d "$repo/objects" ]; then
        ok "healthy"
    else
        fail "MISSING — recreating..."
        mkdir -p "$repo"
        git init --bare "$repo" 2>/dev/null || true
        # Re-initialize backup dir as working copy
        mkdir -p "$HOME/.hermes/memory"
        cd "$HOME/.hermes/memory" && git init 2>/dev/null || true
        (cd "$HOME/.hermes/memory" && git remote add origin "$repo" 2>/dev/null || true) || true
        ((heals++)) || true
    fi
}

check_memory_dirs() {
    echo -n "  Memory dirs: "
    local missing=0
    for dir in "$HOME/.hermes/memory/daily" "$HOME/.hermes/memory/weekly" \
               "$HOME/.hermes/memory/graphify" "$HOME/.hermes/memory-backup.git"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            warn "created: $dir"
            ((missing++)) || true
        fi
    done
    if [ "$missing" -eq 0 ]; then
        ok "all present"
    else
        ok "created $missing missing dirs"
        ((heals++)) || true
    fi
}

check_graphify_cli() {
    echo -n "  Graphify CLI: "
    if command -v graphify &>/dev/null; then
        ok "available"
    else
        warn "not in PATH"
    fi
}

check_sync_log() {
    echo -n "  skill-sync.log: "
    if [ ! -f "$HOME/.hermes/memory/skill-sync.log" ]; then
        warn "not found (will be created on next sync)"
    else
        local age
        age=$(($(date +%s) - $(stat -c %Y "$HOME/.hermes/memory/skill-sync.log" 2>/dev/null || echo 0)))
        if [ "$age" -gt "$MAX_LOG_AGE_SEC" ]; then
            warn "${age}s old (stale)"
        else
            ok "recent (${age}s ago)"
        fi
    fi
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────
ACTION="${1:-run}"
case "$ACTION" in
    run)          cmd_run ;;
    report)       cmd_report ;;
    install-cron) cmd_install_cron ;;
    *)            echo "Usage: watch.sh [run|report|install-cron]" ;;
esac
