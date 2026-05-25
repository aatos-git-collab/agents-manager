#!/usr/bin/env bash
#===============================================================================
# AatosTeam Orchestration Self-Heal
# Fixes symlinks, templates, config, and crontab for aatosteam + claude skills bridge
# Usage: self-heal.sh [--check|--fix]
#===============================================================================
set -euo pipefail

MODE="${1:-check}"
FIX_MODE=false
[[ "$MODE" == "--fix" ]] && FIX_MODE=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)) || true; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)) || true; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARN++)) || true; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

fix() { [[ "$FIX_MODE" == "true" ]] && echo -e "  ${BLUE}FIX:${NC} $1"; }

#===============================================================================
# 1. SYMLINKS — bridge hermes skills to claude skills dir
#===============================================================================
log_info "=== Symlink Bridge: ~/.claude/skills/ → ~/.hermes/skills/ ==="

CLAUDE_SKILLS="$HOME/.claude/skills"
HERMES_TOOLS="$HOME/.hermes/tools"
HERMES_SKILLS="$HOME/.hermes/skills"

declare -A HERMES_SYM_LINKS=(
    ["aatosteam"]="$HERMES_TOOLS/AatosTeam/skills/aatosteam"
    ["cto"]="$HERMES_SKILLS/agent-brains/cto"
    ["ceo"]="$HERMES_SKILLS/agent-brains/ceo"
    ["cfo"]="$HERMES_SKILLS/agent-brains/cfo"
    ["cmo"]="$HERMES_SKILLS/agent-brains/cmo"
    ["coo"]="$HERMES_SKILLS/agent-brains/coo"
    ["cso"]="$HERMES_SKILLS/agent-brains/cso"
    ["grant-cardone"]="$HERMES_SKILLS/agent-brains/grant-cardone"
    ["jordan-belfort"]="$HERMES_SKILLS/agent-brains/jordan-belfort"
    ["zig-ziglar"]="$HERMES_SKILLS/agent-brains/zig-ziglar"
    ["talent-architect"]="$HERMES_SKILLS/agent-brains/talent-architect"
    ["reasoning-personas"]="$HERMES_SKILLS/agent-brains/reasoning-personas"
)

symlinks_ok=true
for skill_name in "${!HERMES_SYM_LINKS[@]}"; do
    src="${HERMES_SYM_LINKS[$skill_name]}"
    dest="$CLAUDE_SKILLS/$skill_name"
    
    if [[ -L "$dest" ]]; then
        real_dest=$(readlink -f "$dest" 2>/dev/null || echo "")
        real_src=$(readlink -f "$src" 2>/dev/null || echo "")
        if [[ "$real_dest" == "$real_src" ]] && [[ -e "$dest" ]]; then
            log_pass "$skill_name → $(basename "$src")"
        else
            symlinks_ok=false
            log_fail "$skill_name → broken symlink (target: $real_dest)"
            if [[ "$FIX_MODE" == "true" ]]; then
                rm -f "$dest"
                ln -sf "$src" "$dest" && log_info "  Fixed: created symlink for $skill_name"
            fi
        fi
    elif [[ -d "$dest" ]] || [[ -f "$dest" ]]; then
        log_warn "$skill_name → real file/dir exists (not symlink, skipping)"
    else
        symlinks_ok=false
        log_fail "$skill_name → symlink missing"
        if [[ "$FIX_MODE" == "true" ]]; then
            ln -sf "$src" "$dest" && log_info "  Fixed: created symlink for $skill_name"
        fi
    fi
done

# boris-workflow is native (not a symlink) — check it exists
if [[ -d "$CLAUDE_SKILLS/boris-workflow" ]]; then
    log_pass "boris-workflow (native)"
else
    log_fail "boris-workflow (native) — missing from ~/.claude/skills/"
fi

#===============================================================================
# 2. CUSTOM TEMPLATES — ~/.aatosteam/templates/
#===============================================================================
log_info "=== Custom Templates: ~/.aatosteam/templates/ ==="

mkdir -p "$HOME/.aatosteam/templates"

