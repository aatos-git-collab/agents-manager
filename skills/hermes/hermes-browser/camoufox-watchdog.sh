#!/bin/bash
# camoufox-watchdog.sh v8.0
# Version tracking + stealth verification + session health + auto-patch
# Runs: cron every 5min + on boot
# Exit: 0=clear, 1=patches-applied, 2=restarted, 3=failed

set +e  # Don't exit on errors — we handle them

CAMOUFOX_DIR="$HOME/.hermes/hermes-agent/node_modules/@askjo/camofox-browser"
SKILL_DIR="$HOME/.hermes/skills/hermes-browser"
SRC_DIR="$SKILL_DIR/src"
CAMOFOX_URL="${CAMOFOX_URL:-http://localhost:9377}"
LOGFILE="$SKILL_DIR/watchdog.log"
VERSION_FILE="$SKILL_DIR/.camoufox-version"
PATCH_LOG="$SKILL_DIR/.patch-log"
ALERT_FILE="$SKILL_DIR/.watchdog-alert"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()    { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOGFILE" 2>/dev/null; }
log_ok() { echo -e "[$(date '+%H:%M:%S')] ${GREEN}✓${NC} $*" | tee -a "$LOGFILE" 2>/dev/null; }
log_warn(){ echo -e "[$(date '+%H:%M:%S')] ${YELLOW}⚠${NC} $*" | tee -a "$LOGFILE" 2>/dev/null; }
log_fail(){ echo -e "[$(date '+%H:%M:%S')] ${RED}✗${NC} $*" | tee -a "$LOGFILE" 2>/dev/null; }
log_info(){ echo -e "[$(date '+%H:%M:%S')] ${BLUE}ℹ${NC} $*" | tee -a "$LOGFILE" 2>/dev/null; }

# ── Version ────────────────────────────────────────────────────────────────────
get_version() {
    python3 -c "import json; print(json.load(open('$CAMOUFOX_DIR/package.json')).get('version','unknown'))" 2>/dev/null || echo "unknown"
}

# ── Patch state ────────────────────────────────────────────────────────────────
get_patch_count() {
    python3 -c "
import re
c = open('$CAMOUFOX_DIR/server.js').read()
n = 0
if re.search(r'CAMOFOX_DEFAULT_OS|spoofOS', c): n += 1
if re.search(r'stealth-overrides|STEALTH_INIT_SCRIPT', c): n += 1
if re.search(r'addInitScript\(STEALTH_INIT_SCRIPT\)', c): n += 1
print(n)
" 2>/dev/null || echo "0"
}

# ── Health ─────────────────────────────────────────────────────────────────────
health_check() {
    local out=$(curl -sf "${CAMOFOX_URL}/health" 2>/dev/null)
    [ $? -eq 0 ] && echo "$out" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('ok') else 1)" 2>/dev/null
}

# ── Restart Camoufox via run.sh ─────────────────────────────────────────────────
restart_camoufox() {
    log_warn "Restarting camoufox..."
    if [ -x "$SKILL_DIR/run.sh" ]; then
        bash "$SKILL_DIR/run.sh" restart 2>/dev/null
    else
        # Fallback: kill and start
        pkill -f "node.*camofox.*server" 2>/dev/null
        sleep 2
        cd "$CAMOUFOX_DIR"
        CAMOFOX_DEFAULT_OS=windows CAMOFOX_PORT=9377 nohup node server.js >> "$SKILL_DIR/camofox.log" 2>&1 &
        echo $! > "$SKILL_DIR/.camofox.pid"
    fi
    sleep 5
    if health_check >/dev/null 2>&1; then
        log_ok "camoufox restarted successfully"
        return 0
    else
        log_fail "Restart failed"
        return 1
    fi
}

