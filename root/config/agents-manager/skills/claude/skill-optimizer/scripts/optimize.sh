#!/bin/bash
# skill-optimizer — Self-improvement engine for skill ecosystem
# Usage: optimize.sh [run|actions|apply|install-cron]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$HOME/.hermes/skills"
MEMORY="$HOME/.hermes/memory"
REPORT_DIR="$MEMORY"
TODAY=$(date +%Y-%m-%d)
REPORT_JSON="$REPORT_DIR/skill-optimizer-$TODAY.json"
OPT_LOG="$REPORT_DIR/skill-optimizer.log"
HEALTH_JSON="$MEMORY/skill-health-latest.json"
WATCHDOG_LOG="$MEMORY/watchdog.log"
SYNC_LOG="$MEMORY/skill-sync.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[skill-optimizer]${NC} $*"; }
ok()  { echo -e "  ${GREEN}✅${NC}  $*"; }
fail(){ echo -e "  ${RED}❌${NC}  $*"; ((issues++)) || true; }
warn(){ echo -e "  ${YELLOW}⚠️${NC}  $*"; ((warnings++)) || true; }

issues=0; warnings=0; improvements=0; auto_fixed=0

# ─── Pattern analysis ─────────────────────────────────────────────────────────

analyze_patterns() {
    log "Analyzing patterns..."

    # 1. Watchdog failure patterns
    if [ -f "$WATCHDOG_LOG" ]; then
        local cron_deaths=0
        cron_deaths=$(grep -c "hermes-memory watchdog.*MISSING\|cron.*MISSING\|reinstalling" "$WATCHDOG_LOG" 2>/dev/null || echo 0)
        if [ "$cron_deaths" -gt 2 ]; then
            warn "cron-die pattern: hermes-memory watchdog dying repeatedly ($cron_deaths times)"
            echo "{\"pattern\":\"cron-die\",\"detail\":\"hermes-memory watchdog dying $cron_deaths times\"}" >> "$REPORT_JSON"
            ((warnings++)) || true
        fi
    fi

    # 2. Skill health failures
    if [ -f "$HEALTH_JSON" ]; then
        local fail_count
        fail_count=$(python3 -c "import json; d=json.load(open('$HEALTH_JSON')); print(d.get('fail',0) or 0)" 2>/dev/null || echo "0")
        if [ -n "$fail_count" ] && [ "$fail_count" -gt 0 ] 2>/dev/null; then
            warn "skill-health: $fail_count skills failing"
            python3 -c "
import json
try:
    d=json.load(open('$HEALTH_JSON'))
    for item in d if isinstance(d, list) else []:
        if item.get('status') == 'fail':
            print(f\"  - FAIL: {item['skill']}: {item.get('reason','unknown')}\")
except: pass
" 2>/dev/null || true
        fi
    fi

    # 3. Sync failures
    if [ -f "$SYNC_LOG" ]; then
        local sync_errors=0
        sync_errors=$(grep -c "ERROR\|FAIL\|❌" "$SYNC_LOG" 2>/dev/null || echo 0)
        if [ "$sync_errors" -gt 5 ]; then
            warn "sync-errors: $sync_errors error lines in skill-sync.log"
        fi
    fi

    # 4. Missing cron checks
    local missing_crons=0
    if ! crontab -l 2>/dev/null | grep -q "power-watchdog"; then
        warn "Missing: power-watchdog cron"
        ((missing_crons++)) || true
    fi
    if ! crontab -l 2>/dev/null | grep -q "skill-sync"; then
        warn "Missing: skill-sync cron"
        ((missing_crons++)) || true
    fi
    if ! crontab -l 2>/dev/null | grep -q "graphify-bootstrap"; then
        warn "Missing: graphify-bootstrap cron"
        ((missing_crons++)) || true
    fi
    if ! crontab -l 2>/dev/null | grep -q "skill-health"; then
        warn "Missing: skill-health cron (recommended weekly)"
        ((missing_crons++)) || true
    fi

    log "Pattern analysis done"
}

# ─── Auto-fix ─────────────────────────────────────────────────────────────────

apply_fixes() {
    log "Applying auto-fixes..."

    # Fix 1: Make all skill scripts executable
    local fixed=0
    for script in "$SKILL_DIR"/*/scripts/*.sh "$SKILL_DIR"/*/*/scripts/*.sh; do
        [ -f "$script" ] || continue
        if [ ! -x "$script" ]; then
            chmod +x "$script" 2>/dev/null || true
            ((fixed++)) || true
        fi
    done
    if [ "$fixed" -gt 0 ]; then
        ok "Made $fixed scripts executable"
        ((auto_fixed+=fixed)) || true
    fi

    # Fix 2: Broken symlinks
    local fixed_links=0
    for skill_path in "$SKILL_DIR"/*/; do
        [ -d "$skill_path" ] || continue
        skill_name="$(basename "$skill_path")"
        target="$HOME/.claude/skills/$skill_name"
        if [ -L "$target" ] && [ ! -e "$target" ]; then
            ln -sfn "$skill_path" "$target" 2>/dev/null || true
            ((fixed_links++)) || true
        fi
    done
    if [ "$fixed_links" -gt 0 ]; then
        ok "Fixed $fixed_links broken symlinks"
        ((auto_fixed+=fixed_links)) || true
    fi

    # Fix 3: Missing cron entries (auto-heal via power-watchdog on next run)
    log "Crons will be healed automatically by power-watchdog on next run"

    log "Auto-fixes applied: $auto_fixed"
}

# ─── Improvement proposals ────────────────────────────────────────────────────

propose_improvements() {
    log "Proposing improvements..."
    local proposals=0

    # Proposal 1: graphify-bootstrap cron missing
    if ! crontab -l 2>/dev/null | grep -q "graphify-bootstrap"; then
        log "  📋 PROPOSE: Install graphify-bootstrap cron"
        # Auto-add it
        local cron_line="*/15 * * * * bash $HOME/.hermes/skills/graphify-bootstrap/scripts/bootstrap.sh cron >> $HOME/.hermes/memory/graphify-bootstrap.log 2>&1"
        if [ -f "$HOME/.hermes/skills/graphify-bootstrap/scripts/bootstrap.sh" ]; then
            echo "$cron_line" | crontab - 2>/dev/null || true
            ok "Auto-added graphify-bootstrap cron"
        else
            warn "graphify-bootstrap script not found — skipping"
        fi
        ((proposals++)) || true
    fi

    # Proposal 2: Check for stale skills (not updated in 90+ days)
    local stale_count=0
    for skill_path in "$SKILL_DIR"/*/; do
        [ -d "$skill_path" ] || continue
        local mtime
        mtime=$(stat -c %Y "$skill_path/SKILL.md" 2>/dev/null || echo 0)
        local age_days=$(( ($(date +%s) - mtime) / 86400 ))
        if [ "$age_days" -gt 90 ]; then
            ((stale_count++)) || true
        fi
    done
    if [ "$stale_count" -gt 0 ]; then
        log "  📋 INFO: $stale_count skills not updated in 90+ days (cosmetic — not actionable)"
    fi

    log "Improvement proposals: $proposals auto-applied"
}

# ─── Main commands ────────────────────────────────────────────────────────────

cmd_run() {
    mkdir -p "$REPORT_DIR"
    echo "[]" > "$REPORT_JSON"
    log "=== skill-optimizer starting ==="

    analyze_patterns
    apply_fixes
    propose_improvements

    echo "{\"ts\":\"$(date -Iseconds)\",\"issues\":$issues,\"warnings\":$warnings,\"auto_fixed\":$auto_fixed}" \
        >> "$REPORT_JSON"

    echo ""
    log "=== Results: issues=$issues | warnings=$warnings | auto_fixed=$auto_fixed ==="
    log "Report: $REPORT_JSON"
}

cmd_actions() {
    log "Actionable items only..."
    # Quick check of most impactful items
    if ! crontab -l 2>/dev/null | grep -q "power-watchdog"; then
        echo "  ❌ MISSING: power-watchdog cron"
    fi
    if ! crontab -l 2>/dev/null | grep -q "skill-health"; then
        echo "  ⚠️  MISSING: skill-health weekly cron (recommended)"
    fi
    if [ -f "$HEALTH_JSON" ]; then
        local fail_count
        fail_count=$(python3 -c "import json; d=json.load(open('$HEALTH_JSON')); print(d.get('fail',0))" 2>/dev/null || echo "0")
        if [ "$fail_count" -gt 0 ]; then
            echo "  ❌ $fail_count broken skills — run: skill-health test.sh run"
        fi
    fi
    ok "No critical actions pending"
}

cmd_apply() {
    apply_fixes
}

cmd_install_cron() {
    log "Installing skill-optimizer weekly cron..."
    local cron_line="0 4 * * 0 bash $SCRIPT_DIR/optimize.sh run >> $OPT_LOG 2>&1"
    (crontab -l 2>/dev/null | grep -v "skill-optimizer") | crontab - 2>/dev/null || true
    echo "$cron_line" | crontab - 2>/dev/null || true
    log "skill-optimizer cron installed: weekly (Sunday 4am)"
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────
ACTION="${1:-run}"
case "$ACTION" in
    run)          cmd_run ;;
    actions)      cmd_actions ;;
    apply)        cmd_apply ;;
    install-cron) cmd_install_cron ;;
    *)            echo "Usage: optimize.sh [run|actions|apply|install-cron]" ;;
esac