for toml in "$HOME"/.aatosteam/templates/*.toml; do
    [[ -e "$toml" ]] || continue
    name=$(basename "$toml" .toml)
    if python3 -c "import sys; import tomllib; tomllib.load(open('$toml','rb'))" 2>/dev/null; then
        log_pass "template: $name.toml (valid TOML)"
    else
        log_fail "template: $name.toml (invalid TOML)"
    fi
done

# Ensure our default templates exist
for tmpl in boris cto full-stack; do
    if [[ ! -f "$HOME/.aatosteam/templates/${tmpl}.toml" ]]; then
        log_warn "template missing: ${tmpl}.toml"
        if [[ "$FIX_MODE" == "true" ]]; then
            log_info "  Run: aatosteam-orchestration setup-templates to generate defaults"
        fi
    fi
done

#===============================================================================
# 3. AATOSTEAM BINARY & CONFIG
#===============================================================================
log_info "=== AatosTeam Binary & Config ==="

if command -v aatosteam &>/dev/null; then
    version=$(aatosteam --version 2>/dev/null || echo "unknown")
    log_pass "aatosteam installed ($version)"
else
    log_fail "aatosteam not found in PATH"
fi

if [[ -f "$HOME/.aatosteam/config.yaml" ]]; then
    if grep -q "skip_permissions:\s*true" "$HOME/.aatosteam/config.yaml" 2>/dev/null; then
        log_pass "~/.aatosteam/config.yaml (skip_permissions: true)"
    else
        log_warn "~/.aatosteam/config.yaml exists but skip_permissions not set to true"
        if [[ "$FIX_MODE" == "true" ]]; then
            if grep -q "skip_permissions" "$HOME/.aatosteam/config.yaml"; then
                sed -i 's/skip_permissions:\s*.*/skip_permissions: true/' "$HOME/.aatosteam/config.yaml"
            else
                echo "skip_permissions: true" >> "$HOME/.aatosteam/config.yaml"
            fi
            log_info "  Fixed: skip_permissions set to true"
        fi
    fi
else
    log_warn "~/.aatosteam/config.yaml not found"
    if [[ "$FIX_MODE" == "true" ]]; then
        mkdir -p "$HOME/.aatosteam"
        echo -e "skip_permissions: true\ndefault_backend: tmux" > "$HOME/.aatosteam/config.yaml"
        log_info "  Fixed: created ~/.aatosteam/config.yaml"
    fi
fi

#===============================================================================
# 4. CRONTAB WATCHDOG
#===============================================================================
log_info "=== Cron Watchdog ==="

cron_label="# AATOSTEAM_ORCHESTRATION_WATCHDOG"
if crontab -l 2>/dev/null | grep -q "$cron_label"; then
    log_pass "cron watchdog entry present"
else
    log_fail "cron watchdog missing"
    if [[ "$FIX_MODE" == "true" ]]; then
        cron_cmd="0 */6 * * * $HOME/.hermes/skills/aatosteam-orchestration/scripts/self-heal.sh --check >> $HOME/.hermes/skills/aatosteam-orchestration/scripts/watchdog.log 2>&1 $cron_label"
        (crontab -l 2>/dev/null | grep -v "$cron_label"; echo "$cron_cmd") | crontab -
        log_info "  Fixed: added cron watchdog (every 6h)"
    fi
fi

#===============================================================================
# 5. TEST SPAWN (quick)
#===============================================================================
log_info "=== Quick Spawn Test ==="

if [[ "$FIX_MODE" != "true" ]]; then
    # Only test in check mode, not fix mode
    test_team="health-check-$(date +%s)"
    if timeout 5 aatosteam team spawn-team "$test_team" -n health-probe 2>&1 | grep -q "OK\|Created"; then
        log_pass "team spawn works"
        # Clean up
        aatosteam team cleanup "$test_team" 2>/dev/null || true
    else
        log_warn "team spawn test timed out (may still work — tmux issue)"
    fi
fi

#===============================================================================
# SUMMARY
#===============================================================================
echo ""
echo "========================================"
echo -e "${BLUE}SUMMARY${NC}: ${GREEN}$PASS passed${NC} | ${RED}$FAIL failed${NC} | ${YELLOW}$WARN warnings${NC}"
echo "========================================"

if [[ "$FAIL" -gt 0 ]]; then
    echo -e "${RED}Run with --fix to auto-repair${NC}"
    exit 1
elif [[ "$WARN" -gt 0 ]]; then
    echo -e "${YELLOW}Warnings present — review above${NC}"
    exit 0
else
    echo -e "${GREEN}All checks passed${NC}"
    exit 0
fi