# ── Apply 3 stealth patches ────────────────────────────────────────────────────
apply_patches() {
    log_info "Applying stealth patches..."
    local patched=0

    # Patch 1: STEALTH_INIT_SCRIPT constant after "const { b } = require..."
    if ! grep -q "STEALTH_INIT_SCRIPT" "$CAMOUFOX_DIR/server.js" 2>/dev/null; then
        python3 -c "
import re
c = open('$CAMOUFOX_DIR/server.js').read()
patch = '''const fs = require('fs');
const STEALTH_INIT_SCRIPT = fs.existsSync('$SRC_DIR/stealth-overrides.js') ? fs.readFileSync('$SRC_DIR/stealth-overrides.js', 'utf8') : '';
'''
c = re.sub(r'(const \{ b \} = require\([\"\']playwright-core[\"\']\);)', patch + r'\1', c, count=1)
open('$CAMOUFOX_DIR/server.js', 'w').write(c)
" 2>/dev/null
        [ $? -eq 0 ] && log_ok "Patch 1: STEALTH_INIT_SCRIPT" && ((patched++)) || log_fail "Patch 1 failed"
    else
        log_info "Patch 1: already applied"
    fi

    # Patch 2: os: spoofOS (instead of os: hostOS) in getHostOS context
    if grep -q "os: hostOS" "$CAMOUFOX_DIR/server.js" 2>/dev/null; then
        python3 -c "
import re
c = open('$CAMOUFOX_DIR/server.js').read()
# Add spoofOS definition near getHostOS if not present
if 'const spoofOS = process.env.CAMOFOX_DEFAULT_OS' not in c:
    c = re.sub(
        r'(function getHostOS\(\) \{)',
        r'\1\n  const spoofOS = process.env.CAMOFOX_DEFAULT_OS || hostOS;',
        c, count=1
    )
# Replace os: hostOS with os: spoofOS
c = re.sub(r'os: hostOS(,\n)', r'os: spoofOS\1', c)
open('$CAMOUFOX_DIR/server.js', 'w').write(c)
" 2>/dev/null
        [ $? -eq 0 ] && log_ok "Patch 2: os: spoofOS" && ((patched++)) || log_fail "Patch 2 failed"
    else
        log_info "Patch 2: already applied or restructured"
    fi

    # Patch 3: context.addInitScript(STEALTH_INIT_SCRIPT) after newContext
    if ! grep -q "addInitScript(STEALTH_INIT_SCRIPT)" "$CAMOUFOX_DIR/server.js" 2>/dev/null; then
        python3 -c "
import re
c = open('$CAMOUFOX_DIR/server.js').read()
c = re.sub(
    r'(const context = await b\.newContext\(contextOptions\);)',
    r'\1\n  if (STEALTH_INIT_SCRIPT) await context.addInitScript(STEALTH_INIT_SCRIPT);',
    c
)
open('$CAMOUFOX_DIR/server.js', 'w').write(c)
" 2>/dev/null
        [ $? -eq 0 ] && log_ok "Patch 3: addInitScript" && ((patched++)) || log_fail "Patch 3 failed"
    else
        log_info "Patch 3: already applied"
    fi

    # Log
    echo "$current_ver" > "$VERSION_FILE"
    echo "$current_patches" > "$VERSION_FILE.patches"
    echo "$(date '+%Y-%m-%d %H:%M:%S') v$(get_version) patches=$current_patches" >> "$PATCH_LOG" 2>/dev/null
    log_info "Patches applied: $current_patches/3"
    return 0
}

