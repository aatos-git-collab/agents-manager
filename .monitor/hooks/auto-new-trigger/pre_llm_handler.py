#!/usr/bin/env python3
"""
pre_llm_handler.py — session auto-new trigger for Hermes Agent.

Wired via config.yaml hooks: { pre_llm_call: [{command: /path/to/this/file.py}] }
Auto-accepted via hooks_auto_accept: true in config.yaml.

Fires when context >= 78% of 131K tokens (~102K tokens).
Injects [SESSION ADVISORY] into user message so model can act before compression.
Does NOT hard-reset — advisory only, model decides.

Also writes sentinel /tmp/.session_guardian_trigger checked by session-guardian.sh cron.
"""
import json
import os
import sys
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────
HERMES_HOME = Path(os.environ.get("HERMES_HOME", str(Path.home() / ".hermes")))
AGENTS_HOME = Path(os.environ.get("AGENTS_HOME", str(Path.home() / ".agents-manager")))
STATE_DB = HERMES_HOME / "state.db"
GUARDIAN_LOG = AGENTS_HOME / ".monitor" / "logs" / "session-guardian.log"
TRIGGER_SENTINEL = Path("/tmp/.session_guardian_trigger")

# ── Tunables ────────────────────────────────────────────────────────────────
MAX_CONTEXT = 131072      # MiniMax M2-7 context window
TRIGGER_PCT = 0.78       # fire at 78% — one notch before compression
# ─────────────────────────────────────────────────────────────────────────────

def get_session_msg_count(session_id: str) -> int:
    try:
        import sqlite3
        conn = sqlite3.connect(str(STATE_DB))
        count = conn.execute(
            "SELECT COUNT(*) FROM messages WHERE session_id=?",
            (session_id,)
        ).fetchone()[0]
        conn.close()
        return count
    except Exception:
        return 0

def get_approx_tokens(session_id: str) -> int:
    return get_session_msg_count(session_id) * 250 + 5000

def main() -> None:
    # Read hook payload from stdin (JSON)
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # Silent no-op

    event_name = payload.get("hook_event_name", "")
    session_id = payload.get("session_id", "")
    user_message = payload.get("user_message", "") or ""
    is_first_turn = payload.get("is_first_turn", False)

    # Skip if already has advisory
    if "[SESSION ADVISORY]" in user_message:
        sys.exit(0)

    # Skip on first turn
    if is_first_turn:
        sys.exit(0)

    approx = get_approx_tokens(session_id)
    pct = approx / MAX_CONTEXT

    # Ensure log dir
    GUARDIAN_LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(GUARDIAN_LOG, "a") as f:
        from datetime import datetime
        f.write(f"[{datetime.now().isoformat()}] [PRE_LLM] sid={session_id} "
                f"tokens≈{approx} pct={pct:.1%} event={event_name}\n")

    if approx >= int(MAX_CONTEXT * TRIGGER_PCT):
        TRIGGER_SENTINEL.parent.mkdir(parents=True, exist_ok=True)
        TRIGGER_SENTINEL.write_text(f"{session_id}|{approx}|{pct:.3f}")

        advisory = (
            f"\n\n[SESSION ADVISORY — Context at ~{pct:.0%} (~{approx:,} / {MAX_CONTEXT:,} tokens). "
            f"New session recommended. Type /new to continue in fresh context, or continue if you "
            f"want to preserve this thread. Compression will occur automatically if not reset.]"
        )

        # Output Hermes-wire-shape response to stdout
        response = {"context": advisory}
        print(json.dumps(response))

        with open(GUARDIAN_LOG, "a") as f:
            f.write(f"[{datetime.now().isoformat()}] [TRIGGER] "
                    f"context {pct:.0%} >= {TRIGGER_PCT:.0%} — advisory injected\n")

    sys.exit(0)

if __name__ == "__main__":
    main()