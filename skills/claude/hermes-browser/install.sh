#!/bin/bash
# camoufox-install.sh — Auto-install / repair camoufox for Hermes Agent
# Run this after restore, update, or when camoufox is broken

set -e

HERMES_HOME_DIR="${HERMES_DIR:-$HOME/.hermes}"
CAMOFOX_DIR="$HERMES_HOME_DIR/hermes-agent/node_modules/@askjo/camofox-browser"
SKILL_DIR="$HOME/.hermes/skills/hermes-browser"
LOGFILE="$SKILL_DIR/install.log"
HEALTH_URL="${CAMOFOX_URL:-http://localhost:9377}/health"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log() { echo -e "[$(date '+%H:%M:%S')] $1" | tee -a "$LOGFILE"; }
log_ok() { log "${GREEN}✓${NC} $1"; }
log_warn() { log "${YELLOW}⚠${NC} $1"; }
log_fail() { log "${RED}✗${NC} $1"; }

step() { log "  → $1"; }

# ── Check if camoufox binary is present ──────────────────────────────────────
check_binary() {
    step "Checking camoufox binary..."
    local ver=$(npx camoufox-js version 2>&1 | grep "Camoufox:" | head -1)
    if [ -n "$ver" ]; then
        log_ok "$ver"
        return 0
    else
        log_warn "camoufox binary NOT found"
        return 1
    fi
}

# ── Install / repair camoufox binary ─────────────────────────────────────────
install_binary() {
    step "Installing camoufox binary..."
    log "  (this downloads ~300MB on first run)"
    if npx camoufox-js fetch 2>&1 | tee -a "$LOGFILE"; then
        log_ok "camoufox binary installed"
        return 0
    else
        log_fail "camoufox binary install failed"
        return 1
    fi
}

# ── Install npm deps if needed ────────────────────────────────────────────────
install_deps() {
    step "Checking npm dependencies..."
    if [ -d "$CAMOFOX_DIR/node_modules" ]; then
        log_ok "node_modules present"
        return 0
    fi
    step "Installing npm dependencies..."
    cd "$CAMOFOX_DIR"
    if npm install --silent 2>&1 | tee -a "$LOGFILE"; then
        log_ok "npm dependencies installed"
        return 0
    else
        log_fail "npm install failed"
        return 1
    fi
}

# ── Verify server.js exists ──────────────────────────────────────────────────
check_server() {
    step "Checking server.js..."
    if [ -f "$CAMOFOX_DIR/server.js" ]; then
        log_ok "server.js found"
        return 0
    else
        log_fail "server.js NOT found at $CAMOFOX_DIR/server.js"
        return 1
    fi
}

# ── Run full install ─────────────────────────────────────────────────────────
do_install() {
    log "=== camoufox auto-install ==="
    
    # Step 1: Verify server location
    check_server || exit 1
    
    # Step 2: Install deps if needed
    install_deps
    
    # Step 3: Install binary if needed
    if ! check_binary; then
        install_binary || exit 1
    fi
    
    log_ok "camoufox install complete"
}

# ── Verify install ───────────────────────────────────────────────────────────
verify() {
    log "=== Verifying camoufox install ==="
    local ok=0
    
    check_server || ok=1
    check_binary || ok=1
    
    step "Checking node_modules..."
    if [ -d "$CAMOFOX_DIR/node_modules" ]; then
        log_ok "node_modules present"
    else
        log_fail "node_modules missing"
        ok=1
    fi
    
    step "Checking skill files..."
    for f in src/session-manager.js src/browser-agent.js src/geo-ai.js src/human-behavior.js; do
        if [ -f "$SKILL_DIR/$f" ]; then
            log_ok "$f"
        else
            log_fail "$f missing"
            ok=1
        fi
    done
    
    if [ $ok -eq 0 ]; then
        log_ok "All checks passed"
    else
        log_fail "Some checks failed"
    fi
    return $ok
}

# ── Restore skill files from backup ─────────────────────────────────────────
restore_skill() {
    local backup_url="https://github.com/aatos-git-collab/agents-backup"
    local branch="stealth-browser-chro"
    local tmp="/tmp/stealth-browser-restore"
    
    step "Restoring skill from backup..."
    
    if [ ! -d "$tmp" ]; then
        log "  Cloning backup repo..."
        git clone --depth=1 -b "$branch" "$backup_url" "$tmp" 2>&1 | tail -3
    fi
    
    # Restore src files
    if [ -d "$tmp" ]; then
        cp -f "$tmp/session-manager.js" "$SKILL_DIR/src/" 2>/dev/null || true
        cp -f "$tmp/browser-agent.js" "$SKILL_DIR/src/" 2>/dev/null || true
        cp -f "$tmp/geo-ai.js" "$SKILL_DIR/src/" 2>/dev/null || true
        cp -f "$tmp/human-behavior.js" "$SKILL_DIR/src/" 2>/dev/null || true
        cp -f "$tmp/SKILL.md" "$SKILL_DIR/" 2>/dev/null || true
        cp -rf "$tmp/profiles/" "$SKILL_DIR/" 2>/dev/null || true
        log_ok "Skill files restored from backup"
    else
        log_warn "Could not clone backup repo"
    fi
}

case "${1:-install}" in
    install)
        do_install
        ;;
    verify)
        verify
        ;;
    restore)
        restore_skill
        ;;
    full)
        do_install
        verify
        ;;
    *)
        echo "Usage: $0 {install|verify|restore|full}"
        exit 1
        ;;
esac