# ── Verify stealth via live browser tab ────────────────────────────────────────
verify_stealth() {
    log_info "Verifying stealth fingerprints..."
    local tab_id=""
    local all_ok=true

    # Create test tab
    tab_id=$(curl -sf -X POST "$CAMOFOX_URL/tabs" \
        -H "Content-Type: application/json" \
        -d '{"userId":"hermes","sessionKey":"watchdog-test"}' 2>/dev/null | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('tabId',''))" 2>/dev/null) || true

    if [ -z "$tab_id" ]; then
        log_fail "verify: could not create test tab"
        return 1
    fi
    log_info "Test tab: $tab_id"

    # Navigate to browserleaks
    curl -sf -X POST "$CAMOFOX_URL/tabs/$tab_id/navigate" \
        -H "Content-Type: application/json" \
        -d '{"userId":"hermes","url":"https://browserleaks.com/canvas"}' >/dev/null 2>&1 || true
    sleep 4

    # Evaluate fingerprint vectors
    local raw=$(curl -sf -X POST "$CAMOFOX_URL/tabs/$tab_id/evaluate" \
        -H "Content-Type: application/json" \
        -d '{"userId":"hermes","expression":"JSON.stringify({platform:navigator.platform,oscpu:navigator.oscpu||'"'"'unset'"'"',hardwareConcurrency:navigator.hardwareConcurrency,deviceMemory:navigator.deviceMemory||'"'"'unset'"'"',vendor:navigator.vendor||'"'"'unset'"'"',buildID:navigator.buildID||'"'"'unset'"'"',webgl:(function(){var c=document.createElement('"'"'canvas'"'"');var gl=c.getContext('"'"'webgl'"'"')||c.getContext('"'"'experimental-webgl'"'"');if(!gl)return'"'"'none'"'"';var e=gl.getExtension('"'"'WEBGL_debug_renderer_info'"'"');if(!e)return'"'"'no-debug-info'"'"';return gl.getParameter(e.UNMASKED_RENDERER_WEBGL);})()})"}' 2>/dev/null) || "null"

    # Close tab
    curl -sf -X DELETE "$CAMOFOX_URL/tabs/$tab_id" \
        -H "Content-Type: application/json" \
        -d '{"userId":"hermes"}' >/dev/null 2>&1 || true

    # Parse result.value (JSON string from JSON.stringify)
    local inner=$(echo "$raw" | python3 -c "
import sys,json
d=json.loads(sys.stdin.read())
r=d.get('result',{})
v=r.get('value',r) if isinstance(r,dict) else r
print(v if isinstance(v,str) else 'null')
" 2>/dev/null) || "null"

    local platform=$(echo "$inner" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('platform',''))" 2>/dev/null)
    local oscpu=$(echo "$inner" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('oscpu',''))" 2>/dev/null)
    local hc=$(echo "$inner" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('hardwareConcurrency',''))" 2>/dev/null)
    local dm=$(echo "$inner" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('deviceMemory',''))" 2>/dev/null)
    local webgl=$(echo "$inner" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('webgl',''))" 2>/dev/null)

    # Check platform
    if [ "$platform" = "Win32" ]; then
        log_ok "platform=$platform"
    else
        log_fail "platform=$platform (expected Win32)"
        all_ok=false
    fi

    # Check oscpu
    if [ "$oscpu" = "Windows NT 10.0" ] || [ "$oscpu" = "unset" ]; then
        log_ok "oscpu=$oscpu"
    else
        log_warn "oscpu=$oscpu (expected Windows NT 10.0)"
    fi

    # Check hardwareConcurrency
    if [ "$hc" = "8" ] || [ "$hc" = "4" ]; then
        log_ok "hardwareConcurrency=$hc"
    else
        log_fail "hardwareConcurrency=$hc (expected 8 or 4)"
        all_ok=false
    fi

    # Check deviceMemory
    if [ "$dm" = "8" ] || [ "$dm" = "unset" ]; then
        log_ok "deviceMemory=$dm"
    else
        log_warn "deviceMemory=$dm (expected 8)"
    fi

    # Check WebGL renderer
    if echo "$webgl" | grep -qi "intel\|nvidia\|amd\|angle"; then
        log_ok "webgl=$webgl"
    else
        log_warn "webgl=$webgl"
    fi

    $all_ok && return 0 || return 1
}

# ── Session health — verify API endpoints work ─────────────────────────────────
verify_session_api() {
    log_info "Verifying session API..."
    local ok=true

    # Test: create tab
    local tab=$(curl -sf -X POST "$CAMOFOX_URL/tabs" \
        -H "Content-Type: application/json" \
        -d '{"userId":"hermes","sessionKey":"watchdog-api-test"}' 2>/dev/null) || ""
    local tab_id=$(echo "$tab" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tabId',''))" 2>/dev/null)

    if [ -n "$tab_id" ]; then
        log_ok "POST /tabs → tab $tab_id"

        # Test navigate
        local nav=$(curl -sf -X POST "$CAMOFOX_URL/tabs/$tab_id/navigate" \
            -H "Content-Type: application/json" \
            -d '{"userId":"hermes","url":"https://example.com"}' 2>/dev/null)
        if echo "$nav" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('ok') else 1)" 2>/dev/null; then
            log_ok "POST /tabs/:id/navigate → ok"
        else
            log_warn "POST /tabs/:id/navigate → may have failed"
        fi

        # Test evaluate
        local ev=$(curl -sf -X POST "$CAMOFOX_URL/tabs/$tab_id/evaluate" \
            -H "Content-Type: application/json" \
            -d '{"userId":"hermes","expression":"document.title"}' 2>/dev/null)
        if echo "$ev" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('ok') else 1)" 2>/dev/null; then
            log_ok "POST /tabs/:id/evaluate → ok"
        else
            log_warn "POST /tabs/:id/evaluate → may have failed"
        fi

        # Test close tab
        curl -sf -X DELETE "$CAMOFOX_URL/tabs/$tab_id" \
            -H "Content-Type: application/json" \
            -d '{"userId":"hermes"}' >/dev/null 2>&1
        log_info "Tab $tab_id closed"
    else
        log_fail "POST /tabs → no tabId returned"
        ok=false
    fi

    # Test: close session
    local del=$(curl -sf -X DELETE "$CAMOFOX_URL/sessions/hermes" \
        -H "Content-Type: application/json" \
        -d '{"userId":"hermes"}' 2>/dev/null)
    if echo "$del" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('ok') else 1)" 2>/dev/null; then
        log_ok "DELETE /sessions/hermes → ok"
    else
        log_warn "DELETE /sessions/hermes → response unexpected"
    fi

    $ok && return 0 || return 1
}

