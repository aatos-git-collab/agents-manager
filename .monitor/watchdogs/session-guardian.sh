#!/bin/bash
# session-guardian.sh — monitors active sessions and triggers /new at 80% context
# Self-locating
if [ -z "$AGENTS_HOME" ]; then
    _self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    AGENTS_HOME="$(cd "$_self/../.." && pwd)"
    export AGENTS_HOME
fi

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
STATE_DB="$HERMES_HOME/state.db"
LOG="$AGENTS_HOME/.monitor/logs/session-guardian.log"
MATTERMOST_TOKEN_FILE="$HERMES_HOME/.env"
WEBHOOK_URL="${SESSION_GUARDIAN_WEBHOOK:-}"

# MiniMax context window
MAX_CONTEXT=131072
TRIGGER_PCT=0.78

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

mkdir -p "$(dirname "$LOG")"

# Get the most recent active session
get_active_session() {
    python3 - "$STATE_DB" << 'PYEOF'
import sys, sqlite3
db = sys.argv[1]
try:
    conn = sqlite3.connect(db)
    cur = conn.execute("""
        SELECT session_id, title, updated_at
        FROM sessions
        WHERE ended_at IS NULL
        ORDER BY updated_at DESC
        LIMIT 1
    """)
    row = cur.fetchone()
    if row:
        print(f"{row[0]}|{row[1] or ''}|{row[2]}")
    conn.close()
except Exception as e:
    sys.exit(1)
PYEOF
}

# Count messages in a session (proxy for context pressure)
get_session_msg_count() {
    local sid="$1"
    python3 - "$STATE_DB" "$sid" << 'PYEOF'
import sys, sqlite3
db, sid = sys.argv[1], sys.argv[2]
try:
    conn = sqlite3.connect(db)
    count = conn.execute("SELECT COUNT(*) FROM messages WHERE session_id=?", (sid,)).fetchone()[0]
    conn.close()
    print(count)
except:
    print(0)
PYEOF
}

# Trigger /new via Mattermost webhook (agent monitors this channel)
trigger_new_session() {
    local sid="$1"
    local webhook="$WEBHOOK_URL"

    if [ -n "$webhook" ]; then
        curl -s -X POST "$webhook" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"SESSION_THRESHOLD reached for $sid — initiating /new\"}" \
            > /dev/null 2>&1 || true
    fi

    # Also write to control FIFO if it exists
    local control_fifo="$AGENTS_HOME/.monitor/control.fifo"
    if [ -e "$control_fifo" ]; then
        echo "/new" > "$control_fifo" 2>/dev/null || true
    fi

    log "Triggered /new for session $sid"
}

# Main
main() {
    result=$(get_active_session)
    if [ -z "$result" ]; then
        log "No active session found"
        exit 0
    fi

    sid="${result%%|*}"
    rest="${result#*|}"
    title="${rest%%|*}"
    updated="${rest#*|}"

    msg_count=$(get_session_msg_count "$sid")

    # Rough token estimate: ~2.5 chars per token, plus prompt overhead
    # Session at 200 messages ≈ ~50K tokens; at 400 ≈ ~100K
    estimated_tokens=$((msg_count * 250 + 5000))

    pct=$(python3 - "$estimated_tokens" "$MAX_CONTEXT" "$TRIGGER_PCT" << 'PYEOF'
import sys
tokens, max_ctx, trigger = map(float, sys.argv[1:])
pct = tokens / max_ctx
print(f"{pct:.3f}")
# Write sentinel if threshold exceeded
if pct >= trigger:
    open("/tmp/.session_guardian_trigger", "w") if pct >= trigger else None
PYEOF
)

    log "Session $sid ($title) — ~${estimated_tokens}tokens (${pct} of $MAX_CONTEXT), $msg_count messages"

    if [ -f "/tmp/.session_guardian_trigger" ]; then
        rm -f /tmp/.session_guardian_trigger
        trigger_new_session "$sid"
    fi
}

main