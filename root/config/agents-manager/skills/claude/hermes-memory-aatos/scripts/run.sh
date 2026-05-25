#!/bin/bash
# run.sh — Hermes Memory System lifecycle: install/start/status/heal/verify
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
MEMORY_GRAPHIFY="$HOME/.hermes/memory/graphify"
MEMORY_HONCHO="$HOME/.hermes/memory/honcho"
MEMORY_DAILY="$HOME/.hermes/memory/daily"
MEMORY_WEEKLY="$HOME/.hermes/memory/weekly"
VENV="$HOME/.hermes/hermes-agent/venv"
GRAPHIFY_REPO="/root/graphify"
BACKUP_GIT="memory-backup"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log() { echo -e "${BLUE}[memory]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC}  $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*" >&2; }

# ─── Subcommands ────────────────────────────────────────────────────────────

cmd_install() {
    log "Installing Hermes Memory System..."
    
    # 1. Create memory dirs
    for dir in "$MEMORY_GRAPHIFY" "$MEMORY_HONCHO" "$MEMORY_DAILY" "$MEMORY_WEEKLY"; do
        mkdir -p "$dir"
        ok "Created $dir"
    done

    # 2. Graphify — install if not present
    if [ ! -d "$GRAPHIFY_REPO" ]; then
        log "Cloning graphify..."
        git clone https://github.com/someone/graphify.git "$GRAPHIFY_REPO" 2>/dev/null || \
        warn "Graphify clone failed — checking if already in PATH"
    fi
    
    if command -v graphify &>/dev/null; then
        ok "Graphify CLI available"
    elif [ -d "$GRAPHIFY_REPO" ]; then
        log "Installing graphify from $GRAPHIFY_REPO..."
        cd "$GRAPHIFY_REPO" && pip install -e . -q 2>/dev/null || \
        "$VENV/bin/pip" install -e . -q 2>/dev/null || \
        warn "Graphify pip install failed — try manual install"
        ok "Graphify installed from repo"
    else
        warn "Graphify not found — install manually: uv pip install graphify"
    fi

    # 3. honcho_ai — install if not present
    if "$VENV/bin/python3" -c "import honcho_ai" 2>/dev/null; then
        ok "honcho_ai installed"
    else
        log "Installing honcho_ai..."
        "$VENV/bin/pip" install honcho-ai -q 2>/dev/null || \
        warn "honcho_ai install failed — try: uv pip install honcho-ai"
    fi

    # 4. Hermes plugin
    if [ -d "$HOME/.hermes/hermes-agent/plugins/memory/honcho" ]; then
        ok "Honcho Hermes plugin present"
    else
        warn "Honcho Hermes plugin not found at plugins/memory/honcho"
    fi

    # 5. Daily memory dirs
    mkdir -p "$MEMORY_DAILY" "$MEMORY_WEEKLY"
    ok "Daily memory dirs ready"

    ok "Install complete. Run 'hermes honcho setup' to configure Honcho API key."
}