# ── Full watchdog cycle ────────────────────────────────────────────────────────
run_watchdog() {
    log_info "=== camoufox watchdog v8.0 ==="
    local current_ver=$(get_version)
    local prev_ver=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    local prev_patches=$(cat "$VERSION_FILE.patches" 2>/dev/null || echo "0")
    local current_patches=$(get_patch_count)

    log_info "Version: $current_ver (recorded: $prev_ver)"
    log_info "Patch count: $current_patches/3 (recorded: $prev_patches/3)"

    local exit_code=0

    # ── 1. Health check ────────────────────────────────────────────────────────
    if ! health_check >/dev/null 2>&1; then
        log_warn "camoufox is DOWN, restarting..."
        restart_camoufox
        [ $? -ne 0 ] && { log_fail "Restart failed"; return 3; }
        exit_code=2
    fi

    # ── 2. Version change → repatch + restart ──────────────────────────────────
    if [ "$current_ver" != "$prev_ver" ] && [ "$current_ver" != "unknown" ]; then
        log_warn "Version changed: $prev_ver → $current_ver"
        echo "$current_ver" > "$VERSION_FILE"
        apply_patches
        restart_camoufox
        [ $? -eq 0 ] && exit_code=2
    fi

    # ── 3. Patch drift → repatch ───────────────────────────────────────────────
    if [ "$current_patches" != "$prev_patches" ] || [ "$current_patches" -lt 3 ]; then
        log_warn "Patch drift detected ($current_patches/3), reapplying..."
        apply_patches
        [ $? -eq 0 ] && exit_code=1
    fi

    # ── 4. Record first-run version ───────────────────────────────────────────
    if [ "$prev_ver" = "unknown" ] || [ ! -f "$VERSION_FILE" ]; then
        log_info "First run — recording version"
        echo "$current_ver" > "$VERSION_FILE"
        echo "$(get_patch_count)" > "$VERSION_FILE.patches"
    fi

    # ── 5. Stealth verification ────────────────────────────────────────────────
    if health_check >/dev/null 2>&1; then
        if ! verify_stealth; then
            log_warn "Stealth failed — repatching + restarting..."
            apply_patches
            restart_camoufox
            sleep 5
            if ! verify_stealth; then
                log_fail "Stealth still failing after repatch"
                echo "stealth-fail $(date)" >> "$ALERT_FILE" 2>/dev/null
                return 3
            fi
            exit_code=2
        fi
    fi

    # ── 6. Session API health ──────────────────────────────────────────────────
    if health_check >/dev/null 2>&1; then
        if ! verify_session_api; then
            log_warn "Session API degraded"
        fi
    fi

    # ── Summary ───────────────────────────────────────────────────────────────
    case $exit_code in
        0) log_ok "Watchdog complete — all clear" ;;
        1) log_ok "Watchdog complete — patches applied" ;;
        2) log_ok "Watchdog complete — restarted" ;;
    esac

    return $exit_code
}

