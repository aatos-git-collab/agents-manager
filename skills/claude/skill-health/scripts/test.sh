#!/bin/bash
# skill-health — Automated test suite for all Hermes skills
# Usage: test.sh [run|quick|broken|install-cron]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$HOME/.hermes/skills"
REPORT_DIR="$HOME/.hermes/memory"
TODAY=$(date +%Y-%m-%d)
REPORT_JSON="$REPORT_DIR/skill-health-$TODAY.json"
HEALTH_LOG="$REPORT_DIR/skill-health.log"
SKILL_SYNC="$HOME/.hermes/skills/skill-sync/scripts/sync.sh"
WATCHDOG="$HOME/.hermes/skills/power-watchdog/scripts/watch.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[skill-health]${NC} $*"; }
ok()  { echo -e "  ${GREEN}✅${NC}  $*"; }
fail(){ echo -e "  ${RED}❌${NC}  $*"; ((fail_count++)) || true; }
warn(){ echo -e "  ${YELLOW}⚠️${NC}  $*"; ((warn_count++)) || true; }
info(){ echo -e "  ${BLUE}ℹ️${NC}  $*"; }

fail_count=0; warn_count=0; pass_count=0; skip_count=0

# ─── Individual skill test ────────────────────────────────────────────────────
test_skill() {
    local skill_path="$1"
    local skill_name
    skill_name="$(basename "$skill_path")"
    local skill_file="$skill_path/SKILL.md"
    local result="pass"

    # 1. SKILL.md exists
    if [ ! -f "$skill_file" ]; then
        fail "$skill_name: missing SKILL.md"
        echo "{\"skill\":\"$skill_name\",\"status\":\"fail\",\"reason\":\"missing SKILL.md\"}" >> "$REPORT_JSON"
        return 1
    fi

    # 2. YAML frontmatter valid (has --- at start and end)
    if ! head -1 "$skill_file" | grep -q "^---"; then
        warn "$skill_name: no YAML frontmatter"
        result="warn"
    fi

    # 3. name: field present
    if ! grep -q "^name:" "$skill_file"; then
        fail "$skill_name: missing 'name:' in frontmatter"
        result="fail"
    fi

    # 4. description: not empty
    local desc_line
    desc_line=$(grep "^description:" "$skill_file" 2>/dev/null || echo "")
    if [ -z "$desc_line" ]; then
        warn "$skill_name: missing or empty 'description:'"
        result="warn"
    fi

    # 5. Scripts executable (if scripts/ dir exists)
    if [ -d "$skill_path/scripts" ]; then
        for script in "$skill_path"/scripts/*.sh; do
            [ -f "$script" ] || continue
            if [ ! -x "$script" ]; then
                chmod +x "$script"
                info "$skill_name: made $(basename "$script") executable"
            fi
        done
    fi

    # 6. Required skill structure sections
    local has_usage=false
    if grep -q "^## Quick Commands\|^## Usage\|^## Commands" "$skill_file" 2>/dev/null; then
        has_usage=true
    fi
    if ! $has_usage; then
        warn "$skill_name: missing Quick Commands/Usage section"
        result="warn"
    fi

    # ─── Final result (no double-counting — helpers called above per issue) ───
    if [ "$result" = "pass" ]; then
        ok "$skill_name"
        ((pass_count++)) || true
    else
        # result is already set; helpers already counted — just record to JSON
        # no additional warn()/fail() call here
        true
    fi

    echo "{\"skill\":\"$skill_name\",\"status\":\"$result\"}" >> "$REPORT_JSON"
}

# ─── Main test run ────────────────────────────────────────────────────────────
cmd_run() {
    log "Running skill health check (recursive)..."
    mkdir -p "$REPORT_DIR"
    echo "[]" > "$REPORT_JSON"  # Reset
    echo "" > "$HEALTH_LOG"

    local total=0
    # Recursively find ALL SKILL.md — top-level + nested inside category dirs
    # Use temp file instead of subshell to preserve counter updates in parent shell
    local tmp_out
    tmp_out=$(mktemp)
    while IFS= read -r skill_file; do
        skill_path="$(dirname "$skill_file")"
        ((total++)) || true
        test_skill "$skill_path" > "$tmp_out" 2>&1
        cat "$tmp_out" | tee -a "$HEALTH_LOG"
    done < <(find "$SKILL_DIR" -name "SKILL.md" -not -path "*/node_modules/*" 2>/dev/null | sort)
    rm -f "$tmp_out"

    echo ""
    log "=== Results: tested $total | ✅ pass $pass_count | ❌ fail $fail_count | ⚠️ warn $warn_count ==="

    # Write summary to daily memory
    local day_file="$REPORT_DIR/daily/$TODAY.md"
    mkdir -p "$(dirname "$day_file")"
    local summary="\n## skill-health $(date +%H:%M)\n- Tested: $total | ✅ $pass_count | ❌ $fail_count | ⚠️ $warn_count\n"
    if [ "$fail_count" -gt 0 ]; then
        summary+="- ❌ BROKEN: see $REPORT_JSON\n"
    fi
    echo -e "$summary" >> "$day_file"

    # Write JSON summary
    echo "{\"ts\":\"$(date -Iseconds)\",\"total\":$total,\"pass\":$pass_count,\"fail\":$fail_count,\"warn\":$warn_count}" \
        > "$REPORT_DIR/skill-health-latest.json"

    return 0
}

cmd_quick() {
    log "Quick status check (recursive)..."
    local total=0 pass=0 fail=0
    while IFS= read -r skill_file; do
        skill_path="$(dirname "$skill_file")"
        ((total++)) || true
        if grep -q "^name:" "$skill_file" 2>/dev/null; then
            ((pass++)) || true
        else
            ((fail++)) || true
            fail "$(basename "$skill_path"): missing 'name:' field"
        fi
    done < <(find "$SKILL_DIR" -name "SKILL.md" -not -path "*/node_modules/*" 2>/dev/null | sort)
    echo ""
    log "Quick: $pass/$total skills valid"
}

cmd_broken() {
    log "Checking for broken skills from last run..."
    local latest="$REPORT_DIR/skill-health-latest.json"
    if [ ! -f "$latest" ]; then
        log "No previous run found — run 'test.sh run' first"
        cmd_quick
        return
    fi
    local fail_count
    fail_count=$(python3 -c "import json; d=json.load(open('$latest')); print(d.get('fail',0))" 2>/dev/null || echo "0")
    log "Last run: $fail_count broken skills"
    log "Re-testing all skills..."
    cmd_run
}

cmd_install_cron() {
    log "Installing skill-health weekly cron..."
    local cron_line="0 3 * * 0 bash $SCRIPT_DIR/test.sh run >> $REPORT_DIR/skill-health.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "skill-health") | crontab - 2>/dev/null || true
    echo "$cron_line" | crontab - 2>/dev/null || {
        warn "Could not install cron"
    }
    log "skill-health cron installed: weekly (Sunday 3am)"
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────
ACTION="${1:-run}"
case "$ACTION" in
    run)          cmd_run ;;
    quick)        cmd_quick ;;
    broken)       cmd_broken ;;
    install-cron) cmd_install_cron ;;
    *)            echo "Usage: test.sh [run|quick|broken|install-cron]" ;;
esac