cmd_start() {
    log "Starting Hermes Memory System..."
    
    # Verify critical dirs
    mkdir -p "$MEMORY_GRAPHIFY" "$MEMORY_HONCHO" "$MEMORY_DAILY" "$MEMORY_WEEKLY"
    
    # Check graphify
    if command -v graphify &>/dev/null || [ -f "$GRAPHIFY_REPO/graphify" ]; then
        ok "Graphify ready"
    else
        warn "Graphify not in PATH"
    fi

    # Check honcho
    if "$VENV/bin/python3" -c "import honcho_ai" 2>/dev/null; then
        ok "honcho_ai ready"
    else
        warn "honcho_ai not installed"
    fi

    # Apply config (nudge intervals, honcho provider)
    log "Applying memory config..."
    if grep -q "memory.provider" "$HOME/.hermes/config.yaml" 2>/dev/null; then
        if grep -q "provider: honcho" "$HOME/.hermes/config.yaml"; then
            ok "Honcho memory provider configured"
        else
            sed -i 's/provider:.*/provider: honcho/' "$HOME/.hermes/config.yaml" 2>/dev/null || true
        fi
    fi

    # Apply hook configs if not present
    if [ ! -d "$HOME/.hermes/hooks/session-memory-guardian" ]; then
        log "Installing session-memory-guardian hook..."
        mkdir -p "$HOME/.hermes/hooks/session-memory-guardian"
        cat > "$HOME/.hermes/hooks/session-memory-guardian/HOOK.yaml" << 'EOF'
name: session-memory-guardian
version: "1.0"
description: "Writes daily + weekly memory digests on session:end"
trigger:
  event: session:end
EOF
        cat > "$HOME/.hermes/hooks/session-memory-guardian/handler.py" << 'HANDLER'
#!/usr/bin/env python3
"""Writes daily + weekly memory digests on session:end."""
import sys, os, json, pathlib, datetime

MEMORY_DIR = pathlib.Path.home() / ".hermes" / "memory"
DAILY = MEMORY_DIR / "daily"
WEEKLY = MEMORY_DIR / "weekly"
DRAFT = MEMORY_DIR / "session-draft.json"

def main():
    DAILY.mkdir(parents=True, exist_ok=True)
    WEEKLY.mkdir(parents=True, exist_ok=True)
    
    today = datetime.date.today()
    day_file = DAILY / f"{today.isoformat()}.md"
    iso_week = today.isocalendar()[1]
    week_file = WEEKLY / f"{today.year}-W{iso_week:02d}.md"
    
    # Load session draft
    draft = {}
    if DRAFT.exists():
        try:
            draft = json.loads(DRAFT.read_text())
        except: pass
    
    # Write daily
    content = f"# {today.isoformat()}\n\n"
    if draft.get("summary"):
        content += f"## Summary\n{draft['summary']}\n\n"
    if draft.get("learnings"):
        content += f"## Learnings\n"
        for l in draft["learnings"]:
            content += f"- {l}\n"
        content += "\n"
    if draft.get("decisions"):
        content += f"## Decisions\n"
        for d in draft["decisions"]:
            content += f"- {d}\n"
    
    day_file.write_text(content)
    print(f"Daily memory written: {day_file}", file=sys.stderr)
    
    # Write weekly
    week_entries = list(DAILY.glob(f"{today.year}-W{iso_week:02d}*.md")) or [day_file]
    week_content = f"# {today.year}-W{iso_week:02d} (Week {iso_week})\n\n"
    for f in sorted(week_entries):
        week_content += f.read_text() + "\n---\n\n"
    week_file.write_text(week_content)
    print(f"Weekly memory written: {week_file}", file=sys.stderr)

if __name__ == "__main__":
    main()
HANDLER
        chmod +x "$HOME/.hermes/hooks/session-memory-guardian/handler.py"
        ok "session-memory-guardian hook installed"
    fi

    if [ ! -d "$HOME/.hermes/hooks/auto-new-trigger" ]; then
        log "Installing auto-new-trigger hook..."
        mkdir -p "$HOME/.hermes/hooks/auto-new-trigger"
        cat > "$HOME/.hermes/hooks/auto-new-trigger/HOOK.yaml" << 'EOF'
name: auto-new-trigger
version: "1.0"
description: "Auto-triggers /new when context ratio hits threshold"
trigger:
  event: pre_llm_call
EOF
        cat > "$HOME/.hermes/hooks/auto-new-trigger/handler.py" << 'HANDLER'
#!/usr/bin/env python3
"""Auto-trigger /new at 78% context ratio."""
import sys, json, os

THRESHOLD = 0.78
TRIGGER = "/new"

def main():
    raw = os.environ.get("HERMES_CONTEXT_RATIO", "")
    if not raw:
        ratio = 0.0
    else:
        try:
            ratio = float(raw)
        except:
            ratio = 0.0
    
    if ratio >= THRESHOLD:
        result = {
            "context": TRIGGER,
            "reason": f"context_ratio={ratio:.2f}>={THRESHOLD}"
        }
        print(json.dumps(result), file=sys.stdout)
        sys.exit(0)
    sys.exit(1)

if __name__ == "__main__":
    main()
HANDLER
        chmod +x "$HOME/.hermes/hooks/auto-new-trigger/handler.py"
        ok "auto-new-trigger hook installed"
    fi
    
    ok "Hermes Memory System started"
}