# ── Report ─────────────────────────────────────────────────────────────────────
report() {
    local ver=$(get_version)
    local prev=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
    local patches=$(get_patch_count)
    local health=$(health_check >/dev/null 2>&1 && echo "UP" || echo "DOWN")
    echo ""
    echo "=== camoufox watchdog report ==="
    echo "  Health:         $health"
    echo "  Version:        $ver"
    echo "  Recorded ver:   $prev"
    echo "  Patch marks:    $patches/3"
    echo "  All patched:    $([ "$patches" -eq 3 ] && echo YES || echo NO — needs $((3-patches)) more)"
    echo "  Version match:  $([ "$ver" = "$prev" ] && echo YES || echo CHANGED)"
    echo "  Cron installed: $(crontab -l 2>/dev/null | grep -c "camoufox-watchdog" || true)"
    echo "  Alert lines:    $(cat "$ALERT_FILE" 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
    echo "=============================="
}

# ── Auto-install cron ──────────────────────────────────────────────────────────
install_cron() {
    local existing=$(crontab -l 2>/dev/null | grep -c "camoufox-watchdog" || echo 0)
    if [ "$existing" -eq 0 ]; then
        (crontab -l 2>/dev/null; echo "*/5 * * * * bash $SKILL_DIR/camoufox-watchdog.sh run >> $SKILL_DIR/watchdog.log 2>&1") | crontab -
        log_ok "Cron job installed (every 5 min)"
    else
        log_info "Cron job already installed"
    fi
}

# ── Touch session (keep-alive) ──────────────────────────────────────────────────
touch_session() {
    # Re-touch a named session to prevent 10-min expiry
    local name="${1:-}"
    [ -z "$name" ] && return
    node "$SKILL_DIR/src/session-manager.js" restore "$name" >/dev/null 2>&1 || true
}

# ── Main dispatch ──────────────────────────────────────────────────────────────
case "${1:-run}" in
    run)
        run_watchdog
        ;;
    verify)
        health_check >/dev/null 2>&1 && verify_stealth && verify_session_api
        ;;
    report)
        report
        ;;
    patches)
        apply_patches
        ;;
    install-cron)
        install_cron
        ;;
    touch)
        touch_session "${2:-}"
        ;;
    *)
        echo "Usage: $0 {run|report|verify|patches|install-cron}"
        echo ""
        echo "  run         — full watchdog cycle (default)"
        echo "  verify      — stealth + API checks only"
        echo "  report      — human-readable status"
        echo "  patches     — apply patches only"
        echo "  install-cron — install/update cron job"
        echo "  touch <name> — keep session alive"
        ;;
esac
