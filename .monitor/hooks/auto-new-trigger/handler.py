#!/usr/bin/env python3
"""
auto-new-trigger pre_llm_call hook.

Fires on every LLM call. Checks approx_input_tokens against threshold.
If >= 78% of context window, injects a session-reset advisory into the
incoming user message so the model can act on it before compression kicks in.

The model sees: "[SESSION ADVISORY] Context at ~{pct}% — consider /new for fresh context"
This is NOT a hard reset. The model decides whether to break the conversation.
"""
import json
import logging
import os
import sys
from pathlib import Path

logger = logging.getLogger("auto_new_trigger")

# Load hermes home
HERMES_HOME = Path(os.environ.get("HERMES_HOME", str(Path.home() / ".hermes")))
STATE_DB = HERMES_HOME / "state.db"

# Tunables
MAX_CONTEXT = 131072        # MiniMax M2-7 context window
TRIGGER_PCT = 0.78         # Fire at 78% — one notch before compression
GUARDIAN_LOG = Path(os.environ.get("AGENTS_HOME", str(Path.home() / ".agents-manager"))) / ".monitor" / "logs" / "session-guardian.log"

# Sentinel file — also checked by session-guardian.sh cron job
TRIGGER_SENTINEL = Path("/tmp/.session_guardian_trigger")


def get_session_approx_tokens(session_id: str) -> int:
    """Estimate tokens from message count in state.db (rough but free)."""
    try:
        import sqlite3
        if not STATE_DB.exists():
            return 0
        conn = sqlite3.connect(str(STATE_DB))
        msg_count = conn.execute(
            "SELECT COUNT(*) FROM messages WHERE session_id=?",
            (session_id,)
        ).fetchone()[0]
        conn.close()
        # ~250 tokens per message average + base overhead
        return msg_count * 250 + 5000
    except Exception as e:
        logger.warning("Could not read state.db: %s", e)
        return 0


def get_context_pct(approx_tokens: int) -> float:
    return min(1.0, approx_tokens / MAX_CONTEXT)


def register(ctx):
    """Called by Hermes plugin system on load."""
    ctx.register_hook("pre_llm_call", on_pre_llm_call)
    logger.info("auto-new-trigger hook registered (threshold: %.0f%%)", TRIGGER_PCT * 100)


def on_pre_llm_call(
    session_id: str,
    user_message: str,
    conversation_history: list,
    is_first_turn: bool,
    model: str,
    platform: str,
    sender_id: str,
    **kwargs,
) -> dict:
    """
    Returns a dict with {"context": "..."} to inject into the user message.
    Empty dict = no injection.
    """
    # Skip on first turn
    if is_first_turn:
        return {}

    # Skip if message already has advisory (avoid double-injecting)
    if isinstance(user_message, str) and "[SESSION ADVISORY]" in user_message:
        return {}

    approx = get_session_approx_tokens(session_id)
    pct = get_context_pct(approx)

    # Write sentinel for external monitor
    GUARDIAN_LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(GUARDIAN_LOG, "a") as f:
        f.write(f"[{__import__('datetime').datetime.now().isoformat()}] "
                f"[PRE_LLM] session={session_id} tokens≈{approx} pct={pct:.1%}\n")

    if approx >= int(MAX_CONTEXT * TRIGGER_PCT):
        TRIGGER_SENTINEL.parent.mkdir(parents=True, exist_ok=True)
        TRIGGER_SENTINEL.write_text(f"{session_id}|{approx}|{pct:.3f}")

        advisory = (
            f"\n\n[SESSION ADVISORY — Context at ~{pct:.0%} (~{approx:,} tokens of {MAX_CONTEXT:,} max). "
            f"New session recommended to maintain quality. Type /new to continue in a fresh context, "
            f"or continue if you want to preserve this thread.]"
        )

        with open(GUARDIAN_LOG, "a") as f:
            f.write(f"[{__import__('datetime').datetime.now().isoformat()}] "
                    f"[TRIGGER] context {pct:.0%} >= {TRIGGER_PCT:.0%} — advisory injected\n")

        return {"context": advisory}

    return {}