cmd_status() {
    log "Memory System Status"
    echo ""
    
    # Graphify CLI
    echo -n "  Graphify CLI: "
    if command -v graphify &>/dev/null; then
        ok "available"
    elif [ -d "$GRAPHIFY_REPO" ]; then
        echo -e "${YELLOW}repo present${NC} ($GRAPHIFY_REPO)"
    else
        fail "not found"
    fi
    
    # Graphify memory dir
    echo -n "  Graphify memory: "
    if [ -d "$MEMORY_GRAPHIFY" ] && [ "$(ls -A $MEMORY_GRAPHIFY 2>/dev/null)" ]; then
        count=$(find "$MEMORY_GRAPHIFY" -type f 2>/dev/null | wc -l)
        ok "$count files"
    else
        warn "not initialized yet (run: graphify update <path>)"
    fi
    
    # Honcho SDK (installed as 'honcho' package, honcho_ai is dist-info name)
    echo -n "  Honcho SDK: "
    if "$VENV/bin/python3" -c "import honcho; c=hasattr(honcho,'Honcho') or hasattr(honcho,'client')" 2>/dev/null; then
        ver=$("$VENV/bin/python3" -c "import honcho; print(getattr(honcho,'__version__','unknown'))" 2>/dev/null)
        ok "v$ver"
    elif [ -d "$VENV/lib/python3.11/site-packages/honcho_ai-2.1.1.dist-info" ]; then
        ok "v2.1.1 (via honcho module)"
    else
        fail "not installed"
    fi
    
    # Honcho plugin
    echo -n "  Honcho plugin: "
    if [ -d "$HOME/.hermes/hermes-agent/plugins/memory/honcho" ]; then
        ok "present"
    else
        fail "not found"
    fi
    
    # Daily + weekly memory dirs (graphify + honcho already checked above)
    for dir in "$MEMORY_DAILY" "$MEMORY_WEEKLY"; do
        echo -n "  $(basename $dir): "
        if [ -d "$dir" ]; then
            count=$(find "$dir" -type f 2>/dev/null | wc -l)
            ok "$count files"
        else
            mkdir -p "$dir"
            warn "created missing dir"
        fi
    done
    
    # Daily memory
    echo -n "  Today's memory: "
    today_file="$MEMORY_DAILY/$(date +%Y-%m-%d).md"
    if [ -f "$today_file" ]; then
        lines=$(wc -l < "$today_file")
        ok "$lines lines"
    else
        warn "not written yet today"
    fi
    
    # Hooks
    echo -n "  Hooks: "
    hooks_installed=0
    for hook in session-memory-guardian auto-new-trigger; do
        [ -d "$HOME/.hermes/hooks/$hook" ] && ((hooks_installed++)) || true
    done
    if [ "$hooks_installed" -eq 2 ]; then
        ok "2/2 installed"
    else
        warn "$hooks_installed/2 installed"
    fi
    
    # Watchdog cron
    echo -n "  Watchdog cron: "
    if crontab -l 2>/dev/null | grep -q "hermes-memory-watchdog"; then
        ok "active"
    else
        warn "not scheduled"
    fi
    
    # Honcho config
    echo -n "  Honcho API: "
    if grep -q "HONCHO_API_KEY" "$HOME/.hermes/.env" 2>/dev/null; then
        ok "configured"
    else
        warn "not configured (run: hermes honcho setup)"
    fi
}

cmd_heal() {
    log "Self-healing Hermes Memory System..."
    cmd_install
    cmd_start
    cmd_status
}

cmd_verify() {
    log "Verifying Hermes Memory System..."
    errors=0
    
    # Graphify
    if ! command -v graphify &>/dev/null && [ ! -d "$GRAPHIFY_REPO" ]; then
        fail "Graphify not found"
        ((errors++))
    else
        ok "Graphify"
    fi
    
    # honcho_ai
    if ! "$VENV/bin/python3" -c "import honcho_ai" 2>/dev/null; then
        fail "honcho_ai not installed"
        ((errors++))
    else
        ok "honcho_ai"
    fi
    
    # Memory dirs
    for dir in "$MEMORY_GRAPHIFY" "$MEMORY_DAILY"; do
        if [ ! -d "$dir" ]; then
            fail "$dir missing"
            ((errors++))
        else
            ok "$dir"
        fi
    done
    
    # Hooks
    for hook in session-memory-guardian auto-new-trigger; do
        if [ ! -d "$HOME/.hermes/hooks/$hook" ]; then
            fail "hook $hook missing"
            ((errors++))
        else
            ok "hook $hook"
        fi
    done
    
    if [ "$errors" -eq 0 ]; then
        ok "All checks passed"
        return 0
    else
        fail "$errors check(s) failed — run 'bash run.sh heal'"
        return 1
    fi
}

# ─── Dispatch ──────────────────────────────────────────────────────────────
case "${1:-status}" in
    install)  cmd_install ;;
    start)    cmd_start ;;
    status)   cmd_status ;;
    heal)     cmd_heal ;;
    verify)   cmd_verify ;;
    *)        echo "Usage: $0 {install|start|status|heal|verify}" ;;
esac
